#!/bin/bash

# description: synching folders
#   using rsync over ssh
# author: flo.alt@fa-netz.de
# version: 0.6

# unset variables
    unset errorcount
    unset failcount
    unset thiserrcount

# read config
    scriptpath=$(dirname "$(readlink -e "$0")")
    scriptname="$(basename $(realpath $0))"

    source $scriptpath/config
    source $scriptpath/functions


# set some variables
    errorcount=0
    failcount=0
    thiserrcount=0
    startsync="$(date +%d.%m.%Y-%H%M)"
    logfile="$logdir"/"$logname"-"$startsync".log
    errorlog="$logdir"/"$logname"-"$startsync".err
    ssh_syncpath="$ssh_user"@"$ssh_host":"$ssh_dir"

# start logging
    if [[ ! -d $logdir ]]; then mkdir -p $logdir; fi
    touch "$scriptpath"/lastsync-start
    echo -e $headline \\n\
         \\b"Ausgeführt von $scriptpath/$scriptname" \\n\
         \\b"Sync gestartet $(date +%d.%m.%y-%h:%m)" \\n\
         > "$logfile"

# test the connection
    ssh -i "$ssh_key" $ssh_user@$ssh_host "touch $ssh_dir/testfile" 2> >(tee $errorlog)
    if [[ $? = 0 ]]; then
        yeah="OK: Schreibtest auf Sync-Ziel erfolgreich"
        shit="FAIL: Kann im Sync-Ziel nichts löschen."
        ssh -i "$ssh_key" $ssh_user@$ssh_host "rm $ssh_dir/testfile"; failcheck
    else
        failcount=1
        shit="FAIL: Schreibtest auf Sync-ziel fehlgeschlagen"
        failcheck
    fi

# check source path

    if [[ -x $sync_from ]]; then failcount=0; else failcount=1; fi
    yeah="OK: Test Zugriff auf Quell-Ordner $sync_from erfolgreich"
    shit="FAIL: Kein Zugriff auf Quell-Ordner $sync_from"
    failcheck       


# start backing up
    
    echo -e "\n" >> $logfile

    yeah="\nOK: Sync erfolgreich durchgeführt"
    shit="\nFAIL: Sync (teilweise) fehlgeschlagen"
    rsync -avz --delete --exclude 'last-success' -e ssh $sync_from $ssh_syncpath | tee -a $logfile; errorcheck


# the end
    
    # set markerfiles
    if [[ $errorcount -eq 0 ]];then cp "$logfile" "$logdir"/last-success.log; fi
    if [[ $errorcount -eq 0 ]] && [[ $marker_ssh -eq 1 ]]; then
        ssh -i "$ssh_key" $ssh_user@$ssh_host "touch $ssh_dir/last-success"
    fi
    touch "$scriptpath"/lastsync-stop

    # in case of error
    if [[ $errorcount -gt 0 ]];then exitwitherror; fi