#!/bin/bash

#abort in error
set -e

LOCATION="/var/www/html";
REPOSITORY="debian";
DISTRIBUTION="stable";
COMPONENTS="main contrib non-free";
ARCHITECTURES="i386 amd64 all";

function isLocationWritable () {
  mkdir -p $LOCATION
  if ! [ -w $LOCATION ]; then
    echo "You don't have permission to write in ${LOCATION}"
    exit 1
  else
    return 0
  fi
}

function listArchDirs () {
    cd $LOCATION/$REPOSITORY
    DISTRIBUTION=$1
    COMP=$2
    local ARCHITECTURES=$(ls -d dists/$DISTRIBUTION/$COMP/binary* |
    awk '{n=split($1,A,"-"); print A[n]}')
    echo "$ARCHITECTURES"
}

# Create repository
function createRepo () {
  if isLocationWritable; then
    mkdir -p $LOCATION/$REPOSITORY/{dists,pool}
    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        mkdir -p $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH
cat << EOF > $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH/release.conf
APT::FTPArchive::Release::Codename "$DISTRIBUTION";
APT::FTPArchive::Release::Components "$COMP";
APT::FTPArchive::Release::Label "Debian Caixa Economica Federal";
APT::FTPArchive::Release::Architectures "$ARCH";
EOF
      done
      mkdir -p $LOCATION/$REPOSITORY/pool/$DISTRIBUTION/$COMP
    done

cat << EOF > $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/release.conf
APT::FTPArchive::Release::Codename "$DISTRIBUTION";
APT::FTPArchive::Release::Components "$COMPONENTS";
APT::FTPArchive::Release::Label "Debian Caixa Economica Federal";
APT::FTPArchive::Release::Architectures "$ARCHITECTURES";
EOF

    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        cd $LOCATION/$REPOSITORY
        apt-ftparchive -a $ARCH packages pool/$DISTRIBUTION/$COMP > $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
        gzip -kf $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
      done
    done

    for COMP in $COMPONENTS; do
      for ARCH in $ARCHITECTURES; do
        cd $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH
        apt-ftparchive release -c release.conf . > Release
      done
    done

    cd $LOCATION/$REPOSITORY/dists/$DISTRIBUTION
    apt-ftparchive release -c release.conf . > Release
  fi
}

# Update repository
function updateRepo() {
  if [ "$FLAG_DISTRIBUTION" != "1" ]; then
    DISTRIBUTION=$(ls $LOCATION/$REPOSITORY/dists)
  fi
  for DIST in $DISTRIBUTION; do
    if [ "$FLAG_COMPONENTS" != "1" ]; then
      COMPONENTS=$(grep Components $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/Release | \
        cut -d ":" -f2)
    fi
    for COMP in $COMPONENTS; do
      cd $LOCATION/$REPOSITORY
      if [ "$FLAG_ARCHITECTURES" != "1" ]; then
        ARCHITECTURES=$(listArchDirs $DIST $COMP)
      fi
      for ARCH in $ARCHITECTURES; do
        apt-ftparchive -a $ARCH packages pool/$DISTRIBUTION/$COMP > $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
        gzip -kf $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH/Packages
      done
    done

    for COMP in $COMPONENTS; do
      cd $LOCATION/$REPOSITORY
      if [ "$FLAG_ARCHITECTURES" != "1" ]; then
        ARCHITECTURES=$(listArchDirs $DIST $COMP)
      fi
      for ARCH in $ARCHITECTURES; do
        cd $LOCATION/$REPOSITORY/dists/$DISTRIBUTION/$COMP/binary-$ARCH
        apt-ftparchive release -c release.conf > Release
      done
    done

    cd $LOCATION/$REPOSITORY/dists/$DISTRIBUTION
    apt-ftparchive release -c release.conf . > Release
  done
}

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  repo-deb.sh -m create|update [-l <location>] [-r <repository>] [-d <distribution>] [-c '<list of components>'] [-a '<list of architectures>']"
  echo "  repo-deb.sh -h (print this message)"
  echo "    -m <mode> - one of 'create' or 'update'"
  echo "      - 'create' - create all folders structure to start an Debian Repository"
  echo "      - 'update' - update an existing Debian Repository"
  echo "    -l <location> - filesystem location served by a webserver"
  echo "      (defaults to '${LOCATION}')"
  echo "    -r <repository> - name"
  echo "      (defaults to '${REPOSITORY}')"
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
  if [ "$FORCE" == "1" ]; then
    ans=y
  else
    read -p "Continue (y/n)? " ans
  fi
  case "$ans" in
    y|Y )
      echo "proceeding ..."
      ;;
    n|N )
      echo "exiting..."
      exit 1
      ;;
    * )
      echo "invalid response"
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
    r)  REPOSITORY=$OPTARG
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
    h\?)
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
elif [ "$MODE" == "update" ]; then
  EXPMODE="Updating"
else
  echo "Specify a valid execution mode."
  echo
  printHelp
  exit 1
fi

echo "${EXPMODE} repository '${REPOSITORY}' in '${LOCATION}' from '${DISTRIBUTION}' distribution with '${COMPONENTS}' components and '${ARCHITECTURES}' architectures."

# ask for confirmation to proceed
askProceed

command -v apt-ftparchive >/dev/null 2>&1 || { echo >&2 "I required apt-ftparchive but it's not installed.  Aborting."; exit 1; }

if [ "${MODE}" == "create" ]; then
  createRepo
  echo "All done!"
  echo "Put this in your source.list"
  echo "deb [trusted=yes] http://repository-address.com/$REPOSITORY $DISTRIBUTION $COMPONENTS"
elif [ "${MODE}" == "update" ]; then
  updateRepo
  echo "All done!"
else
  printHelp
  exit 1
fi
