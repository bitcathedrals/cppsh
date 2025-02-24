#! /usr/bin/env bash

debian_based="clang libclang-dev lldb gdb binutils autoconf build2"

case $1 in
  "macos-tools")
    brew install bear build2 binutils capstone
    ;;
  "ubuntu")
      eval "doas apt install $debian_based"
    ;;
  "kali")
      eval "doas apt insatll $debian_based imhex"
    ;;
  *)
cat <<HELP
cc.sh

macos-tools   = macos tools install
ubuntu        = ubuntu tools install
kali          = kali tools install
HELP
    ;;
esac
