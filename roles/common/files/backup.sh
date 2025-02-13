#!/bin/bash
#set -x
# source our config
. /opt/backup/backup.cfg

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Execute pre-exec tasks if configured
if [ ${#PREEXEC[@]} -gt 0 ]; then
    for item in "${PREEXEC[@]}"; do
        eval ${item} 2>/tmp/rsync_output.log
    done
fi

# Prepare include options only if INCLUDE array is not empty
include_opts=""
if [ ${#INCLUDE[@]} -gt 0 ]; then
    for item in "${INCLUDE[@]}"; do
        include_opts+="${item} "
    done
fi

# Prepare exclude options only if EXCLUDE array is not empty
exclude_opts=""
if [ ${#EXCLUDE[@]} -gt 0 ]; then
    for item in "${EXCLUDE[@]}"; do
        exclude_opts+="--exclude=${item} "
    done
fi

# Make sure remote location exists
log "Create remote target directory $REMOTE_PATH if necessary"
ssh -o StrictHostKeyChecking=no -i ${SSHKEY} $REMOTE_USER@$REMOTE_SERVER "mkdir -p $REMOTE_PATH"

# copy each local directory to the remote path
RSYNC_CMD="rsync -avz $exclude_opts --delete --relative -e \"ssh -o StrictHostKeyChecking=no -i ${SSHKEY}\" $include_opts $REMOTE_USER@$REMOTE_SERVER:$REMOTE_PATH"
log "Running command: $RSYNC_CMD"  
if eval $RSYNC_CMD > /tmp/rsync_output.log 2>&1; then
    log "`hostname` backup completed successfully"
else
    log "ERROR: `hostname` backup failed, check /tmp/rsync_output.log"
	exit 1
fi

# Execute post-exec tasks if configured
if [ ${#POSTEXEC[@]} -gt 0 ]; then
    for item in "${POSTEXEC[@]}"; do
        eval ${item} 2>/tmp/rsync_output.log
    done
fi


if [ $? -ne 0 ]; then
    ERROR=1
fi
# Only send an e-mail if it is set
if [ -n "${EMAIL}" ]; then
    if [ ${ERROR} ]; then
        mail -s "rsync backup error for ${REMOTE_PATH}" ${EMAIL} <<< 'Failure'
    else
        mail -s "rsync backup complete for ${REMOTE_PATH}" ${EMAIL} <<< 'Success'
    fi
fi



