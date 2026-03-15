Usage for restic on Windows


# install
winget install --exact --id restic.restic --scope Machine


# configure .aws
    get-content ~\.aws\config

        [profile maintenance]
        region = us-east-2
        output = json

    get-content ~\.aws\credentials
        
        [maintenance]
        aws_access_key_id = foo
        aws_secret_access_key = foo 


# password
generate a random string


# init
# one time at setup
    
    $env:RESTIC_REPOSITORY="s3:s3.amazonaws.com/richardhall-backup/restic/marsha"
    $env:RESTIC_PASSWORD_FILE="c:\Users\Marsha\Documents\pc-maintenance\restic-backup\.restic-pass_marsha"
    $env:AWS_PROFILE="maintenance"

    restic init

        created restic repository 3e5b0afcb0 at s3:s3.amazonaws.com/richardhall-backup/restic/null