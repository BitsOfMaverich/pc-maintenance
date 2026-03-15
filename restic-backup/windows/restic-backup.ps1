# restic-backup.ps1

# requires powershell 7.
# winget install --id Microsoft.Powershell --source winget
# execute with pwsh, not powershell
# pwsh 7 does not include ISE.  use vscode.

$ErrorActionPreference = "Continue"

# Determine script directory
$BASE_PATH = Split-Path -Parent $MyInvocation.MyCommand.Path

$ENV_FILE = Join-Path $BASE_PATH "restic.env"
$BACKUP_PATHS_FILE = Join-Path $BASE_PATH "backup-paths.txt"
$EXCLUDES_FILE = Join-Path $BASE_PATH "excludes.txt"
$LOG_FILE = Join-Path $BASE_PATH "restic-backup.log"



# debug
$BASE_PATH
$ENV_FILE
$BACKUP_PATHS_FILE
$EXCLUDES_FILE
$LOG_FILE


Add-Content $LOG_FILE "---"
Add-Content $LOG_FILE (Get-Date)

if (!(Test-Path $ENV_FILE)) {
    $msg = "ERROR: cannot read $ENV_FILE"
    Write-Error $msg
    Add-Content $LOG_FILE $msg
    exit 1
}

# Load env file (KEY=value format)
# strip surrounding quotes
Get-Content $ENV_FILE | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()

        if (
            $value.Length -ge 2 -and
            (
                ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))
            )
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path "Env:$name" -Value $value
    }
}


$HOSTNAME_SHORT = $env:COMPUTERNAME


function Send-Message {
    param(
        [string]$status,
        [string]$message
    )

    # save message as a file
    $message | Out-File $BASE_PATH/message.json -Encoding utf8NoBOM
    $subject = "Restic Backup ${status}: $HOSTNAME_SHORT"

    aws sns publish `
        --profile $env:AWS_PROFILE `
        --topic-arn $env:SNS_TOPIC_ARN `
        --subject  $subject `
        --message file://$BASE_PATH/message.json
}


# Run backup
restic backup `
    --files-from $BACKUP_PATHS_FILE `
    --exclude-file $EXCLUDES_FILE

$exit_code = $LASTEXITCODE

if ($exit_code -eq 0) {

    $status = "PASS"

    $latest = restic snapshots --latest 1 --json | ConvertFrom-Json
    $data = $latest[0] | ConvertTo-Json -Depth 10
    $short_id = $latest[0].short_id

    $stats = restic stats $short_id

$message = @"
DATA:
########
$data

STATS:
########
$stats
"@

    Send-Message $status $message

}
else {

$status = "FAIL"

$message = @"
Backup failed with exit code $exit_code
"@

    Send-Message $status $message
}

# Cleanup
restic forget `
    --keep-within "$($env:KEEP_DAYS)d" `
    --prune