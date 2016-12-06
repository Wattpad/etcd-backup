#!/bin/sh
set -e

DOCKER_HOST_ADDR="${DOCKER_HOST_ADDR:-"localhost"}"
FAKES3_URL="http://${DOCKER_HOST_ADDR}"
ETCD_SOURCE_URL="http://${DOCKER_HOST_ADDR}:2379"
ETCD_RESTORED_URL="http://${DOCKER_HOST_ADDR}:12379"

DEBUG_OUTPUT=${DEBUG_OUTPUT:-/dev/null}

script_dir="$(cd "$(dirname $0)" && pwd)"

export BASE_DIR="$script_dir/tmp"
export DATA_DIR="$BASE_DIR/data"
export RESTORE_DIR="$BASE_DIR/restore"

main() {
  validate_env
  trap handle_exit EXIT INT TERM

  set_up

  populate_etcd

  run_backup
  restore_data
  run_tests

  tear_down
}

populate_etcd() {
  log "Populating etcd at ${ETCD_SOURCE_URL} ..."
  (
    curl -s "${ETCD_SOURCE_URL}/v2/keys/message" -XPUT -d value="Hello world"
    curl -s "${ETCD_SOURCE_URL}/v2/keys/foo" -XPUT -d dir=true
    curl -s "${ETCD_SOURCE_URL}/v2/keys/foo/bar" -XPUT -d value="BAR"
    curl -s "${ETCD_SOURCE_URL}/v2/keys/baz" -XPUT -d value=123
  ) > $DEBUG_OUTPUT 2>&1
}

run_tests() {
  expected="$(curl -s "${ETCD_SOURCE_URL}/v2/keys?recursive=true&sorted=true")"
  actual="$(curl -s "${ETCD_RESTORED_URL}/v2/keys?recursive=true&sorted=true")"

  if [ "$expected" != "$actual" ]; then
    log "Backup and restore contents did not match!"
    log "Expected: $expected"
    log "Actual: $actual"
  else
    log "Tests passed!"
  fi
}

run_backup() {
  log "Running etcd-backup ..."
  docker-compose run etcd-backup
}

restore_data() {
  log "Restoring data from fakes3 ..."
  (
    export AWS_ACCESS_KEY_ID=123
    export AWS_SECRET_ACCESS_KEY=abc
    object=$(aws --endpoint-url="$FAKES3_URL" s3 ls --recursive s3://testbucket | awk '{ print $4 }' | tail -n 1)
    if [ -z "$object" ]; then
      log "Could not find backup tarball in fakes3."
      exit 1
    fi
    aws --endpoint-url=$FAKES3_URL s3 cp "s3://testbucket/$object" $BASE_DIR/
    tar xzvf "$BASE_DIR/$(basename "$object")" -C "$RESTORE_DIR" > /dev/null
  ) > $DEBUG_OUTPUT 2>&1

  log "Starting etcd-restored container ..."
  docker-compose up -d etcd-restored > $DEBUG_OUTPUT 2>&1
}

set_up() {
  log "Setting up environment..."
  (
    docker-compose up -d --force-recreate fakes3 etcd-source
    mkdir -p $BASE_DIR/source $BASE_DIR/restore
  ) > $DEBUG_OUTPUT 2>&1
}

tear_down() {
  log "Cleaning up..."
  (
    docker-compose rm -f
    rm -rf $BASE_DIR/source $BASE_DIR/restore $BASE_DIR/*.tar.gz
  ) > $DEBUG_OUTPUT 2>&1
}

validate_env() {
  if ! which aws docker-compose tar > /dev/null; then
    log "Cannot find all required executables: aws docker-compose tar"
    exit 1
  fi
}

log() {
  echo "[$(date)] $*" >&2
}

handle_exit() {
  status=$?
  if [ $status -ne 0 ]; then
    log "Error occured. return_code: $status"
    tear_down
  fi
}

main
