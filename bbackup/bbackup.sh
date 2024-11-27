#!/bin/bash

# description: Borg Backup Script
#   pulling from source host via sshfs
#   to local (iSCSI) borg repository
# author: flo.alt@fa-netz.de
# version: 0.1


#### this has neven been finished.....




# unset variables
    unset errorcount
    unset failcount
    unset thiserrcount

# where am I, how am I?
    scriptpath=$(dirname "$(readlink -e "$0")")
    scriptname="$(basename $(realpath $0))"

# read files
    source $scriptpath/config
    source $scriptpath/functions

# export some variables
    export BORG_PASSPHRASE=$repo_passphrase
    export BORG_REPO=$repository
    export BORG_RSH='ssh -oBatchMode=yes'


# Mount the remote directory using SSHFS

    echo "Mounting $ssh_host:$ssh_dir to $mountpoint"
    sshfs -o IdentityFile="$ssh_key",allow_other $ssh_user@$ssh_host:$ssh_dir "$mountpoint" 



# start backup

    borg create                     \
        --show-version              \
        --list                      \
        --stats                     \
        --show-rc                   \
        $BORG_REPO::"$server"__{now}  \
        $mountpoint\folder1         \
        $mountpoint\folder2


# Prune old backups

    echo "Entfernen alter Backups..."
    borg prune \
        --keep-daily=7 \
        --keep-weekly=4 \
        --keep-monthly=6


# final steps

    umount $mountpoint