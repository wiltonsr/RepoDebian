#!/bin/bash

#abort in error
set -e

LOCATION="/var/www/html";
REPOSITORIES="debian";
DISTRIBUTION="stable";
COMPONENTS="main contrib non-free";
ARCHITECTURES="i386 amd64 all";
#colors
BOLD="\e[1m"
RED="\e[31m${BOLD}"
GREEN="\e[32m${BOLD}"
YELLOW="\e[33m${BOLD}"
WHITE="\e[97m${BOLD}"
NC="\e[0m" # no-color

function validRepositories() {
  set -e
  cd $LOCATION
  local VALID_REPOS=""
  for REPO in $(ls); do
    if [[ ( -d "${REPO}/dists" ) && ( -d "${REPO}/pool" ) ]]; then
      VALID_REPOS+=$REPO
      VALID_REPOS+=" "
    fi
  done
  echo "$VALID_REPOS"
}

function listDistDirs() {
  set -e
  REPOSITORY=$1
  DISTRIBUTION=$(ls $LOCATION/$REPOSITORY/dists)
  echo "$DISTRIBUTION"
}

function listCompDirs() {
  set -e
  REPOSITORY=$1
  DISTRIBUTION=$2
  local COMPONENTS=""
  for COMP in $(ls $LOCATION/$REPOSITORY/dists/$DISTRIBUTION); do
    if [[ -d "$LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP" ]]; then
      COMPONENTS+=$COMP
      COMPONENTS+=" "
    fi
  done
  echo "$COMPONENTS"
}

function updateDistReleaseConf () {
  set -e
  REPOSITORIES=$1
  DISTRIBUTION=$2
  ARCHITECTURES=$3
  ALL_COMPS=$(listCompDirs $REPOSITORIES $DISTRIBUTION)

cat << EOF > $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/release.conf
APT::FTPArchive::Release::Codename "$DISTRIBUTION";
APT::FTPArchive::Release::Components "$ALL_COMPS";
APT::FTPArchive::Release::Label "Debian Caixa Economica Federal";
APT::FTPArchive::Release::Architectures "$ARCHITECTURES";
EOF
}

function isLocationWritable () {
  set -e
  mkdir -p $LOCATION
  if ! [ -w $LOCATION ]; then
    echo "You don't have permission to write in ${LOCATION}"
    exit 1
  else
    return 0
  fi
}

function listArchDirs () {
  set -e
  REPOSITORY=$1
  DISTRIBUTION=$2
  COMP=$3
  cd $LOCATION/$REPOSITORY
  local ARCHITECTURES=$(ls -d dists/$DISTRIBUTION/$COMP/binary* |
  awk '{n=split($1,A,"-"); print A[n]}' |
  tr '\n' ' ')
  echo "$ARCHITECTURES"
}

# Create repository
function createRepo () {
  set -e
  if isLocationWritable; then
    mkdir -p $LOCATION/$REPOSITORIES/{dists,pool}
    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        mkdir -p $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/$COMP/binary-$ARCH
cat << EOF > $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/$COMP/binary-$ARCH/release.conf
APT::FTPArchive::Release::Codename "$DISTRIBUTION";
APT::FTPArchive::Release::Components "$COMP";
APT::FTPArchive::Release::Label "Debian Caixa Economica Federal";
APT::FTPArchive::Release::Architectures "$ARCH";
EOF
      done
      mkdir -p $LOCATION/$REPOSITORIES/pool/$DISTRIBUTION/$COMP
    done

    updateDistReleaseConf $REPOSITORIES $DISTRIBUTION "$ARCHITECTURES"

    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        cd $LOCATION/$REPOSITORIES
        apt-ftparchive -a $ARCH packages pool/$DISTRIBUTION/$COMP > $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
        gzip -kf $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
      done
    done

    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        cd $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION/$COMP/binary-$ARCH
        apt-ftparchive release -c release.conf . > Release
      done
    done

    cd $LOCATION/$REPOSITORIES/dists/$DISTRIBUTION
    apt-ftparchive release -c release.conf . > Release
  fi
}

# Update repository
function updateRepo() {
  set -e
  if isLocationWritable; then
    for REPOSITORY in $REPOSITORIES; do
      if [ "$FLAG_DISTRIBUTION" != "1" ]; then
        DISTRIBUTION=$(listDistDirs $REPOSITORY)
      fi
      for DIST in $DISTRIBUTION; do
        if [ "$FLAG_COMPONENTS" != "1" ]; then
          COMPONENTS=$(listCompDirs $REPOSITORY $DIST)
        fi
        for COMP in $COMPONENTS; do
          cd $LOCATION/$REPOSITORY
          if [ "$FLAG_ARCHITECTURES" != "1" ]; then
            ARCHITECTURES=$(listArchDirs $REPOSITORY $DIST $COMP)
          fi
          for ARCH in $ARCHITECTURES; do
            apt-ftparchive -a $ARCH packages pool/$DIST/$COMP > $LOCATION/$REPOSITORY/dists/$DIST/$COMP/binary-$ARCH/Packages
            gzip -kf $LOCATION/$REPOSITORY/dists/$DIST/$COMP/binary-$ARCH/Packages
          done
        done

        for COMP in $COMPONENTS; do
          cd $LOCATION/$REPOSITORY
          if [ "$FLAG_ARCHITECTURES" != "1" ]; then
            ARCHITECTURES=$(listArchDirs $REPOSITORY $DIST $COMP)
          fi
          for ARCH in $ARCHITECTURES; do
            cd $LOCATION/$REPOSITORY/dists/$DIST/$COMP/binary-$ARCH
            apt-ftparchive release -c release.conf > Release
          done
        done

        updateDistReleaseConf $REPOSITORY $DIST "$ARCHITECTURES"
        cd $LOCATION/$REPOSITORY/dists/$DIST
        apt-ftparchive release -c release.conf . > Release
      done
    done
  fi
}

# Delete repository
function deleteRepo() {
  set -e
  if isLocationWritable; then
    if [[ "$FLAG_REPOSITORIES" != "1" &&
      "$FLAG_DISTRIBUTION" != "1" &&
      "$FLAG_COMPONENTS" != "1" ]]; then
      for REPOSITORY in $REPOSITORIES; do
        rm -rf $LOCATION/$REPOSITORY
      done
    elif [[ "$FLAG_REPOSITORIES" == "1" &&
      "$FLAG_DISTRIBUTION" != "1" &&
      "$FLAG_COMPONENTS" != "1" ]]; then
      for REPOSITORY in $REPOSITORIES; do
        rm -rf $LOCATION/$REPOSITORY
      done
    elif [[ "$FLAG_REPOSITORIES" == "1" &&
      "$FLAG_DISTRIBUTION" == "1" &&
      "$FLAG_COMPONENTS" != "1" ]]; then
      for REPOSITORY in $REPOSITORIES; do
        for DIST in $DISTRIBUTION; do
          rm -rf $LOCATION/$REPOSITORY/dists/$DIST
          rm -rf $LOCATION/$REPOSITORY/pool/$DIST
        done
      done
    elif [[ "$FLAG_REPOSITORIES" == "1" &&
      "$FLAG_DISTRIBUTION" == "1" &&
      "$FLAG_COMPONENTS" == "1" ]]; then
      for REPOSITORY in $REPOSITORIES; do
        for DIST in $DISTRIBUTION; do
          for COMP in $COMPONENTS; do
            rm -rf $LOCATION/$REPOSITORY/dists/$DIST/$COMP
            rm -rf $LOCATION/$REPOSITORY/pool/$DIST/$COMP
            FLAG_COMPONENTS=0
            updateRepo
          done
        done
      done
    fi
  fi
}
# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  repo-deb.sh -m create|update|delete [-l <location>] [-r <repository>] [-d <distribution>] [-c '<list of components>'] [-a '<list of architectures>']"
  echo "  repo-deb.sh -h (print this message)"
  echo "    -m <mode> - one of 'create' or 'update'"
  echo "      - 'create' - create all folders structure to start an Debian Repository"
  echo "      - 'update' - update an existing Debian Repository"
  echo "      - 'delete' - delete an existing Debian Repository, distribution or components"
  echo "    -l <location> - filesystem location served by a webserver"
  echo "      (defaults to '${LOCATION}')"
  echo "    -r <repository> - name"
  echo "      (defaults to '${REPOSITORIES}')"
  echo "    -d <distribution> - specifies a subdirectory in \$repo/dists."
  echo "      (defaults to '${DISTRIBUTION}')"
  echo "    -c <components> - specifies the subdirectories in \$repo/dists/\$distribution"
  echo "      (defaults to '${COMPONENTS}')"
  echo "    -a <architectures> - specifies the architectures of repository"
  echo "      (defaults to '${ARCHITECTURES}')"
  echo "      Note: Architecture all is always created"
  echo "    -f <force> - no prompt for confirmation"
  echo
}

# Ask user for confirmation to proceed
function askProceed () {
  set -e
  if [ "$FORCE" == "1" ]; then
    ans=y
  else
    read -p "Continue (y/n)? " ans
  fi
  case "$ans" in
    y|Y )
      echo "proceeding ..."
      echo
      ;;
    n|N )
      echo "exiting..."
      echo
      exit 1
      ;;
    * )
      echo "invalid response"
      echo
      askProceed
      ;;
  esac
}

# Parse commandline args
while getopts ":m:l:r:d:c:a:hf" opt; do
  case "$opt" in
    m)  MODE=$OPTARG
      ;;
    l)  LOCATION=$OPTARG
      ;;
    r)  REPOSITORIES=$OPTARG
        FLAG_REPOSITORIES=1
      ;;
    d)  DISTRIBUTION=$OPTARG
        FLAG_DISTRIBUTION=1
      ;;
    c)  COMPONENTS=$OPTARG
        FLAG_COMPONENTS=1
      ;;
    a)  ARCHITECTURES=$OPTARG
        FLAG_ARCHITECTURES=1
      ;;
    f)  FORCE=1
      ;;
    h|\?)
      printHelp
      exit 0
      ;;
    :)
      echo "Missing option argument for -$OPTARG" >&2
      exit 2
      ;;
  esac
done

if ! [[ $ARCHITECTURES == *"all"* ]]; then
  ARCHITECTURES=$ARCHITECTURES" all";
fi

# Determine whether creating or updating
if [ "$MODE" == "create" ]; then
  EXPMODE="Creating"
  echo -e "${GREEN}${EXPMODE}${NC} repository '${WHITE}${REPOSITORIES}${NC}' in '${WHITE}${LOCATION}${NC}' from '${WHITE}${DISTRIBUTION}${NC}' distribution with '${WHITE}${COMPONENTS}${NC}' components and '${WHITE}${ARCHITECTURES}${NC}' architectures."
  echo
elif [ "$MODE" == "update" ]; then
  EXPMODE="Updating"
  if [ "$FLAG_REPOSITORIES" != "1" ]; then
    REPOSITORIES=$(validRepositories)
  fi
  for REPO in $REPOSITORIES; do
    if [ "$FLAG_DISTRIBUTION" != "1" ]; then
      DISTRIBUTION=$(listDistDirs $REPO)
    fi
    for DIST in $DISTRIBUTION; do
      if [ "$FLAG_COMPONENTS" != "1" ]; then
        COMPONENTS=$(listCompDirs $REPO $DIST)
      fi
      echo -e "${YELLOW}${EXPMODE}${NC} repository '${WHITE}${REPO}${NC}' in '${WHITE}${LOCATION}${NC}' from '${WHITE}${DIST}${NC}' distribution with '${WHITE}${COMPONENTS}${NC}' components."
      echo
    done
  done
elif [ "$MODE" == "delete" ]; then
  EXPMODE="Deleting"
  if [ "$FLAG_REPOSITORIES" != "1" ]; then
    REPOSITORIES=$(validRepositories)
  fi
  for REPO in $REPOSITORIES; do
    if [ "$FLAG_DISTRIBUTION" != "1" ]; then
      DISTRIBUTION=$(listDistDirs $REPO)
    fi
    for DIST in $DISTRIBUTION; do
      if [ "$FLAG_COMPONENTS" != "1" ]; then
        COMPONENTS=$(listCompDirs $REPO $DIST)
      fi
      echo -e "${RED}${EXPMODE}${NC} repository '${WHITE}${REPO}${NC}' in '${WHITE}${LOCATION}${NC}' from '${WHITE}${DIST}${NC}' distribution with '${WHITE}${COMPONENTS}${NC}' components."
      echo
    done
  done
else
  echo "Specify a valid execution mode."
  echo
  printHelp
  exit 1
fi


# ask for confirmation to proceed
askProceed

command -v apt-ftparchive >/dev/null 2>&1 || { echo >&2 "I required apt-ftparchive but it's not installed.  Aborting."; exit 1; }

if [ "${MODE}" == "create" ]; then
  createRepo
  echo "All done!"
  echo "Put this in your source.list"
  echo "deb [trusted=yes] http://repository-address.com/$REPOSITORIES $DISTRIBUTION $COMPONENTS"
elif [ "${MODE}" == "update" ]; then
  updateRepo
  echo "All done!"
elif [ "${MODE}" == "delete" ]; then
  deleteRepo
  echo "All done!"
else
  printHelp
  exit 1
fi
