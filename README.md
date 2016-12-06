# docker-etcd

etcd->S3 backup script

## Usage

    ```shell
    docker run \
      -e ETCD_BACKUP_S3_BUCKET=mybucket \
      -e ETCD_BACKUP_S3_PREFIX=myprefix \
      -e ETCD_BACKUP_INTERVAL_SEC=600 \
      -v <YOUR_ETCD_DATA_DIR>:/var/lib/etcd \
      wattpad/etcd:<VERSION> \
      etcd-backup
    ```

## AWS Authentication

The backup script uses boto3 under the hood, so any [authentication method](http://boto3.readthedocs.io/en/latest/guide/configuration.html#configuring-credentials)
used by boto will work here, including environment variables and IAM instance profiles.

## Datadog support

If you supply the appropraite environment variables, the backup script will send metrics to Datadog.  See the
usage docs in [etcd-backup.py](etcd-backup/etcd-backup.py) for more information.
