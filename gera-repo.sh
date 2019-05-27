#!/bin/bash

ROOT_DIR="/var/www/html"
CODENAME="jessie"
REPOS="ef ec to-th"
COMPONENTS="pl01 pl02 pl03 prd01 prd02"
ARCHITECTURE="binary-i386"

# Cria estrutura de diretorios
for REPO in $REPOS; do
  mkdir -p $ROOT_DIR/$REPO/{dists,pool}
  for COMP in $COMPONENTS; do
    mkdir -p $ROOT_DIR/$REPO/dists/$CODENAME/$COMP/$ARCHITECTURE
    mkdir -p $ROOT_DIR/$REPO/pool/$COMP
  done
  cat << EOF > $ROOT_DIR/$REPO/release.conf 
APT::FTPArchive::Release::Codename "$CODENAME";
APT::FTPArchive::Release::Components "$COMPONENTS";
APT::FTPArchive::Release::Label "Repositório de Pacotes ${REPO^^} Caixa Econômica Federal";
APT::FTPArchive::Release::Architectures "i386";
EOF
done

# Cria o Packages.gz
for REPO in $REPOS; do
  for COMP in $COMPONENTS; do
    cd $ROOT_DIR/$REPO/pool/$COMP
    if [ $(ls -l *.deb 2>/dev/null | wc -l) -gt 0 ]; then
      cd $ROOT_DIR/$REPO
      apt-ftparchive packages pool/$COMP > $ROOT_DIR/$REPO/dists/$CODENAME/$COMP/$ARCHITECTURE/Packages
      gzip -k $ROOT_DIR/$REPO/dists/$CODENAME/$COMP/$ARCHITECTURE/Packages
    fi
  done
done

# Cria o Release
for REPO in $REPOS; do
  for COMP in $COMPONENTS; do
    cd $ROOT_DIR/$REPO/dists/$CODENAME/$COMP/$ARCHITECTURE
    apt-ftparchive release . > Release
  done
  cd $ROOT_DIR/$REPO/dists/$CODENAME
  apt-ftparchive release -c $ROOT_DIR/$REPO/release.conf . > Release
done

