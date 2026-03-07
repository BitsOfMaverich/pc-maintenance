exit

#untested

#wbadmin can't do incremental or differential backups.

$DTS = date -Uformat %Y-%m-%d
$backupFile = $env:ComputerName + "_$DTS"

#backup D
wbadmin start backup -backupTarget:\\10.0.1.53\Backups\rich\wbadmin\$backupFile -include:d: -exclude:"D:\no backup","D:\My Data Sources","D:\software purchaced" -user rich -password foo -vssFull -quiet

#The list of available backups
#wbadmin get versions

#Delete all copies except the last two (0 delete all backups):
wbadmin delete systemstatebackup -keepversions:2