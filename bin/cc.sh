#! /usr/bin/env bash

compile_based="clang libclang-dev lldb \
gdb binutils autoconf \
bear \
musl musl-dev musl-tools"

CAPSTONE_VERSION="4"

capstone_debian="libcapstone-dev capstone-tool libcapstone${CAPSTONE_VERSION} python3-capstone"

BUILD2_BUILD_DIR=build2
BUILD2_BUILD_PATH=$HOME/tools/build/$BUILD2_BUILD_DIR
BUILD2_VERSION=0.17.0

BUILD_DIR=$HOME/tools/build
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

function install_musl_clang {
  test -d $BUILD_DIR/musl-clang && return 0

  git clone https://github.com/esjeon/musl-clang.git $BUILD_DIR/musl-clang
  cp $BUILD_DIR/musl-clang/musl-clang $INSTALL_BIN/
  chmod u+x $INSTALL_BIN/musl-clang
}

case $1 in
  "macos-tools")
    brew install bear build2 binutils retdec capstone
    ;;
  "ubuntu")
      eval "doas apt install $compile_debian $capstone_debian" && \
      compile_build2 && \
      install_musl_clang
    ;;
  "kali")
      eval "doas apt install $compile_debian $capstone_debian imhex" && \
      compile_build2 && \
      install_musl_clang
    ;;
  "capstone-python")
      pipenv install capstone
      exit $?
    ;;
  *)
cat <<HELP
cc.sh

macos-tools      = macos tools install
ubuntu           = ubuntu tools install
kali             = kali tools install
capstone-python  = install python bindings for capstone
HELP
    ;;
esac
