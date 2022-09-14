#!/bin/bash

# description: backing up some config / data files
#   using rdiff backup over ssh
#   using a list of folders to backup
# author: flo.alt@fa-netz.de
# version: 0.63

# unset variables
    unset backup_list
    unset backup_from
    unset errorcount
    unset failcount
    unset thiserrcount

# read config
    scriptpath=$(dirname "$(readlink -e "$0")")
    scriptname="$(basename $(realpath $0))"

# read files
    source $scriptpath/config
    source $scriptpath/functions


# set some variables
    errorcount=0
    failcount=0
    thiserrcount=0
    startbak="$(date +%d.%m.%Y-%H:%M)"
    logfile="$logdir"/"$logname"-"$startbak".log
    errorlog="$logdir"/"$logname"-"$startbak".err
    ssh_bakpath="$ssh_user"@"$ssh_host"::"$ssh_dir"
    if [[ ! -z $backup_list ]]; then backup_list="$scriptpath/$backup_list"; fi

# start logging
    if [[ ! -d $logdir ]]; then mkdir -p $logdir; fi
    touch "$scriptpath"/lastbackup-start
    echo -e $headline \\n\
         \\b"Ausgeführt von $scriptpath/$scriptname" \\n\
         \\b"Backup gestartet $startbak" \\n\
         > "$logfile"
  #  (   # start append all outputs to $logfile

# test the connection
    ssh -i "$ssh_key" $ssh_user@$ssh_host "touch $ssh_dir/testfile" 2> >(tee $errorlog)
    if [[ $? = 0 ]]; then
        yeah="OK: Schreibtest auf Backup-Ziel erfolgreich"
        shit="FAIL: Kann im Backup-Ziel nichts löschen."
        ssh -i "$ssh_key" $ssh_user@$ssh_host "rm $ssh_dir/testfile"; failcheck
    else
        failcount=1
        shit="FAIL: Schreibtest auf Backup-ziel fehlgeschlagen"
        failcheck
    fi

# check sources

    # check single folder
    if [[ ! -z $backup_folder ]]; then
        if [[ -x $backup_folder ]]; then failcount=0; else failcount=1; fi
        yeah="OK: Test Zugriff auf Quell-Ordner $backup_folder erfolgreich"
        shit="FAIL: Kein Zugriff auf Quell-Ordner $backup_folder"
        failcheck       
    fi

    # check list of folders
    if [[ ! -z $backup_list ]]; then

        # read from folderlist
        tac $backup_list > /tmp/tacfolders
        # cut all lines beginning with "-" and output in variable $folders
        folders=$(sed /^-.*/d /tmp/tacfolders)
        
        for folder in $folders; do
            yeah="OK: Test Zugriff auf Quell-Ordner $folder erfolgreich"
            shit="FAIL: Kein Zugriff auf Quell-Ordner $folder"
            if [[ -x $folder ]]; then thiserrcount=0; else thiserrcount=1; fi
            errorcheck
        done

        rm /tmp/tacfolders
    fi

    # fail if neither folder nor list
    if [[ -z $backup_folder ]] && [[ -z $backup_list ]]; then
        failcount=1
        shit="FAIL: Es ist keine Backup-Quelle definiert (weder einzelner Ordner noch Liste)"
        failcheck
    fi

    # start backing up
        
        echo -e "\n" >> $logfile

        # backup a single folder
        if [[ ! -z $backup_folder ]]; then
            yeah="\nOK: Backup erfolgreich durchgeführt"
            shit="\nFAIL: Backup (teilweise) fehlgeschlagen"
            (rdiff-backup --force --print-statistics -v0 $backup_from $ssh_bakpath; failcheck)| tee -a $logfile
        fi

        # backup a list of folders
        if [[ ! -z $backup_list ]]; then
            echo -e "\n"
            yeah="\nOK: Backup erfolgreich durchgeführt"
            shit="\nFAIL: Backup (teilweise) fehlgeschlagen"
            (rdiff-backup --force --print-statistics --include-globbing-filelist $backup_list / $ssh_bakpath; failcheck) | tee -a $logfile
        fi


# the end
    
    # set markerfiles
    if [[ $errorcount -eq 0 ]];then cp "$logfile" "$logdir"/last-success.log; fi
    if [[ $errorcount -eq 0 ]] && [[ $marker_ssh -eq 1 ]]; then
        ssh -i "$ssh_key" $ssh_user@$ssh_host "touch $ssh_dir/last-success"
    fi
    touch "$scriptpath"/lastbackup-stop

    # in case of error
    if [[ $errorcount -gt 0 ]];then exitwitherror; fi