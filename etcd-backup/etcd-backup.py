#!/usr/bin/env python

import base64
import boto3
import datadog
import datetime
import hashlib
import logging
import os
import subprocess
import tarfile
import time
import signal
import sys

BACKUP_BASE_DIR = "/tmp"
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# Allows for testing against a fake S3 backend
S3_ENDPOINT_URL = os.getenv('S3_ENDPOINT_URL')
S3_UPLOAD_MAX_RETRIES = 10
S3_UPLOAD_RETRY_INITIAL_DELAY_SEC = 0.1

should_shut_down = False


def main():
    data_dir = os.getenv('ETCD_DATA_DIR', '/var/lib/etcd')
    backup_interval = int(os.getenv('BACKUP_INTERVAL_SEC', 60))
    s3_bucket = get_required_env_var('S3_BUCKET')
    s3_prefix = get_required_env_var('S3_PREFIX')
    run_once = os.getenv("RUN_ONCE") == "true"

    while True:
        logging.info("Starting etcd-backup, running backup every %s seconds.", backup_interval)
        do_backup(data_dir, s3_bucket, s3_prefix)

        if run_once:
            logging.info("RUN_ONCE enabled, exiting.")
            break
        if should_shut_down:
            break
        time.sleep(backup_interval)


def print_usage():
    message = """
Usage: %s

Required env vars:
  S3_BUCKET: S3 bucket to upload backup tarball
  S3_PREFIX: S3 prefix added to S3 object (useful for backup up multiple clusters into the same bucket)

Optional env vars:
  ETCD_DATA_DIR: etcd data directory  (default: /var/lib/etcd)
  BACKUP_INTERVAL_SEC: number of seconds to wait between backup runs (default: 60)
  RUN_ONCE: if "true", run once and exit
""" % (sys.argv[0])
    print(message)


def get_required_env_var(var):
    value = os.getenv(var)
    if value is None:
        logging.error('Missing required env var: %s' % var)
        print_usage()
        sys.exit(1)
    return value


def do_backup(data_dir, s3_bucket, s3_prefix):
    base_path = '%s/etcd-backup-%s' % (BACKUP_BASE_DIR, datetime.datetime.utcnow().strftime('%Y-%m-%d-%H%M%S'))

    backup_dir = base_path
    backup_file = '%s.tar.gz' % base_path

    generate_backup(data_dir, backup_dir)
    compress_files(backup_dir, backup_file)
    s3_key = "%s%s" % (s3_prefix, os.path.basename(backup_file))

    retries = S3_UPLOAD_MAX_RETRIES
    delay = S3_UPLOAD_RETRY_INITIAL_DELAY_SEC

    while True:
        if should_shut_down:
            break

        try:
            upload_file(s3_bucket, s3_key, backup_file)
            submit_metrics(s3_bucket, s3_prefix, os.path.getsize(backup_file))
            break
        except Exception as e:
            logging.error("Error uploading to S3: %s" % e.message)
            retries -= 1
            if retries == 0:
                raise e
            logging.error("Retrying upload in %s seconds" % delay)
            time.sleep(delay)
            delay *= 2


def generate_backup(data_dir, backup_dir):
    logging.debug("Backing up etcd data from %s to %s" % (data_dir, backup_dir))
    try:
        subprocess.check_output(['etcdctl', 'backup', '--data-dir=%s' % data_dir, '--backup-dir=%s' % backup_dir], stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        logging.error("Error running etcdctl. Output: %s" % e.output)
        raise


def compress_files(source_dir, file_path):
    logging.debug("Compressing backup directory %s into tarball %s" % (source_dir, file_path))
    with tarfile.open(name=file_path, mode="w:gz") as tar:
        tar.add(source_dir, arcname='/')


def upload_file(bucket, key, file_path):
    with open(file_path, 'rb') as f:
        boto3.resource('s3', endpoint_url=S3_ENDPOINT_URL) \
             .Object(bucket, key) \
             .put(Body=f, ContentMD5=base64.b64encode(get_file_md5_sum(file_path)))


def get_file_md5_sum(file_path):
    m = hashlib.md5()
    with open(file_path, 'rb') as f:
        while True:
            b = f.read(512)
            if b == '':
                break
            m.update(b)
    return m.digest()


def submit_metrics(bucket, prefix, file_size_bytes):
    api_key = os.getenv('DATADOG_API_KEY')
    app_key = os.getenv('DATADOG_APPLICATION_KEY')

    if api_key and app_key:
        datadog.initialize(api_key=api_key, app_key=app_key)
        datadog.api.Metric.send(metric='etcd_backup.s3_upload.bytes',
                                points=file_size_bytes,
                                host="",
                                tags=['bucket:%s' % bucket, 'prefix:%s' % prefix])
    else:
        logging.debug("Not submitting Datadog metric: DATADOG_API_KEY and DATADOG_APPLICATION_KEY not set.")


if __name__ == '__main__':
    logging.basicConfig(level=logging.getLevelName(LOG_LEVEL))
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("boto3").setLevel(logging.WARNING)

    def sig_handler(signum, frame):
        logging.info("Signal received, shutting down...")
        global should_shut_down
        should_shut_down = True

    signal.signal(signal.SIGTERM, sig_handler)
    signal.signal(signal.SIGINT, sig_handler)

    main()
