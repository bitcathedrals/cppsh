#! /usr/bin/env bash


case $1 in
  "macos-tools")
    brew install bear build2
    ;;
  "macos-reverse")
    brew install binutils
    ;;
  *)
cat <<HELP
cc.sh

macos-tools   = install macos cpp tools using brew
macos-reverse = install reverse engineering tools
HELP
    ;;
esac
