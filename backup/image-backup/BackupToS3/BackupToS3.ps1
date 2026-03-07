# aws cli must be installed on local system
# aws configure must have been run to specify the access keys
# expects file BackupToS3.conf in same directory where the script is running.
#
# Includes/Excludes:
# all directories specified in the config file will be recursively synced, so be sure to not 
#   have directoreis that you don't want backed up within the specified paths.
#   For instnace, if you specify to back up D:\, everything on D will be backed up.
#   Best practice is to put your excludes into a top level directory, and specify all other TLD's in the config file.

#######################################################
#  BEGIN USER VARIABLES
#######################################################

#S3 bucket and key to write into.  No trailing slash.
$bucketTarget = "s3://richardhall-backups-home/targeted-backup/rich"

$configFile ="D:\OneDrive\backup scripts\BackupToS3\backupToS3.conf"

#######################################################
#  END USER VARIABLES
#######################################################

#get the directories to back up.  Ignore comments and blank lines.
$list = get-content $configFile | Where-Object {$_ -notlike '#*'} | Where-Object {$_ -notlike ''}

#back up each directory
foreach ($line in $list) {

    #we need to split the drive letter from the folder path so we can recreate the path on s3 without a colon.
    $lineparts = $line -split (":")

#######################################################
#  BEGIN DESTINATION PATH OPTION
#######################################################

    #override to account for different key name on S3.
    #example: key in S3 is "D" but my data drive is now E.  
    #To force key name instead of dynamically getting it from the source, uncomment and edit option 2, then comment option 1.
    #OPTION 1:  the default is to dynamically get the drive letter
    $drive=$lineparts[0]
    #OPTION 2:  override
    #$drive="D"

#######################################################
#  END DESTINATION PATH OPTION
#######################################################

    #now flip the slash the other way
    $path = $lineparts[1] -replace "\\","/"


    #sync the files to S3
    #deletes file from dest if they are not in source.
    aws s3 sync $line $bucketTarget"/"$drive$path --delete

    }


$now = get-date -format "yyyy-MM-ddThhmmz"

#create the output file name
$out = "log\s3_content_$now.txt" 

#make sure the log directory exists
$logDir = ".\log"
If(!(test-path $logDir))
    {
      New-Item -ItemType Directory -Force -Path $logDir
    }

#get the list of what's storred
$content = aws s3 ls $bucketTarget --recursive 


#tally up storrage usage
[long]$bytes = 0
[long]$bytesTotal = 0

foreach ($line in $content) {
    $bytes = ($line -split '\s+')[2]
    $bytesTotal = $bytesTotal + $bytes
    }

$GB = $bytesTotal / 1024 / 1024 / 1024
$num = $content.length


$now = get-date -format "yyyy-MM-ddThhmmz"

#report
"Files stored on S3: $num" | out-file ($out) ascii
"Total size stored:  $GB GB" | out-file ($out) ascii -Append
"Content stored:" | out-file ($out) ascii -Append
$content | out-file ($out) ascii -Append


write-host "$now FINISHED" | out-file ($out) ascii -Append

