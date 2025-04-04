#!/bin/bash
################################################################################
# backup.sh General etcd backup script
################################################################################
#
# Copyright (C) 2024 Adfinis AG
#                    https://adfinis.com
#                    info@adfinis.com
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public
# License as published  by the Free Software Foundation, version
# 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License  along with this program.
# If not, see <http://www.gnu.org/licenses/>.
#
# Please submit enhancements, bugfixes or comments via:
# https://github.com/adfinis-sygroup/openshift-etcd-backup
#
# Authors:
#  Cyrill von Wattenwyl <cyrill.vonwattenwyl@adfinis.com>
#  Felix Niederer <felix.niederer@adfinis.com>
#  Valentin Maillot <valentin.maillot@adfinis.com>


set -xeuo pipefail

# check storage type
if [ "${ETCD_BACKUP_S3}" = "true" ]; then
    # prepare & push backup to S3

    # update CA trust
    update-ca-trust

    # configure mcli assuming the bucket already exists
    set +o history +x  # disable history and printing of command to stdout, this prevents leaking the secret to the logs
    mcli alias set "${ETCD_BACKUP_S3_NAME}" "${ETCD_BACKUP_S3_HOST}" "${ETCD_BACKUP_S3_ACCESS_KEY}" "${ETCD_BACKUP_S3_SECRET_KEY}"
    set -o history -x  # reenable history and output

    # make dirname
    BACKUP_FOLDER="$( date "${ETCD_BACKUP_DIRNAME}")" || { echo "Invalid backup.dirname" && exit 1; }

    # make necessary directory
    mkdir -p "/tmp/etcd-backup/${BACKUP_FOLDER}"

    # create backup to temporary location
    ETCDCTL_API=3 etcdctl --endpoints "${ENDPOINT}:2379" --cacert="/etc/kubernetes/pki/etcd-ca/ca.crt"  --cert="/etc/kubernetes/pki/etcd-peer/tls.crt" --key="/etc/kubernetes/pki/etcd-peer/tls.key" snapshot save "/tmp/etcd-backup/${BACKUP_FOLDER}/snapshot.db"
    ETCDCTL_API=3 etcdutl --write-out=table snapshot status "/tmp/etcd-backup/${BACKUP_FOLDER}/snapshot.db"

    # move files to S3 and delete temporary files
    mcli mv -r /tmp/etcd-backup/* "${ETCD_BACKUP_S3_NAME}"/"${ETCD_BACKUP_S3_BUCKET}"
    rm -rv /tmp/etcd-backup
else
  # set proper umask
  umask "${ETCD_BACKUP_UMASK}"

  # validate expire type
  case "${ETCD_BACKUP_EXPIRE_TYPE}" in
      days|count|never) ;;
      *) echo "backup.expiretype needs to be one of: days,count,never"; exit 1 ;;
  esac

  # validate  expire numbers
  if [ "${ETCD_BACKUP_EXPIRE_TYPE}" = "days" ]; then
    case "${ETCD_BACKUP_KEEP_DAYS}" in
      ''|*[!0-9]*) echo "backup.expiredays needs to be a valid number"; exit 1 ;;
      *) ;;
    esac
  elif [ "${ETCD_BACKUP_EXPIRE_TYPE}" = "count" ]; then
    case "${ETCD_BACKUP_KEEP_COUNT}" in
      ''|*[!0-9]*) echo "backup.expirecount needs to be a valid number"; exit 1 ;;
      *) ;;
    esac
  fi

  # make dirname and cleanup paths
  BACKUP_FOLDER="$( date "${ETCD_BACKUP_DIRNAME}")" || { echo "Invalid backup.dirname" && exit 1; }
  BACKUP_PATH="$( realpath -m "${ETCD_BACKUP_SUBDIR}/${BACKUP_FOLDER}" )"
  BACKUP_PATH_POD="$( realpath -m "/backup/${BACKUP_PATH}" )"
  BACKUP_ROOTPATH="$( realpath -m "/backup/${ETCD_BACKUP_SUBDIR}" )"

  # make nescesary directorys
  mkdir -p "/tmp/etcd-backup"
  mkdir -p "${BACKUP_PATH_POD}"

  # create backup to temporary location
  ETCDCTL_API=3 etcdctl --endpoints "${ENDPOINT}:2379" --cacert='/etc/kubernetes/pki/etcd-ca/ca.crt'  --cert='/etc/kubernetes/pki/etcd-peer/tls.crt' --key='/etc/kubernetes/pki/etcd-peer/tls.key' snapshot save /tmp/etcd-backup/snapshot.db
  ETCDCTL_API=3 etcdutl --write-out=table snapshot status /tmp/etcd-backup/snapshot.db

  # move files to pvc and delete temporary files
  mv /tmp/etcd-backup/* "${BACKUP_PATH_POD}"
  rm -rv /tmp/etcd-backup

  # expire backup
  if [ "${ETCD_BACKUP_EXPIRE_TYPE}" = "days" ]; then
    find "${BACKUP_ROOTPATH}" -mindepth 1 -maxdepth 1  -type d -mtime "+${ETCD_BACKUP_KEEP_DAYS}" -exec rm -rv {} +
  elif [ "${ETCD_BACKUP_EXPIRE_TYPE}" = "count" ]; then
    # shellcheck disable=SC3040,SC2012
    ls -1tp "${BACKUP_ROOTPATH}" | awk "NR>${ETCD_BACKUP_KEEP_COUNT}" | xargs -I{} rm -rv "${BACKUP_ROOTPATH}/{}"
  fi
fi
