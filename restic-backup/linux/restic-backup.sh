#!/bin/bash

 # run as root if we expand to backing up outside of my user profile

BASE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="$BASE_PATH/restic.env"
BACKUP_PATHS_FILE="$BASE_PATH/backup-paths.txt"
EXCLUDES_FILE="$BASE_PATH/excludes.txt"
LOG_FILE="$BASE_PATH/restic-backup.log"

echo "---" >> $LOG_FILE
echo $(date) >> $LOG_FILE

[[ -r "$ENV_FILE" ]] || {
   echo "ERROR: cannot read $ENV_FILE" | tee -a "$LOG_FILE" >&2
   exit 1
}

set -a
. "$ENV_FILE"
set +a

HOSTNAME_SHORT="$(hostname -s)"

send_message(){

   local status=$1
   local message=$2

  aws --profile "${AWS_PROFILE}" sns publish \
      --topic-arn "${SNS_TOPIC_ARN}" \
      --subject "Restic Backup ${status}: ${HOSTNAME_SHORT}" \
      --message "${message}"
}

restic backup \
    --one-file-system \
    --files-from ${BACKUP_PATHS_FILE} \
    --exclude-file ${EXCLUDES_FILE}

exit_code=$?

# check exit status.  
# If 0 collect stats and send message
if [ $exit_code -eq 0 ]; then
   status="PASS"
   latest=$(restic snapshots --latest 1 --json)
   data=$(echo $latest | jq -r .[0])
   short_id=$(echo $latest | jq -r .[0].short_id)
   stats=$(restic stats $short_id)
   message=$(cat << EOF
DATA:
########
${data}

STATS:
########
${stats}
EOF
)
   send_message "${status}" "${message}"

# else send message with exit code and exit
else
   status="FAIL"
   message=$(cat << EOF
Backup failed with exit code ${exit_code}
EOF
)
   send_message "${status}" "${message}"
fi


# Cleanup
restic forget \
        --keep-within "${KEEP_DAYS}d" \
        --prune