# Minimal disk health check using native Get-PhysicalDisk.
# Sends SNS alerts if any disk is not Healthy. Sends a Monday heartbeat if all are Healthy.

Start-Transcript -Path "C:\Users\Marsha\Documents\utility\log.txt"

$Profile     = "maintenance"
$SnsTopicArn = "arn:aws:sns:us-east-2:465723427096:pc-health"
$HostName    = $env:COMPUTERNAME

function Send-SnsMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [string] $Subject
    )

    $args = @(
        "sns", "publish",
        "--topic-arn", $SnsTopicArn,
        "--message", $Message
    )

    if ($Subject) { $args += @("--subject", $Subject) }
    if ($Profile) { $args += @("--profile", $Profile) }

    & aws @args | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "aws sns publish failed with exit code $LASTEXITCODE"
    }
}

$failed = $false

# Pull disk health from Windows storage stack
$disks = Get-PhysicalDisk |
    Select-Object FriendlyName, SerialNumber, MediaType, HealthStatus, OperationalStatus

foreach ($d in $disks) {
    $name   = $d.FriendlyName
    $serial = $d.SerialNumber
    $media  = $d.MediaType
    $health = $d.HealthStatus
    $op     = ($d.OperationalStatus -join ", ")

    Write-Host "$name ($media) Health=$health Op=$op"

    if ($health -ne "Healthy") {
        $failed = $true
        Send-SnsMessage `
            -Subject "HEALTH ALERT" `
            -Message "Disk health issue on $HostName $name ($media) SN:$serial Health=$health Op=$op"
    }
}

# Monday heartbeat only if everything is healthy
if ((Get-Date).DayOfWeek -eq [DayOfWeek]::Monday -and -not $failed) {
    Send-SnsMessage `
        -Subject "Health Check for $HostName" `
        -Message "Health checks ran on $HostName. No problems found."
}
