#! /usr/bin/env bash

compile_debian="build-essential \
clang libclang-dev lldb \
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

CONFIG_FILE=cppsh.sh

function prep_for_build {
  build_dir=$1

  mkdir -p $HOME/tools/bin
  mkdir -p $HOME/tools/build/$build_dir
}

function compile_build2 {
  if [ -x $INSTALL_BIN/b ]
  then
    return 0
  fi

  prep_for_build "build2"

  BUILD2_INSTALLER=build2-install-${BUILD2_VERSION}.sh

  if [ ! -f $BUILD2_BUILD_PATH/$BUILD2_INSTALLER ] 
  then 
    (cd $BUILD2_BUILD_PATH && curl -sSfO https://download.build2.org/${BUILD2_VERSION}/$BUILD2_INSTALLER)

    if [ $? -ne 0 ]
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

#
# globals
#

TOOLCHAIN_NAME=""
TOOLCHAIN_SIGNATURE=""

function print_global_settings {
  echo "cc.sh [info]: TOOLCHAIN_NAME = ${TOOLCHAIN_NAME}"
  echo "cc.sh [info]: TOOLCHAIN_SIGNATURE = ${TOOLCHAIN_SIGNATURE}"
  echo "cc.sh [info]: TOOLCHAIN_PATH = ${TOOLCHAIN_PATH}"
}

#
# project paths
#

PROJECT_ROOT=""
PROJECT_BUILD2=""
PROJECT_SRC=""
PROJECT_BIN=""
PROJECT_DEPS=""
PROJECT_TOOLING=""

function global_project_paths {
  load_config_file $1

  PROJECT_ROOT=$1

  PROJECT_BUILD2="${PROJECT_ROOT}/${NAME}/"
  PROJECT_SRC="${PROJECT_ROOT}/${NAME}/${NAME}/"
  PROJECT_BIN="${PROJECT_ROOT}/bin/"
  PROJECT_TOOLING="${PROJECT_ROOT}/tooling/"

  PROJECT_DEPS="${PROJECT_ROOT}/deps/"
  return 0
}

function load_config_file {
  config="${1}/cppsh.sh"

  if [ ! -f $config ]
  then
    return 1    
  fi

  if [ $NOP == "true" ]
  then
    echo "cc.sh [nop] (global_project_paths): found config file ${config}, loading it."
  fi

  source $config

}

function print_project_paths {
  echo "cc.sh [info]: PROJECT_ROOT = ${PROJECT_ROOT}"
  echo "cc.sh [info]: PROJECT_BUILD2 = ${PROJECT_BUILD2}"
  echo "cc.sh [info]: PROJECT_SRC = ${PROJECT_SRC}"
  echo "cc.sh [info]: PROJECT_BIN = ${PROJECT_BIN}"
  echo "cc.sh [info]: PROJECT_DEPS = ${PROJECT_DEPS}"
  echo "cc.sh [info]: PROJECT_TOOLING = ${PROJECT_TOOLING}"
}

function create_project_paths {
  if [ -d $PROJECT_BUILD2 ]
  then
    echo "cc.sh [warning] (create_project_paths): found existing build2 project: $PROJECT_BUILD2."
  fi

  test -d $PROJECT_BIN || mkdir -p $PROJECT_BIN
  test -d $PROJECT_DEPS || mkdir -p $PROJECT_DEPS
  test -d $PROJECT_TOOLING || mkdir -p $PROJECT_TOOLING

  deps_lib=()
  deps_headers=()

  repo_lib=()
  repo_headers=()

  for format in ${OBJECT_FORMAT[@]}
  do
    deps_path="${PROJECT_DEPS}/${HOST}/${format}/lib"
    headers_path="${PROJECT_DEPS}/${HOST}/${format}/include"

    deps_lib+=("${deps_path}")
    deps_headers+=("${headers_path}")

    test -d ${deps_path} || mkdir -p ${deps_path}
    test -d ${headers_path} || mkdir -p ${headers_path}

    repo_path="${REPO}/${HOST}/${format}/lib"
    headers_path="${REPO}/${HOST}/${format}/include"

    test -d $repo_path || mkdir -p $repo_path
    test -d $headers_path || mkdir -p $headers_path

    repo_lib+=("${repo_path}")
    repo_headers+=("${headers_path}")
  done

  OBJECT_PATHS=${deps_lib[@]}
  OBJECT_PATHS+=${repo_lib[@]}

  HEADER_PATHS=${deps_headers{@]}
  HEADER_PATHS+=${repo_headers[@]}
}

function debug_ascend {
  echo "print_dirs: $1"
  return 1
}

function ascend_anscestor_paths {
  this_dir=$(echo $1 | tr -s '/')
  this_dir=$(echo $this_dir | sed -e 's,/$,,g')

  if [ $NOP == "true" ]
  then
    echo "cc.sh [nop] (ascend_anscetor_paths): current directory $this_dir"
  fi

  callback=$2

  while [ -n $this_dir ]
  do
    echo "ascend debug callback = $callback $this_dir"

    eval "$callback $this_dir"

    if [ $? -eq 0 ]
    then
      return 0
    fi

    this_dir=$(echo $this_dir | sed -e 's,\(.*\)/[^/]*$,\1,')
  done

  return 1
}

function global_project_root {
 ascend_anscestor_paths $PWD global_project_paths

 ascend=$?

 if [ $ascend -ne 0 ]
 then
    echo >/dev/stderr "cc.sh [error]: (global_project_root) ascend_ancestor_paths failed with $ascend"
  fi

  return 0
}

function test_paths {
  project_root
  print_project_paths
}


#
# platform helpers
# 

function global_host {
  HOST=$(uname)
}

#
# argument-less functions
# 

function toolchain_list {
  bdep-config list
  return 0;
}

#
# simple name argument functions
#

function tooling_delete {
  name=$1

  if [ ! -d ${PROJECT_TOOLING}$name ]
  then
    return 0
  fi

  echo >/dev/stderr "cc.sh (exec): deleting old tooling $name"

  if [ $NOP == "true" ]
  then
    echo "cc.sh [NOP] (exec): (cd ${PROJECT_TOOLING} && rm -r ${name})"
    return 0
  fi

  (cd ${PROJECT_TOOLING} && rm -r ${name})      
  return $?
}

function canonicalize_suite_and_options {
  echo "canonical input = $*"

  # sort so we get the same name every invocation in any order
  canonical=$(echo "$*" | tr ' ' '\n' | sort -u | tr '\n' '-')
  canonical=$(echo "$canonical" | sed -e 's,-$,,g')

  TOOLCHAIN_PATH="${PROJECT_TOOLING}${TOOLCHAIN_NAME}${canonical}"
  TOOLCHAIN_SIGNATURE="${TOOLCHAIN_NAME}${canonical}"
}

# compile directive settings

CLANG_COMPILER=""
CLANGXX_COMPILER=""

GCC_COMPILER=""
GXX_COMPILER=""

GCC_PROCESSOR=""
GXX_PROCESSOR=""

MACHO_LINK=""
ELF_LINK=""

LIBRARIES=""

CC_HEADERS=""
CC_OBJECTS=""
CC_LIBS=""

GCC_OPTION=""
GXX_OPTION=""

CLANG_OPTION=""
CLANGXX_OPTION=""

GCC_AFTER=""
GXX_AFTER=""

CLANG_AFTER=""
CLANGXX_AFTER=""

GCC_TARGET=""
CLANG_TARGET=""

GXX_TARGET=""
CLANGXX_TARGET=""

BUILD2_OPTIONS=""

LANGUAGE_PRIMARY=""
LANGUAGE_SECONDARY=""

SUITE_PRIMARY=""
SUITE_SECONDARY=""

HOST=""

OBJECT_FORMAT=()
OBJECT_PATHS=()
HEADER_PATHS=()

VERBOSE=""

BUILD2_SPECIFICATION=""

function print_cc_settings {
  echo "cc.sh [info] toolchain BUILD2_TYPE = \"$BUILD2_TYPE\""
  echo "cc.sh [info] toolchain BUILD2_TYPE_OPTIONS = \"$BUILD2_TYPE_OPTIONS\""

  echo "cc.sh: [info] suite CLANG_COMPILER = \"$CLANG_COMPILER\""
  echo "cc.sh: [info] suite CLANGXX_COMPILER = \"$CLANGXX_COMPILER\""

  echo "cc.sh: [info] suite GCC_COMPILER = \"$GCC_COMPILER\""
  echo "cc.sh: [info] suite GXX_COMPILER = \"$GXX_COMPILER\""

  echo "cc.sh: [info] suite GCC_PROCESSOR = \"$GCC_PROCESSOR\""
  echo "cc.sh: [info] suite GXX_PROCESSOR = \"$GXX_PROCESSOR\""

  echo "cc.sh: [info] suite GCC_OPTION = \"$GCC_OPTION\""
  echo "cc.sh: [info] suite GXX_OPTION = \"$GXX_OPTION\""

  echo "cc.sh: [info] suite CLANG_OPTION = \"$CLANG_OPTION\""
  echo "cc.sh: [info] suite CLANGXX_OPTION = \"$CLANGXX_OPTION\""

  echo "cc.sh: [info] suite ELF_LINK = \"$ELF_LINK\""
  echo "cc.sh: [info] suite MACHO_LINK = \"$MACHO_LINK\""

  echo "cc.sh: [info] suite CC_HEADERS = \"$CC_HEADERS\""
  echo "cc.sh: [info] suite CC_OBJECTS = \"$CC_OBJECTS\""
  echo "cc.sh: [info] suite CC_LIBS = \"$CC_LIBS\""

  echo "cc.sh: [info] suite GCC_AFTER = \"$GCC_AFTER\""
  echo "cc.sh: [info] suite GXX_AFTER = \"$GXX_AFTER\""

  echo "cc.sh: [info] suite CLANG_AFTER = \"$CLANG_AFTER\""
  echo "cc.sh: [info] suite CLANGXX_AFTER = \"$CLANGXX_AFTER\""

  echo "cc.sh: [info] suite LANGAUGE_PRIMARY = \"$LANGUAGE_PRIMARY\""
  echo "cc.sh: [info] suite LANGUAGE_SECONDARY = \"$LANGUAGE_SECONDARY\""

  echo "cc.sh: [info] toolchain HOST = \"$HOST\""
  echo "cc.sh: [info] toolchain OBJECT_FORMAT = \"${OBJECT_FORMAT[@]}\""

  echo "cc.sh: [info] toolchain OBJECT_PATHS = \"${OBJECT_PATHS[@]}\""
  echo "cc.sh: [info] toolchain HEADER_PATHS = \"${$HEADER_PATHS[@]}\""
  echo "cc.sh: [info] toolchain LIBRARIES = \"${LIBRARIES[@]}\""

  echo "cc.sh: [info] toolchain GCC_TARGET = \"$GCC_TARGET\""
  echo "cc.sh: [info] toolchain GXX_TARGET = \"$GXX_TARGET\""
  echo "cc.sh: [info] toolchain CLANG_TARGET = suite \"$CLANG_TARGET\""
  echo "cc.sh: [info] toolchain CLANGXX_TARGET = \"$CLANGXX_TARGET\""

  echo "cc.sh: [info] toolchain SUITE_PRIMARY = \"$SUITE_PRIMARY\""
  echo "cc.sh: [info] toolchain SUITE_SECONDARY = \"$SUITE_SECONDARY\""

  echo "cc.sh: [info] VERBOSE = \"$VERBOSE\""

  echo "cc.sh: [info] suite BUILD2_OPTIONS = \"$BUILD2_OPTIONS\""
  echo "cc.sh: [info] suite BUILD2_SPECIFICATION = \"$BUILD2_SPECIFICATION\""
}

#
# cc compiler selection
#

function set_build2_options {
  build2_job_options="-v --progress --diag-color"

  case $HOST in
    "Darwin")
       cores=$(sysctl -n hw.ncpu)

       if [ -n $cores ]
       then
         build2_job_options="$build2_job_options --jobs $cores"
       fi
    ;;
  esac
}

function set_object_format {
  case $HOST in
    "Darwin")
      OBJECT_FORMAT=("elf" "mach-o")
    "Linux")
      OBJECT_FORMAT=("elf")
    ;;
    *)
      echo "cc.sh [error] (set_object_format) host: $HOST unsupported for setting object format. exiting."
      exit 1
    ;;
  esac
}

function set_cc_compiler_directive {
  language=$1
  suite=$2
  directive=$3

  compiler_tuple="${language}_${suite}_${directive}"

  case "$compiler_tuple" in
    # static

    "c_clang_static")
      CLANG_OPTION="$CLANG_OPTION -static"
    ;;
    "c++_clang_static")
      CLANGXX_OPTION="$CLANGXX_OPTION -static"
    ;;
    "c_gcc_static")
      GCC_OPTION="$GCC_OPTION -static -static-libgcc"
    ;;
    "c++_gcc_static")
      GXX_OPTION="$GXX_OPTION -static -static-libgcc -static-libstdc++"
    ;;

    # MUSL

    "c_gcc_musl")
      GCC_COMPILER="musl-gcc"
    ;;

     # analyzer. clang has a much more complicated analyzer support

    "c_gcc_analyzer")
      GCC_OPTION="$GCC_OPTION -fanalyzer"
    ;;
    "c++_gcc_analyzer")
      GXX_OPTION="$GXX_OPTION -fanalyzer"
    ;;

    # canary all

    "c_clang_canary-all")
      CLANG_OPTION="$CLANG_OPTION -fstack-protector-all"
    ;;
    "c++_clang_canary-all")
      CLANGXX_OPTION="$CLANGXX_OPTION -fstack-protector-all"
    ;;

    "c_gcc_canary-all")
      GCC_OPTION="$GCC_OPTION -fstack-protector-all"
    ;;
    "c++_gcc_canary-all")
      GXX_OPTION="$GXX_OPTION -fstack-protector-all"
    ;;

    # maximum warnings

    "c_clang_warn-max")
      CLANG_OPTION="$CLANG_OPTION -Wall -Werror"
    ;;
    "c++_clang_warn-max")
      CLANGXX_OPTION="$CLANGXX_OPTION -Wall -Werror"
    ;;

    "c_gcc_warn-max")
      GCC_OPTION="$GCC_OPTION -Wall -Werror"
    ;;
    "c++_gcc_warn-max")
      GXX_OPTION="$GXX_OPTION -Wall -Werror"
    ;;

    # debug
    "c_clang_debug")
      CLANG_OPTION="$CLANG_OPTION -g -glldb"
    ;;
    "c++_clang_debug")
      CLANGXX_OPTION="$CLANGXX_OPTION -g -glldb"
    ;;

    "c_gcc_debug")
      GCC_OPTION="$GCC_OPTION -g3 -ggdb"
    ;;
    "c++_gcc_debug")
      GXX_OPTION="$GXX_OPTION -g3 -ggdb"
    ;;

    # optimization

    "c_clang_fast")
      CLANG_OPTION="$CLANG_OPTION -O2"
      CLANG_LINK="$CLANG_LINK -fflto -ffat-lto-objects"
    ;;
    "c++_clang_fast")
      CLANGXX_OPTION="$CLANGXX_OPTION -O2"
      CLANGXX_LINK="$CLANGXX_OPTION -fflto -ffat-lto-objects"
    ;;

    "c_gcc_fast")
      GCC_OPTION="$GCC_OPTION -O2"
      GCC_LINK="$GCC_LINK -O2 -fflto -ffat-lto-objects"
    ;;
    "c++_gcc_fast")
      GXX_OPTION="$GXX_OPTION -O2"
      GXX_LINK="$GXX_LINK -fflto -ffat-lto-objects"
    ;;

    *)
      if echo "$compiler_tuple" | grep -E 'S'
      then
        lang=`echo $compiler_tuple | cut -d '_' -f 1`
        suite=`echo $compiler_tuple | cut -d '_' -f 2`
        version=`echo $compiler_tuple | cut -d 'S' -f 2`
        
        case $suite in
          "gcc")
            if [ "$lang" == "c" ]
            then
              GCC_OPTION="$GCC_OPTION -std=$version"
              continue
            fi

            if [ "$lang" == "c++" ]
            then
              GXX_OPTION="$GXX_OPTION -std=$version"
              continue
            fi
          ;;
          "clang")
            if [ "$lang" == "c" ]
            then
              CLANG_OPTION="$CLANG_OPTION -std=$version"
              continue
            fi

            if [ "$lang" == "c++" ]
            then
              CLANGXX_OPTION="$CLANGXX_OPTION -std=$version"
              continue
            fi
          ;;
          *)
            echo "cc.sh: [compiler_option]: compiler ($compiler) for standard option not supported by cc.sh"
            exit 1
          ;;
        esac

        continue
      fi

      if echo "$compiler_tuple" | grep -E '^@'
      then
        toolchain_target=`echo "$1" | sed -e 's,^@,,'`

        shift
        continue
      fi

      echo "cc.sh: [compiler_option]: compiler tuple ($compiler_tuple) not supported by cc.sh"
      exit 1
    ;;
  esac
}

function set_cc_headers_and_objects {
  read -ra libraries <<<"$LIBRARIES"

  # The host usually indicates common switches for library paths and includes.
  # Use this assumption until it breaks and we need to specificy a SUITE for
  # headers and objects. 
  case $HOST in
    "Darwin"|"Linux")
      for path in ${OBJECT_PATHS[@]}
      do
        if [ -d $path ]
        then
          CC_OBJECTS="${CC_OBJECTS} -L${path}"
        fi
      done
 
      for path in ${HEADER_PATHS[@]}
      do
        if [ -d $path ]
        then
          CC_HEADERS="${CC_HEADERS} -I${path}"
        fi
      done

      for lib in ${libraries[@]}
      do
        CC_LIBS="${CC_LIBS} -l${lib}"
      done
    ;;
  esac
}

function set_cc_default_compiler {
  if [ "$SUITE_PRIMARY" == "clang" ]
  then
    if [ "$LANGUAGE_PRIMARY" == "c" ] || [ "$LANGUAGE_SECONDARY" == "c" ]
    then
      if [ -z $CLANG_COMPILER ]
      then
        CLANG_COMPILER="clang"
      fi
    fi
  fi
      
  if [ "$SUITE_PRIMARY" == "clang" ]
  then
    if [ "$LANGUAGE_PRIMARY" == "c++" ] || [ "$LANGUAGE_SECONDARY" == "c++" ]
    then
      if [ -z $CLANGXX_COMPILER ]
      then
        CLANGXX_COMPILER="clang++"
      fi
    fi
  fi
      
  if [ "$SUITE_PRIMARY" == "gcc" ]
  then
    if [ "$LANGUAGE_PRIMARY" == "c" ] || [ "$LANGUAGE_SECONDARY" == "c" ]
    then
      if [ -z $GCC_COMPILER ]
      then
        GCC_COMPILER="gcc"
      fi
    fi
  fi
      
  if [ "$SUITE_PRIMARY" == "gcc" ]
  then
    if [ "$LANGUAGE_PRIMARY" == "c++" ] || [ "$LANGUAGE_SECONDARY" == "c++" ]
    then
      if [ -z $GXX_COMPILER ]
      then
        GXX_COMPILER="g++"
      fi
    fi
  fi
}

function process_cc_arguments {
  TOOLCHAIN_NAME=$1
  shift

  # Options That Are appended to type spec
  BUILD2_TYPE=""
  BUILD2_TYPE_OPTIONS=""

  primary_directives=""
  secondary_directives=""

  for argument in $@
  do
    if [ "$NOP" == "true" ]
    then
      echo "cc.sh [info] (process_cc_arguments) argument = \"$argument\""
    fi

    case $argument in
      "verbose")
        VERBOSE="true"
        continue
      ;;
      "tests")
        BUILD2_TYPE_OPTIONS="${BUILD2_TYPE_OPTIONS},unit-tests"
        continue
      ;;
      "exe")
        BUILD2_TYPE="exe"
        continue
      ;;
      "lib")
        BUILD2_TYPE="lib,split"
        continue
      ;;
      "tool")
        SUITE='build2'
        continue
      ;;
    esac

    if echo "$argument" | grep -E '^-'
    then
      if [ -z $LIBRARIES ]
      then
        LIBRARIES="$argument"
      else     
        LIBRARIES="$LIBRARIES $argument"
      fi

      continue
    fi

    if echo "$argument" | grep -E ','
    then
      primary=`echo $argument | cut -d ',' -f 1`
      secondary=`echo $argument | cut -d ',' -f 2`

      if [ -z $LANGUAGE_PRIMARY ]
      then
        LANGUAGE_PRIMARY=$primary
        LANGUAGE_SECONDARY=$secondary

        continue
      fi

      if [ -z $SUITE_PRIMARY ]
      then
        SUITE_PRIMARY=$primary
        SUITE_SECONDARY=$secondary

        continue
      fi

      echo "cc.sh [warning] (proccess_cc_arguments) language/suite spec $argument already set both language and suite, skipping."
      continue
    fi

    if echo "$argument" | grep -E ':'
    then
      lang=`echo $argument | cut -d ':' -f 1`
      option=`echo $argument | cut -d ':' -f 2`

      if [ "$lang" == "$LANGUAGE_PRIMARY" ]
      then
        primary_directives="$primary_directives $option"
        continue
      fi

      if [ "$lang" == "$LANGUAGE_SECONDARY" ]
      then
        secondary_directives="$secondary_directives $option"
        continue
      fi

      echo "cc.sh [error]: option langauge $lang != primary or secondary langauge. exiting"
      exit 1
    fi

    # default is both
    primary_directives="$primary_directives $argument"

    if [ -n $LANGUAGE_SECONDARY ]
    then
      secondary_directives="$secondary_directives $argument"
    fi
  done
}

function exec_cc_core {
  global_host
  set_build2_options

  process_cc_arguments $@

  if [ "$NOP" == "true" ]
  then
    echo "cc.sh [info] (exec_cc_core): finished argument processing."
    echo "cc.sh [info] (exec_cc_core): primary_directives = $primary_directives"
    echo "cc.sh [info] (exec_cc_core): secondary_directives = $secondary_directives"
  fi

  set_object_format

  read -ra primary <<<"$primary_directives"

  for option in ${primary[@]}
  do
    set_cc_compiler_directive $LANGUAGE_PRIMARY $SUITE_PRIMARY $option
  done

  if [ "$secondary_directives" != "" ]
  then
    read -ra secondary <<<"$secondary_directives"

    for option in ${secondary[@]}
    do
      set_cc_compiler_directive $LANGUAGE_SECONDARY $SUITE_SECONDARY $option
    done
  fi

  set_cc_default_compiler

  set_cc_headers_and_objects
}

function emit_cc_compiler {
  if [ "$GCC_COMPILER" != "" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.c=\"$GCC_COMPILER $GCC_OPTION $toolchain_target $GCC_AFTER\""
  fi

  if [ "$GXX_COMPILER" != "" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.cxx=\"$GXX_COMPILER $GXX_OPTION $toolchain_target $GXX_AFTER\""
  fi

  if [ "$CLANG_COMPILER" != "" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.c=\"$CLANG_COMPILER $CLANG_OPTION $toolchain_target $CLANG_AFTER\""
  fi

  if [ "$CLANGXX_COMPILER" != "" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.cxx=\"$CLANGXX $CLANGXX_OPTION $toolchain_target $CLANGXX_AFTER\""
  fi
}

function emit_cc_headers_and_libraries {
  # if primary and secondary use different switches we will move this to a loop
  # over object format
  case $HOST in
    "Darwin"|"Linux")
      link=""

      if [ "$VERBOSE" == "true" ]
      then
        link="-V"
      fi

      if [ "$ELF_LINK" != "" ]
      then
        link="$link $ELF_LINK"
      fi

    ;;
    *)
      echo "cc.sh [error] (emit_cc_headers_and_objects) object format $format no supported. exiting."
      exit 1
    ;;
  esac  

  link="${link} ${CC_OBJECTS} ${CC_LIBS}"

  if [ "$link" != "" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.cc.loptions=\"$link\""
  fi

  if [ -n "${CC_HEADERS}" ]
  then
    BUILD2_SPECIFICATION="$BUILD2_SPECIFICATION config.cc.poptions=\"${CC_HEADERS}\""
  fi
}

function emit_cc_core {
  case $1 in
    "create")
      build2_operation="-C"
    ;;
    "add")
      build2_operation="-A"
    ;;
    *)
      echo "cc.sh: [error] (emit_cc_core) unknown build2 operation $1"
      exit 1
    ;;
  esac

  spec="$build2_job_options $build2_operation @${TOOLCHAIN_NAME} cc -t $BUILD2_TYPE"

  if [ "$BUILD2_TYPE_OPTIONS" != "" ]
  then
    spec="${spec},$BUILD2_TYPE_OPTIONS"
  fi

  spec="${spec} -l $LANGUAGE_PRIMARY"
  
  if [ -n $LANGUAGE_SECONDARY ]
  then
    spec="${spec},${LANGUAGE_SECONDARY}"
  fi  

  BUILD2_SPECIFICATION="${BUILD2_SPECIFICATION} $spec"

  emit_cc_compiler

  emit_cc_headers_and_libraries

  BUILD2_SPECIFICATION=`echo ${BUILD2_SPECIFICATION} | tr -s ' '`
}

function generate_cc_create {
  load_config_file

  global_project_root

  create_project_paths

  # canonicalize a spec so we can get a unique and consistent name
  # from those options, produces option_list
  canonicalize_suite_and_options $@

  exec_cc_core $@
  emit_cc_core "create"

  BUILD2_SPECIFICATION="bdep new $BUILD2_SPECIFICATION"
}

function generate_cc_add {
  exec_cc_core $@
  emit_cc_core "add"

  BUILD2_SPECIFICATION="bdep $BUILD2_SPECIFICATION"
}

function run_build2 {
  datetime=`date`

  echo "cc.sh [info] RUN $datetime"

  if [ $NOP == "true" ]
  then
    print_global_settings
    print_project_paths

    print_cc_settings

    return 0
  fi

  echo "cc.sh [exec]: $BUILD2_SPECIFICATION"

  eval "$BUILD2_SPECIFICATION"
  status=$?

  print "cc.sh [exec] RUN exited with $status"
  return $status
}

if [ $1 == "-n" ]
then
  NOP="true"
  shift
fi

case $1 in
  "macos")
    if [ $NOP == "true" ]
    then
      echo "exec: brew install bear build2 binutils retdec capstone git-flow"
      exit 1
    fi

    brew install bear build2 binutils retdec capstone git-flow
    ;;
  "ubuntu")
    if [ $NOP == "true" ]
    then
      echo "exec: doas apt install $compile_debian $capstone_debian" && \
      echo "call: compile_build2"
      exit 1
    fi

    eval "doas apt install $compile_debian $capstone_debian" && \
    compile_build2
    ;;
  "kali")
    if [ $NOP == "true" ]
    then
      eval "exec: doas apt install $compile_debian $capstone_debian imhex" && \
      echo "call: compile_build2"
      exit 1
    fi

    eval "doas apt install $compile_debian $capstone_debian imhex" && \
    compile_build2
    ;;
  "capstone-python")
      if [ $NOP == "true" ]
      then
        echo "exec: pipenv install capstone"
        echo "call: compile_build2"
        exit 1
      fi

      pipenv install capstone
      exit $?
    ;;
    "build2/tool")
      generate_cc_tool
    ;;
    "cc/create")
      shift

      echo "cc.sh [command] (cc/create): creating exe project"

      generate_cc_create $@

      run_build2
      exit $?
    ;;
    "cc/add")
      shift

      echo "cc.sh [command] (cc/create): creating exe project"

      generate_cc_add $@

      run_build2
      exit $?
    ;;
    "test")
      shift

      load_config_file
      global_project_root

      if [ $NOP == "true" ]
      then
        echo "cc.sh [NOP] (exec): (cd ${PROJECT_BUILD2} && b test $*)"
        exit 0
      fi

      (cd ${PROJECT_BUILD2} && b test $@)
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

cc/create <NAME> <COMPILER> <-tests?> = create a C program with <NAME> and <COMPILER>
cc/add    <NAME> <COMPILER> <-tests?> = create a C library with <NAME> and <COMPILER>

build   = build the project
test    = run test suite
info    = print configuration info
HELP
    ;;
  *)

    global_project_root

    if [ $NOP == "true" ]
    then
      echo "cc.sh [NOP] (exec): (cd ${PROJECT_BUILD2} && b $*)"
      exit 0
    fi
      
    (cd ${PROJECT_BUILD2} && b -v $@)
    exit $?
  ;; 
esac
