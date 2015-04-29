#!/bin/bash

# Neutron synchronization slave process to run on the Compute Nodes.

function error() { 
    echo "ERROR: $@"
    exit 1 
}

[ ! -z "$NEUTRON_DIR" ]      || export NEUTRON_DIR=/var/snabbswitch/neutron
[ ! -z "$SNABB_DIR"   ]      || export SNABB_DIR=/var/snabbswitch/networks
[ ! -z "$TMP_DIR"   ]        || export TMP_DIR=/tmp/snabbswitch
[ ! -z "$NEUTRON2SNABB" ]    || export NEUTRON2SNABB="snabb snabbnfv neutron2snabb"
[ ! -z "$SYNC_PATH" ]        || error "check_env_vars: \$SYNC_PATH not set"
[ ! -z "$SYNC_HOST" ]        || error "check_env_vars: \$SYNC_HOST not set"
[ ! -z "$SYNC_INTERVAL" ]    || export SYNC_INTERVAL=1

# Remove old repository if it exists
if [ -d $NEUTRON_DIR ]; then
    rm -rf $NEUTRON_DIR
fi

if [ ! -d $SNABB_DIR ]; then
    mkdir -p $SNABB_DIR
fi

# (Re)create TMP_DIR
if [ -d $TMP_DIR ]; then
    rm -rf $TMP_DIR
fi
mkdir -p $TMP_DIR

initial=true

# Loop pulling/cloning the repo.
while true; do
    if [ ! -d $NEUTRON_DIR ]; then
    git clone git://$SYNC_HOST/$SYNC_PATH $NEUTRON_DIR
    fi
    cd $NEUTRON_DIR
    git fetch
    git diff --quiet origin/master
    if [ $? != 0 -o $initial = true ]; then
        git pull --rebase origin master
        git reflog expire --expire-unreachable=0 --all
        git prune --expire 0
        echo "Generating new configuration"
        $NEUTRON2SNABB $NEUTRON_DIR $TMP_DIR
        # Only (atomically) replace configurations that have changed.
        for conf in $TMP_DIR/*; do
            dest=$SNABB_DIR/$(basename $conf)
            if ! diff $conf $dest; then mv -f $conf $dest; fi
        done
        initial=false
    fi
    sleep $SYNC_INTERVAL
done

