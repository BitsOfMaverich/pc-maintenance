#!/bin/bash

 # run as root if we expand to backing up outside of my user profile


BASE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME_SHORT="$(hostname -s)"

set -a
source $BASE_PATH/restic-backup.vars
set +a

# debug

echo $RESTIC_REPOSITORY
echo $RESTIC_PASSWORD_FILE
echo $RESTIC_BACKUP_LOG
echo
echo $BACKUP_PATHS_FILE
echo $EXCLUDES_FILE
echo $LOG_FILE

echo $AWS_PROFILE
echo $SNS_TOPIC_ARN
echo $PATH

echo $DAYS





send_message(){

   local status=$1
   local message=$2

  result=$(aws --profile "${AWS_PROFILE}" sns publish \
      --topic-arn "${SNS_TOPIC_ARN}" \
      --subject "Restic Backup ${status}: ${HOSTNAME_SHORT}" \
      --message "${message}" \
  )

  logger "sns result: $result"
}

logger(){
   now=$(date --iso-8601=s)
   echo "$now $1" >> $LOG_FILE
}

# do backup
result=$(restic backup \
    --one-file-system \
    --files-from ${BACKUP_PATHS_FILE} \
    --exclude-file ${EXCLUDES_FILE}
)

exit_code=$?

logger "backup exit code: $exit_code"


# check exit status.  
# If 0 collect stats and send message
if [ $exit_code -eq 0 ]; then

   # Cleanup
   # Disable grouping entirely (keep N snapshots total across the whole repo):
   restic forget --group-by "" --keep-last "${KEEP_DAYS}" --prune

   status="PASS"
   latest=$(restic snapshots latest)
   message=$(cat << EOF
Latest snapshot:
"${latest}"

Total snapshots: $(restic snapshots --json | jq length)
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


