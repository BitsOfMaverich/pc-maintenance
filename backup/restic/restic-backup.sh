#!/bin/bash

 # run as root if we expand to backing up outside of my user profile

echo $(date) > /home/rich/OneDrive/pc-maintenance/backup/restic/cron.log

ENV_FILE="/home/rich/.config/restic/restic.env"
[[ -r "$ENV_FILE" ]] || { echo "ERROR: cannot read $ENV_FILE" >&2; exit 1; }

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
    --files-from /home/rich/.config/restic/backup-paths.txt \
    --exclude-file /home/rich/.config/restic/excludes.txt

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


