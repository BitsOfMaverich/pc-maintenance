#!/usr/bin/bash


echo "debug 1" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

echo "debug 2" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

set -euo pipefail

echo "debug 3" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# --- load config ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "debug 4" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

# shellcheck source=/dev/null
source "$SCRIPT_DIR/config"

echo "debug 5" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

require_cmd jq
require_cmd tar
require_cmd hostname
require_cmd aws
require_cmd date

echo "debug 6" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

HOSTNAME_SHORT="$(hostname -s)"
DATE_ISO="$(date '+%Y-%m-%d_%H%M')"
ARCHIVE_BASENAME="${HOSTNAME_SHORT}_${DATE_ISO}.tar.gz"
ARCHIVE_PATH="${TMP_DIR%/}/${ARCHIVE_BASENAME}"
s3_dest="s3://${S3_BUCKET%/}/${HOSTNAME_SHORT}/"


log() { 
  now=$(date --iso-8601=seconds)
  printf '%s\n' "${now} $*" >> "${SCRIPT_DIR}/log.txt" ; }


build_exclude_args() {
  local json="$1"
  local -a args=()

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    args+=( "--exclude=$item" "--exclude=*/$item" )
  done < <(jq -r '.[]' <<<"$json")

  log "Excludes:"
  log "  ${args[@]}"

  printf '%s\0' "${args[@]}"
}


build_nobackup_excludes() {
  # Emit NUL-delimited --exclude=... args for any directory that contains a .nobackup file.
  # We exclude the directory itself (so its entire subtree is skipped) and also the .nobackup file.
  local -a roots=()
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    roots+=( "$root" )
  done < <(jq -r '.[]' <<<"${BACKUP_DIR_LIST:-[]}")

  local -a args=()
  local root rel_dir

  for root in "${roots[@]}"; do
    [[ "$root" != /* ]] && continue
    [[ ! -d "$root" ]] && continue

    # Find .nobackup files anywhere under this root
    while IFS= read -r nb; do
      [[ -z "$nb" ]] && continue
      # Directory containing the .nobackup marker
      local nb_dir
      nb_dir="$(dirname -- "$nb")"

      # Convert to tar path relative to / because you use: tar -C /
      rel_dir="${nb_dir#/}"

      # Exclude the whole directory subtree and the marker file itself
      args+=( "--exclude=${rel_dir}" "--exclude=${rel_dir}/**" "--exclude=${rel_dir}/.nobackup" )
    done < <(find "$root" -type f -name '.nobackup' -print)
  done

  log "Exclude .nobackup dirs:"
  log "  ${args[@]}"

  printf '%s\0' "${args[@]}"
}


build_path_args() {
  local json="$1"
  local -a paths=()

  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    if [[ "$dir" != /* ]]; then
      log "WARN: skipping non-absolute path: '$dir'" >&2
      continue
    fi
    if [[ ! -e "$dir" ]]; then
      log "WARN: path does not exist, skipping: '$dir'" >&2
      continue
    fi
    paths+=( "${dir#/}" )
  done < <(jq -r '.[]' <<<"$json")

  if [[ "${#paths[@]}" -eq 0 ]]; then
    log "ERROR: no valid backup paths found" >&2
    return 1
  fi

  log "Backup paths relative to /:"
  log "  ${paths[@]}"

  printf '%s\0' "${paths[@]}"
}


main() {
  log "Creating archive: $ARCHIVE_PATH"

  local -a exclude_args=()
  local -a path_args=()
  local -a nobackup_excludes=()

  while IFS= read -r -d '' x; do exclude_args+=( "$x" ); done < <(build_exclude_args "${IGNORE:-[]}")
  while IFS= read -r -d '' x; do path_args+=( "$x" ); done < <(build_path_args "${BACKUP_DIR_LIST:-[]}")
  while IFS= read -r -d '' x; do nobackup_excludes+=( "$x" ); done < <(build_nobackup_excludes)

  log "Starting tar."
  
  tar --wildcards --wildcards-match-slash -C / -czvf "$ARCHIVE_PATH" \
    "${exclude_args[@]}" \
    "${nobackup_excludes[@]}" \
    "${path_args[@]}"

  log "Archive created."


  if [[ "${UPLOAD_TO_S3}" == "true" ]]; then

    log "Uploading to $s3_dest"
        
    aws s3 cp "$ARCHIVE_PATH" "$s3_dest" \
        --profile "$AWS_PROFILE" \
        --storage-class "GLACIER_IR"
    
    if [[ $? -eq 0 ]]; then
      log "Uploaded to S3"
    else
      log "Error uploading to S3"
    fi
  else
    log "Skipped upload to S3"
  fi

  if [[ "${CLEANUP}" == "true" ]]; then
    rm -f -- "$ARCHIVE_PATH"
  fi


  if [[ "${UPLOAD_TO_S3}" == "true" ]]; then
    S3_STATUS="${s3_dest}${ARCHIVE_BASENAME}"
  else
    S3_STATUS="S3 upload skipped"
  fi

  local msg
  msg="Backup SUCCESS
Host: ${HOSTNAME_SHORT}
When: ${DATE_ISO}
S3:   ${S3_STATUS}
Dirs: $(jq -c '.' <<<"${BACKUP_DIR_LIST:-[]}")
"

  aws --profile "$AWS_PROFILE" sns publish \
      --topic-arn "$SNS_TOPIC_ARN" \
      --subject "Backup SUCCESS: ${HOSTNAME_SHORT} ${DATE_ISO}" \
      --message "$msg" >/dev/null

  log "SNS published."
  log "Done."
}

echo "debug 7" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

log "Settings 0: ${HOSTNAME_SHORT}
${DATE_ISO}
${ARCHIVE_BASENAME}
${ARCHIVE_PATH}
${s3_dest}
"

echo "Settings 1: ${HOSTNAME_SHORT}
${DATE_ISO}
${ARCHIVE_BASENAME}
${ARCHIVE_PATH}
${s3_dest}
" >> /home/rich/OneDrive/pc-maintenance/backup/backup-linux/log.txt

main "$@"
