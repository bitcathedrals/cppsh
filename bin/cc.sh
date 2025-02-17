#! /usr/bin/env bash


case $1 in
  "macos-tools")
    brew install bear build2
    ;;
  *)
cat <<HELP
cc.sh

macos-tools   - install macos cpp tools using brew
HELP
    ;;
esac
