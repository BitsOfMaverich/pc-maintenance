

$bucket = "s3://richardhall-backups-home/targeted-backup/rich"

$now = date -format "yyyyMMdd"

#create the output file name
$out = "s3_content_$now.txt"

#get the list of what's storred
$content = aws s3 ls $bucket --recursive 


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

