#!/bin/sh
set -e

host_ip=$(route -n | grep "^0\.0\.0\.0" | awk '{ print $2 }')

if [ -z "$DOGSTATSD_HOST" ]; then
  export DOGSTATSD_HOST="$host_ip"
fi

if [ -z "$ETCD_CLIENT_URL" ]; then
  export ETCD_CLIENT_URL="http://$host_ip:2379"
fi

exec "$@"
