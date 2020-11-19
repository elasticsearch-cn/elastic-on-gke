#!/bin/bash

PWD=$(
    cd "$(dirname "$0")"
    pwd
)
export PWD
MODULE=
ACT=

if [ ! -d "$PWD/deploy" ];then
    mkdir "$PWD/deploy"
fi


__usage() {
    echo "Usage: $0 -m module -a action [-o]"
    echo "    -m ./bin 目录下的脚本"
    echo "        可选的参数有" $(ls "$PWD" | sed 's/.sh//g')
    echo "    -a 脚本需要的参数"
    echo "    -o [可选参数] 显示脚本执行过程，相当于 bash -x "
    exit
}

if [ $# -eq 0 ]
then
    __usage
fi

GETOPTOUT=$(getopt 'm:a:oh' "$@")
set - $GETOPTOUT
while [ -n "$1" ]; do
    case $1 in
    -m)
        MODULE=$2
        shift
        ;;
    -a)
        ACT=$2
        shift
        ;;
    -o)
        XSH="-x"
        shift
        ;;
    -h)
        __usage
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Unknow arg:"$1""
        ;;
    esac
    shift
done

# export variables
if [ ! -f "$PWD"/../conf/configure.ini ]; then
    echo "need conf/configure.ini"
    exit 1
fi

source "$PWD"/../conf/configure.ini
export $(grep -v '^#' "$PWD"/../conf/configure.ini | awk NF | cut -d= -f1)

# set -x -e

if [ -s "$PWD/aio_$MODULE.sh" ]; then
    if [ $ACT ]; then
        echo "exec : "bash $XSH aio_$MODULE.sh $ACT $XARG
        exec bash $XSH "$PWD"/aio_$MODULE.sh $ACT $XARG
    else
        echo "need action"
        echo "exit 1"
        exit 1
    fi
fi

