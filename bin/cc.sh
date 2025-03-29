#! /usr/bin/env bash

compile_debian="clang libclang-dev lldb \
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

NOP=""

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

function create_project_paths {
  name=$1

  PROJECT_ROOT=$PWD
  PROJECT_BUILD2="${PWD}/${name}/"
  PROJECT_SRC="${PROJECT_BUILD2}/${name}/${name}/"
  PROJECT_BIN="${PWD}/bin/"
  PROJECT_DEPS="${PWD}/deps/"
  PROJECT_TOOLING="${PWD}/tooling/"

  if [[ -d ${PROJECT_BUILD2} ]]
  then
    if [[ $NOP == "true" ]]
    then
      echo "would have skipped create over pre-exising project"
    else
      echo "cc.sh [error] create_project_paths: ${name} - found existing build2 project, aborting."
      exit 1    
    fi
  fi

  test -d $PROJECT_BIN || mkdir -p $PROJECT_BIN
  test -d $PROJECT_DEPS || mkdir -p $PROJECT_DEPS
  test -d $PROJECT_TOOLING || mkdir -p $PROJECT_TOOLING

  return 0
}

function set_project_paths {
  if [[ ! -f $1/"cppsh.sh" ]]
  then
    return 1    
  fi

  build2=$(cat ${1}/build2.name)

  PROJECT_ROOT=$1
  PROJECT_BUILD2="${1}/${build2}/"
  PROJECT_SRC="${1}/${build2}/${build2}/"
  PROJECT_BIN="${1}/bin/"
  PROJECT_DEPS="${1}/deps/"
  PROJECT_TOOLING="${1}/tooling/"

  return 0
}

function print_ascend {
  echo "print_dirs: $1"
  return 1
}

function print_project_paths {
  echo "PROJECT_ROOT = ${PROJECT_ROOT}"
  echo "PROJECT_BUILD2 = ${PROJECT_BUILD2}"
  echo "PROJECT_SRC = ${PROJECT_SRC}"
  echo "PROJECT_BIN = ${PROJECT_BIN}"
  echo "PROJECT_DEPS = ${PROJECT_DEPS}"
  echo "PROJECT_TOOLING = ${PROJECT_TOOLING}"
}

function ascend_anscestor_paths {
  this_dir=$(echo $1 | tr -s '/')
  this_dir=$(echo $this_dir | sed -e 's,/$,,g')

  callback=$2

  while [[ -n $this_dir ]]
  do
    eval "$callback $this_dir"

    if [[ $? -eq 0 ]]
    then
      return 0
    fi

    this_dir=$(echo $this_dir | sed -e 's,\(.*\)/[^/]*$,\1,')
  done

  return 1
}

function project_root {
  ascend_anscestor_paths $PWD set_project_paths

  if [[ $1 -ne 0 ]]
  then
    echo >/dev/stderr "cc.sh [error]: no cppsh.sh configuration file found"
    exit 1
  fi

  source ${PROJECT_ROOT}/cppsh.sh

  if [[ -z $REPO ]]
  then
    echo >/dev/stderr "cc.sh [error]: cppsh.sh does not define REPO"
    exit 1
  fi

  test -d $REPO || mkdir -p $REPO
  test -d $REPO/include || mkdir -p $REPO/include

  return 0
}

function test_paths {
  project_root
  print_project_paths
}

# echo "test" >../build2.name
#test_paths
#exit 0

function toolchain_list {
  bdep-config list
  return 0;
}

function tooling_create {
  name=$1
  shift

  if [[ $NOP == "true" ]]
  then
    echo "cc.sh [NOP] (call): (cd ${PROJECT_BUILD2} && bdep config create -v --diag-color --progress -- @${name} ${PROJECT_TOOLING}/${name} $*)"
  fi  

  eval "(cd ${PROJECT_ROOT} && bdep config create -v --diag-color --progress -- @${name} ${PROJECT_TOOLING}/${name} $*)"
  return $?
}

function c_configuration {
  compiler=$1
  shift

  spec="@${compiler} cc "

  if [[ -n $SWITCHES ]]
  then
    spec="$spec config.c.coptions=\"$SWITCHES\" "
    spec="$spec config.cxx.coptions=\"$SWITCHES\" "
  fi

  if [[ -n $C_SWITCHES ]]
  then
    spec="$spec config.c.coptions=\"$C_SWITCHES\" "
  fi

  if [[ -n $CPP_SWITCHES ]]
  then
    spec="$spec config.cxx.coptions=\"$CPP_SWITCHES\" "
  fi

#  spec="$spec config.c.poptions=\"-I${REPO}/include -I${PROJECT_DEPS}/include/\" "
#  spec="$spec config.c.loptions=\"-L${REPO}/$compiler/ -L${PROJECT_DEPS}/$compiler/\" "

#  spec="$spec config.cxx.poptions=\"-I${REPO}/include -I${PROJECT_DEPS}/include/\" "
#  spec="$spec config.cxx.loptions=\"-L${REPO}/$compiler -L${PROJECT_DEPS}/$compiler/\" "

  spec="$spec $*"
}

function c_tooling_spec {
  compiler=$1
  shift

  test -d $REPO/$compiler || mkdir -p $REPO/$compiler

  case $compiler in
    "gcc")
      c_configuration $compiler config.c=gcc config.cxx=g++
      status=$?

      if [[ $status -ne 0 ]]
      then
        echo >/dev/stderr "cc.sh [error] calling c_configuration: config.c=gcc config.cxx=g++"
        return $status
      fi

      c_tooling="-C ${PROJECT_TOOLING}$compiler $spec"
    ;; 
    "clang")
        c_configuration $compiler config.c=clang config.cxx=clang++
        status=$?

        if [[ $status -ne 0 ]]
        then
          echo >/dev/stderr "cc.sh [error] calling c_configuration: config.c=clang config.cxx=clang++"
          return $status
        fi

        c_tooling="-C ${PROJECT_TOOLING}$compiler $spec"
      ;;

    "gcc-musl")
        c_configuration $compiler config.c=gcc-musl config.cxx=g++
        status=$?

        if [[ $status -ne 0 ]]
        then
          echo >/dev/stderr "cc.sh [error] calling c_configuration: config.c=gcc-musl config.cxx=g++"
          return $status
        fi

        c_tooling="-C ${PROJECT_TOOLING}$compiler $spec"
      ;; 
    "clang-musl")
        c_configuration $compiler config.c=clang-musl config.cxx=clang++
        status=$?

        if [[ $status -ne 0 ]]
        then
          echo >/dev/stderr "cc.sh [error] calling c_configuration: config.c=clang-musl config.cxx=clang++"
          return $status
        fi

        c_tooling="-C ${PROJECT_TOOLING}/$compiler $spec"
      ;;
    *)
      echo >/dev/stderr "cc.sh [error] c_tooling_spec: ${compiler} is not supported"
      exit 1
    ;;
  esac
}

function c_new {
  name=$1
  compiler=$2
  type=$3

  if [[ $NOP == "true" ]]
  then
    echo "cc.ssh [NOP] (args): name=$name compiler=$compiler type=$type"
  fi

  create_project_paths $name

  if [[ $? -ne 0 ]]
  then
    echo >/dev/stderr "cc.sh [error]: create_project_paths failed. aborting."
    exit 1
  fi

  if [[ $type == "exe" ]]
  then
    type_spec="-t exe,unit-tests"
  else
    type_spec="-t lib,split,unit-tests"
  fi

  if [[ $NOP == "true" ]]
  then
    echo "cc.sh [NOP] (call): c_tooling_spec($compiler)"
  fi

  c_tooling_spec $compiler

  echo >/dev/stderr "cc.sh (exec): exec bdep new -l c,c++ ${type_spec} $name ${c_tooling}"

  if [[ $NOP == "true" ]]
  then
    echo "cc.sh [NOP] (exec): bdep new -v -l c,c++ ${type_spec} $name ${c_tooling}"
  else
    eval "bdep new -v -s none -l c,c++ ${type_spec} $name ${c_tooling}"
  fi

  echo >>.gitignore <<IGNORE
${name}/.build2
tooling/
bin/
*.so
IGNORE

  echo "$name" >build2.name

  return 0;
}

if [[ $1 == "-nop" ]]
then
  NOP="true"
  shift
fi

case $1 in
  "macos")
    if [[ $NOP == "true" ]]
    then
      echo "exec: brew install bear build2 binutils retdec capstone git-flow"
      exit 1
    fi

    brew install bear build2 binutils retdec capstone git-flow
    ;;
  "ubuntu")
    if [[ $NOP == "true" ]]
    then
      echo "exec: doas apt install $compile_debian $capstone_debian" && \
      echo "call: compile_build2"
      exit 1
    fi

    eval "doas apt install $compile_debian $capstone_debian" && \
    compile_build2
    ;;
  "kali")
    if [[ $NOP == "true" ]]
    then
      eval "exec: doas apt install $compile_debian $capstone_debian imhex" && \
      echo "call: compile_build2"
      exit 1
    fi

    eval "doas apt install $compile_debian $capstone_debian imhex" && \
    compile_build2
    ;;
  "capstone-python")
      if [[ $NOP == "true" ]]
      then
        echo "exec: pipenv install capstone"
        echo "call: compile_build2"
        exit 1
      fi

      pipenv install capstone
      exit $?
    ;;
    "c-exe")
      shift

      name=$1
      compiler=$2

      echo >/dev/stderr "cc.sh -> c-exe: creating exe project $name with compiler $compiler"

      c_new $name $compiler "exe"
      exit $?
    ;;
    "c-lib")
      shift

      name=$1
      compiler=$2

      echo >/dev/stderr "cc.sh -> c-lib: creating lib project $name with compiler $compiler"

      c_new $name $compiler "lib"
      exit $?
    ;;
    "test")
      shift
      project_root

      if [[ $NOP == "true" ]]
      then
        echo "cc.sh [NOP] (exec): (cd ${PROJECT_BUILD2} && b test $*)"
        exit 0
      fi

      (cd ${PROJECT_BUILD2} && b test $@)
      exit $?
    ;;
    "status")
      shift
      project_root

      (cd ${PROJECT_BUILD2} && b status)
      exit $?
    ;;
    "info")
      shift
      project_root

      print_project_paths

      (cd ${PROJECT_BUILD2} && b info)
      exit $?
    ;;
    "help")
      cat <<HELP
cc.sh

macos            = macos tools install
ubuntu           = ubuntu tools install
kali             = kali tools install
capstone-python  = install python bindings for capstone

[create]

c-exe <NAME> <COMPILER> = create a C program with <NAME> and <COMPILER>
c-lib <NAME> <COMPILER> = create a C library with <NAME> and <COMPILER>
build   = build the project
test    = run test suite
status  = report status of project
info    = print configuration info
HELP
    ;;
  "build"|*)
    shift
    project_root

    if [[ $NOP == "true" ]]
    then
      echo "cc.sh [NOP] (exec): (cd ${PROJECT_BUILD2} && b $*)"
      exit 0
    fi
      
    (cd ${PROJECT_BUILD2} && b -v $@)
    exit $?
  ;; 
esac
