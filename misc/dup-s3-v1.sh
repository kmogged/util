#!/bin/bash

## tkooda : 2015-02-20 : simple duplicity backup script, specify S3 bucket, and list of dirs to backup


## NOTE: duplicity will mark dirs/files as deleted from the archive if you remove dirs from it's arg list, so we upload each directory argument on the command line separately

## OPTIONS:
##  - configs to into ~/.config/envdir/duplicity/{PASSPHRASE,AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY}
##  - set  DUPLICITY_ARGS="-v6 --dry-run"   for debugging
##  - set  DUPLICITY_FULL_IF_OLDER_THAN="180D"
##  - set  DUPLICITY_VOLSIZE="250"
##  - set  DUPLICITY_REMOVE_ALL_BUT_N_FULL="2"


[ $# -lt 2 ] && { echo -e "usage: ${0##*/} [--clean] <s3_bucket_path> <path_dirs..>\n e.g.: ${0##*/} --clean s3+http://my-bucket-name/my-device-dir ~/.ssh/ ~/bin/"; exit 1; }

which chpst >/dev/null 2>/dev/null || { echo "ERROR: missing 'chpst' binary from 'runit' package:  sudo apt-get install runit"; exit 2; }

for var in PASSPHRASE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  [ -f ~/.config/envdir/duplicity/$var ] || { echo "ERROR: missing ~/.config/envdir/duplicity/$var"; exit 3; }
done

if [ "$1" == "--clean" ]; then
  clean="yes"
  shift
else
  clean="no"
fi

bucket="$1"
shift

for item in $*; do
  cd "${item}" || continue
  echo "#################################################"
  echo "[ syncing ${item} to ${bucket} .. ]"
#echo \
  chpst \
    -L /tmp/.lock.dup-s3.${PWD//\//_} \
    -e ~/.config/envdir/duplicity/ \
      nice -n19 \
      duplicity \
        ${DUPLICITY_ARGS} \
        --full-if-older-than ${DUPLICITY_FULL_IF_OLDER_THAN:-180D} \
        --asynchronous-upload \
        --volsize ${DUPLICITY_VOLSIZE:-250} \
        --exclude '**.svn' \
        --exclude '**.git' \
        --exclude '**.CVS' \
        ./ "${bucket}/`hostname`${PWD//\//_}" 2>&1
  if [ "$clean" == "yes" ]; then
#echo \
  chpst \
    -L /tmp/.lock.dup-s3.${PWD//\//_} \
    -e ~/.config/envdir/duplicity/ \
      nice -n19 \
      duplicity \
        remove-all-but-n-full ${DUPLICITY_REMOVE_ALL_BUT_N_FULL:-2} --force \
        ${DUPLICITY_ARGS} \
        "${bucket}/`hostname`${PWD//\//_}" 2>&1
  fi
  echo
done

