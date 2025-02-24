#! /usr/bin/env bash

system=`uname`

spec=$1
out=$2

file=$(echo "$spec" | cut -d ':' -f 1)
section=$(echo "$spec" | cut -d ':' -f 2)

if [[ ! -f $file ]]
then
  echo "path $file does not exist."
  exit 1
fi

case $system in
  "Darwin")
    objcopy -O binary --only-section=$section $file $out

    exit $?
    ;;
  "help")
    cat <<HELP
bin-extract.sh

extract a section from an object file. System specific.

bin-extract.sh <file>:section <output file>
HELP
    ;;
  *)
    echo "arch: $arch is unsupported"
    exit 1
    ;;
esac
