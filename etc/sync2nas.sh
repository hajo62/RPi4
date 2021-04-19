#!/bin/bash
set -e                          # Stop batch on error
timestamp=`date "+%Y%m%d"`      # Timestamp for delete files folder name

CHECK_PATH() {
    # Check if 'from' and 'to' directories are available
    if ! [ -d $from_dir ]; then
        echo "ERROR: Quelle $from_dir nicht vorhanden."
        exit 1
    fi
    if ! [ -d $to_dir ]; then
        echo "ERROR: Ziel $to_dir nicht vorhanden."
        exit 1
    fi
}

SYNC() {
    # Pattern for filenames to exclude from sync
    exclude="--exclude=.DS_Store
             --exclude=._*  
             --exclude=*-hold 
             --exclude=.XnViewSort 
             --exclude=.dtrash 
             --exclude=.* 
             --exclude=*~"  
    bwlimit="--bwlimit=2000"               # Speed limit for transfer - i.e. 1000 = 1000 kb/s

    flags=--verbose                         # Tell what you are doing
    flags=$flags" "--archive                # Archive mode
    flags=$flags" "--no-owner
    flags=$flags" "--partial                # Leave partially copied files to restart after a break
    flags=$flags" "$exclude                 # Exclude files - see above
    flags=$flags" "$bwlimit                 # Limit band width
    #flags=$flags" "--modify-window=2
    flags=$flags" "--human-readable
    flags=$flags" "--inplace
    flags=$flags" "--delete" -b "--backup-dir=$backup_dir/${1}
    #flags=$flags" "--dry-run                # Modify nothing, just simulate

    # Create rsync command - be careful with () and ""
    rsync_cmd=( /usr/bin/rsync $flags "$from_dir/${1}" "$to_dir/${2}" )
    echo "${rsync_cmd[@]}"
    "${rsync_cmd[@]}"
}

# This part runs on my new Raspberry Pi
if [ `hostname` == "rpi4b" ];
  then
    from_dir=/home/hajo/docker-volumes/Nextcloud/data/hajo/files/Photos
    to_dir=/nfs/Photos_wd
    backup_dir="$to_dir/deleted/deleted-$timestamp"    # Folder name to put the removed files

    echo "Running on Pi..."
    echo -e "Synching from $from_dir to $to_dir\n"
    CHECK_PATH

    # IMPORTANT: No / at the end of the directory name.
    for subdir in   "2020"          \
                    "2010-2019"     \
                    "2000-2009"     \
                    "1990-1999"     \
                    "1980-1989"       
    do
        SYNC "${subdir}/"  "${subdir}"

        # Aktualisieren der Nextcloud-DB. Wird nur benötigt, wenn Dateien auf die NC kopiert werden.
        # docker exec --user www-data nextcloud nice php occ files:scan --path="/hajo/files/Photos/${subdir}"
    done
fi