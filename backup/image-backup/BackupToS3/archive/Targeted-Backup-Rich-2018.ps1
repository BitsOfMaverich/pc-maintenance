# aws cli must be installed on local system
# aws configure must have been run to specify the access keys
# expects file BackupList.txt in same directory where the script is running.
#
# Includes/Excludes:
# all directories specified in the config file will be recursively synced, so be sure to not 
#   have directoreis that you don't want backed up within the specified paths.
#   For instnace, if you specify to back up D:\, everything on D will be backed up.
#   Best practice is to put your excludes into a top level directory, and specify all other TLD's in the config file.


#S3 bucket and key to write into.  No trailing slash.
$bucketTarget = "s3://richardhall-backups-home/targeted-backup/rich"

#get the directories to back up.  Ignore comments and blank lines.
$list = get-content "BackupList.txt" | Where-Object {$_ -notlike '#*'} | Where-Object {$_ -notlike ''}

#back up each directory
foreach ($line in $list) {

    #we need to split the drive letter from the folder path so we can recreate the path on s3 without a colon.
    $lineparts = $line -split (":")

    #hacked to account for different key name on S3.
    #key is "D" but my data drive is now E
    $drive="D"
    #$drive=$lineparts[0]

    #now flip the slash the other way
    $path = $lineparts[1] -replace "\\","/"


    #sync the files to S3
    #deletes file from dest if they are not in source.
    aws s3 sync $line $bucketTarget"/"$drive$path --delete

    #or don't delete.  Comment the line above, uncomment the one below.
    #write-host "aws s3 sync " $line $bucketTarget"/"$drive$path
    }


$now = date -format "yyyyMMdd"

#create the output file name
$out = "s3_content_$now.txt" 

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


#report
"Total size stored in the target location:" | out-file ($out) ascii
"$GB GB" | out-file ($out) ascii -Append
$content | out-file ($out) ascii -Append


write-host "$num files stored on S3.  Full list recorded to $out"
write-host "Total size stored in the target location:  $GB GB"

