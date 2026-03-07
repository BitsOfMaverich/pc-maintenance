
# need pip install pyyaml

import os
import subprocess
import yaml
import posixpath
import shlex

def load_config(path):
    with open(path, 'r') as f:
        return yaml.safe_load(f)

def run_sync(include_path, config):
    include_path = os.path.abspath(include_path)
    bucket = config['s3_bucket']
    storageclass = config['storageclass']
    prefix = config.get('s3_prefix', '').strip('/')
    exclude_list = [os.path.abspath(e) for e in config.get('exclude', [])]

    # S3 target: s3://bucket/prefix/D/path/to/dir
    drive, tail = os.path.splitdrive(include_path)
    drive_letter = drive.strip(":").upper()
    rel_tail = tail.lstrip("\\/")

    s3_key_path = posixpath.join(prefix, drive_letter, rel_tail.replace("\\", "/"))
    s3_target = f"s3://{bucket}/{s3_key_path}"

    cmd = ['aws', 's3', 'sync', include_path, s3_target, '--delete', '--storage-class', storageclass]

    for excl in exclude_list:
        if os.path.commonpath([include_path, excl]) == include_path:
            rel_excl = os.path.relpath(excl, include_path).replace("\\", "/")
            cmd += ['--exclude', rel_excl + '/*']

    print("Running:", ' '.join(shlex.quote(arg) for arg in cmd))
    subprocess.run(cmd)

if __name__ == "__main__":
    config = load_config('backup_config.yaml')
    for path in config['include']:
        run_sync(path, config)
