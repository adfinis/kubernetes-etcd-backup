# Kubernetes etcd backup CronJob

This CronJob creates a Pod which runs `/backup.sh` on a Kubernetes cluster to create the described backup. After finishing, it copies the files to a configured PV and expires old backups according to its configuration.

The backup script generates a `snapshot.db` file with the date when it is performed.

## Installation

First, create a namespace:
```
kubectl create namespace etcd-backup
```

### Get the necessary configuration
If you run etcd in your cluster you can read the etcd configuration and the location of the required certificates from your clusters etcd pod. The following commands will give you the necessary information:

```
kubectl describe pod -n kube-system etcd-<name of your etcd pod> | less
```

Get the IP address of the etcd endpoint and put it in the config map. Then get the location of the following certificates:
- peer-cert-file etcd-peer.crt
- peer-key-file etcd-peer.key
- trusted-ca-file etcd-ca.crt

If you run etcd outside of your cluster, you can get the information from the etcd configuration file. The default location is `/etc/etcd.env`. The certificate information is in the TLS section. You need the `ETCD_ADVERTISE_CLIENT_URLS`, `ETCD_PEER_TRUSTED_CA_FILE`, `ETCD_PEER_CERT_FILE` and `ETCD_PEER_KEY_FILE` variables. The following example shows the default values:

- ETCD_ADVERTISE_CLIENT_URLS=https://192.168.122.151:2379
- ...
- ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
- ETCD_PEER_CERT_FILE=/etc/ssl/etcd/ssl/member-node1.pem
- ETCD_PEER_KEY_FILE=/etc/ssl/etcd/ssl/member-node1-key.pem

Get the certificates from the Kubernetes host and put them into a secret:
```
kubectl create secret generic etcd-peer-tls --from-file=tls.crt --from-file=tls.key -n etcd-backup
kubectl create secret generic etcd-server-ca --from-file=service-ca.crt -n etcd-backup
```

Add the endpoint IP address to the [ConfigMap](./backup-config.yaml), without scheme or port:
```
  ENDPOINT: "192.168.122.151"
```

### Create the backup configuration

Then adjust the storage configuration to your needs in `backup-storage.yaml` and deploy it. The example uses NFS but you can use any storage class you want:
```
kubectl create -f backup-storage.yaml
```

Configure the backup-script:
```
kubectl create -f backup-config.yaml
```

Then deploy the CronJob:
```
kubectl create -f backup-cronjob.yaml
```

## Creating manual backup for testing purpose

To test the backup or create an manual backup you can run a job:
```
backupName=$(date "+etcd-backup-manual-%F-%H-%M-%S")
kubectl create job --from=cronjob/etcd-backup ${backupName}
```

To see if everything works as it should you can check the logs:
```
kubectl logs -l job-name=${backupName}
```
Then check on your Storage, if the files are there as excepted.

## Configuration

Configuration can be changed in the ConfigMap `backup-config`:

```
kubectl edit -n etcd-backup cm/backup-config
```

The following options are used:
- `ETCD_BACKUP_SUBDIR`: Sub directory on PVC that should be used to store the backup. If it does not exist it will be created.
- `ETCD_BACKUP_DIRNAME`: Directory name for a single backup. This is a format string used by
[`date`](https://man7.org/linux/man-pages/man1/date.1.html)
- `ETCD_BACKUP_EXPIRE_TYPE`:
  - `days`: Keep backups newer than `backup.keepdays`.
  - `count`: Keep a number of backups. `backup.keepcount` is used to determine how much.
  - `never`: Do not expire backups, keep all of them.
- `ETCD_BACKUP_KEEP_DAYS`: Days to keep the backup. Only used if `backup.expiretype` is set to `days`.
- `ETCD_BACKUP_KEEP_COUNT`: Number of backups to keep. Only used if `backup.expiretype` is set to `count`.
- `ETCD_BACKUP_UMASK`: Umask used inside the script to set restrictive permission on written files, as they contain sensitive information.
- `ENDPOINT`: The IP address of the etcd endpoint, without scheme or port, e.g. `"192.168.39.86"`.

Changing the schedule be done in the CronJob directly, with `spec.schedule`:
```
kubectl edit -n etcd-backup cronjob/etcd-backup
```
Default is `0 0 * * *` which means the CronJob runs one time a day at midnight.

## Monitoring

To be able to get alerts when backups are failing or not being scheduled you can deploy this [PrometheusRule](https://github.com/adfinis/kubernetes-etcd-backup/blob/main/etcd-backup-cronjob-monitor.PrometheusRule.yaml).

```
kubectl create -n etcd-backup -f etcd-backup-cronjob-monitor.PrometheusRule.yaml
```

# Helm chart

To easily deploy the solution a Helm chart is available on upstream Adfinis charts [repository](https://github.com/adfinis-sygroup/helm-charts/tree/master/charts/kubernetes-etcd-backup).

## Installation

Fist create the namespace:
```
kubectl create namespace etcd-backup
```

Then create the secrets as described above.
Finally update the `values.yaml` file according to your needs.

```
helm repo add adfinis https://charts.adfinis.com
helm install etcd-backup adfinis/kubernetes-etcd-backup
```

## Development

### Release Management

The CI/CD setup uses semantic commit messages following the
[conventional commits standard](https://www.conventionalcommits.org/en/v1.0.0/).
There is a GitHub Action in [.github/workflows/semantic-release.yaml](./.github/workflows/semantic-release.yaml)
that uses [go-semantic-commit](https://go-semantic-release.xyz/) to create new releases.

The commit message should be structured as follows:

```console
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

The commit contains the following structural elements, to communicate intent to the consumers of your library:

1. **fix:** a commit of the type `fix` patches gets released with a PATCH version bump
1. **feat:** a commit of the type `feat` gets released as a MINOR version bump
1. **BREAKING CHANGE:** a commit that has a footer `BREAKING CHANGE:` gets released as a MAJOR version bump
1. types other than `fix:` and `feat:` are allowed and don't trigger a release

If a commit does not contain a conventional commit style message you can fix
it during the squash and merge operation on the PR.

## References
* https://docs.openshift.com/container-platform/4.14/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html
