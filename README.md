# docker-etcd

etcd image with S3 backup script

## Usage

    ```shell
    docker run \
      -e ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380 \
      -e ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379 \
      -e ETCD_ADVERTISE_CLIENT_URLS=http://0.0.0.0:2379 \
      # ... other env vars
      -v <YOUR_ETCD_DATA_DIR>:/var/lib/etcd \
      -p 2379:2379 \
      -p 2380:2380 \
      wattpad/etcd
    ```

### etcd-backup

    ```shell
    docker run \
      -e ETCD_BACKUP_S3_BUCKET=mybucket \
      -e ETCD_BACKUP_S3_PREFIX=myprefix \
      -e ETCD_BACKUP_INTERVAL_SEC=600 \
      -v <YOUR_ETCD_DATA_DIR>:/var/lib/etcd \
      wattpad/etcd \
      etcd-backup
    ```

## AWS Authentication

The backup script uses boto3 under the hood, so any [authentication method](http://boto3.readthedocs.io/en/latest/guide/configuration.html#configuring-credentials)
used by boto will work here, including environment variables and IAM instance profiles.

## Datadog support

If you supply the appropraite environment variables, the backup script will send metrics to Datadog.  See the
usage docs in [etcd-backup.py](etcd-backup/etcd-backup.py) for more information.
