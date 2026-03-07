variables are in file 'config'
run backup-linux.sh, which sources config

parse json doc (list) from config.DIR_LIST

example config:
S3_BUCKET="richardhall_backups"
AWS_PROFILE="foo"
TMP_DIR="/tmp"
SNS_TOPIC="backup-status"
BACKUP_DIR_LIST={
    "/home/rich/OneDrive",
    "foo"
}
IGNORE={
    "Thumbs.db",
    "Desktop.ini"
}

for each $DIR in $BACKUP_DIR_LIST,
- recursively back up that folder
    - ignore subfolders that have a file at the root ".nobackup" 
    - ignore filenames that match any item in $IGNORE_FILES
- backup goes to a gzipped tar file stored in $TMP_DIR/$hostname_$date
    - $date is ISO8601 string of YYYY-mm-DD_HH.MM
- when backup is complete
    - copy the file up to $S3_BUCKET/$hostname/
    - delete the file from $TMP_DIR
    - send message to $SNS_TOPIC endpoint using $AWS_PROFILE to do so