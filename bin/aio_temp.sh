#!/bin/bash

# Author: Kasen <kasen@outlook.com>

set -e

__usage() {
    echo "Usage: $0 [debug]"
}


__main() {
    if [ $# -eq 0 ]
    then
        python3 bin/aio_temp.py
    else
        case $1 in
            debug)
                python3 bin/aio_temp.py --debug
                ;;
            nodebug)
                python3 bin/aio_temp.py
                ;;
            *)
                __usage
                ;;
        esac
    fi
}

__main $@
