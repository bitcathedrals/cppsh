#! /usr/bin/env bash

debian_based="clang libclang-dev lldb gdb binutils autoconf bear"


BUILD2_BUILD_DIR=build2
BUILD2_BUILD_PATH=$HOME/tools/build/$BUILD2_BUILD_DIR
BUILD2_VERSION=0.17.0

INSTALL_DIR=$HOME/tools/local
INSTALL_BIN=$INSTALL_DIR/bin

function prep_for_build {
  build_dir=$1

  mkdir -p $HOME/tools/bin
  mkdir -p $HOME/tools/build/$build_dir
}

function compile_build2 {
  if [[ -x $INSTALL_BIN/b ]]
  then
    return 0
  fi

  prep_for_build "build2"

  BUILD2_INSTALLER=build2-install-${BUILD2_VERSION}.sh

  if [[ ! -f $BUILD2_BUILD_PATH/$BUILD2_INSTALLER ]] 
  then 
    (cd $BUILD2_BUILD_PATH && curl -sSfO https://download.build2.org/${BUILD2_VERSION}/$BUILD2_INSTALLER)

    if [[ $? -ne 0 ]]
    then
      return 1
    fi
  fi

  (cd $BUILD2_BUILD_PATH && \
        chmod u+x $BUILD2_INSTALLER  && \
        sh $BUILD2_INSTALLER \
        --local \
        $INSTALL_DIR)

  return $?
}

case $1 in
  "macos-tools")
    brew install bear build2 binutils retdec capstone
    ;;
  "ubuntu")
      eval "doas apt install $debian_based" && \
      compile_build2
    ;;
  "kali")
      eval "doas apt install $debian_based imhex"
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
