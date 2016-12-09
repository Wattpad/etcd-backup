# etcd-backup [![Build Status](https://travis-ci.org/Wattpad/etcd-backup.svg?branch=master)](https://travis-ci.org/Wattpad/etcd-backup)

etcd->S3 backup script

## Usage

    ```shell
    docker run \
      -e S3_BUCKET=mybucket \
      -e S3_PREFIX=myprefix \
      -e BACKUP_INTERVAL_SEC=600 \
      -v <YOUR_ETCD_DATA_DIR>:/var/lib/etcd \
      wattpad/etcd-backup:<VERSION> \
      etcd-backup
    ```

See the `print_usage` method in [etcd-backup.py](etcd-backup.py) for all available environment variables.

## Leader Backups

This script should be deployed on every peer of the etcd cluster (ie. no proxies) and it will ensure that
backups only run on the current leader.  It will talk to the local etcd instance to determine if it is the
leader.

## AWS Authentication

The backup script uses boto3 under the hood, so any [authentication method](http://boto3.readthedocs.io/en/latest/guide/configuration.html#configuring-credentials)
used by boto will work here, including environment variables and IAM instance profiles.

## Host IP Detection

Any host IPs that would normally default to localhost will default to the host IP when running
in the container.  See [entrypoint.sh](entrypoint.sh).

## Datadog support

If you supply the appropriate environment variables, the backup script will send metrics to Datadog.  See the
usage docs for more information.
