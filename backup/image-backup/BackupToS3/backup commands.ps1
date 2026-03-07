


#exclude list. make this into a paramater.
$excludeFile = "D:\backupScript\exclude.txt"

#the directory or drive to backup.  make this a parameter.
$backupTarget = "D:\backupScript\src"


#get all directories in the tree 
$dirlist = Get-ChildItem -Recurse $backupTarget | ?{ $_.PSIsContainer } | Select-Object FullName

#get the list of directories to ignore.
$excludelist = get-content $excludeFile


foreach ($dir in $dirlist) {
    $dir
    pause

    $filelist = gci $dir | where { ! $_.PSIsContainer }

    foreach ($file in $filelist) {
        $file
        
        $archivebit = "$dir\$file".attributes -band [io.fileattributes]::archive
        
        "archivebit:  $archivebit"
        pause
        }
    }




