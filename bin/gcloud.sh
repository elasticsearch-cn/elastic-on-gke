#!/bin/bash

# Author: Bin Wu <binwu@google.com>

pwd=`pwd`

__usage() {
    echo "Usage: ./bin/gcloud.sh {install|init|update|kubectl}"
}

# https://cloud.google.com/sdk/docs/downloads-interactive
__inst_quiet() {
    curl https://sdk.cloud.google.com > $pwd/bin/gcloud_install.sh \
        && bash $pwd/bin/gcloud_install.sh --disable-prompts \
        && rm -f $pwd/bin/gcloud_install.sh

    exec -l $SHELL

    __init
}

__inst() {
    curl https://sdk.cloud.google.com | bash

    exec -l $SHELL

    __init
}

__init() {
    gcloud init
}

__update() {
    gcloud components update
}

__kubectl() {
    gcloud components install kubectl
}

__main() {
    if [ $# -eq 0 ]
    then
        __usage
    else
        case $1 in
            install)
                #__inst
                __inst_quiet
                ;;
            init)
                __init
                ;;
            update)
                __update
                ;;
            kubectl)
                __kubectl
                ;;
            *)
                __usage
                ;;
        esac
    fi
}

__main $@
