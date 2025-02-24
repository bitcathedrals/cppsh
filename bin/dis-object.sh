#! /usr/bin/env bash

system=`uname`

file=$1

if [[ ! -f $file ]]
then
  echo "path $file does not exist."
  exit 1
fi

case $system in
  "Darwin")
    otool -t -v -L $file
    exit $?
    ;;
  "help")
    cat <<HELP
dis-object.sh

disassemble code from an object file

dis-object.sh <file>
HELP
    ;;
  *)
    echo "arch: $arch is unsupported"
    exit 1
    ;;
esac
