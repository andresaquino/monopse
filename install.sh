#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai et: 

# install.sh -- instalar monopse en el directorio
# =-=
#
# Developer
# Andres Aquino <aquino@hp.com>
# 

echo "[1] - Creating structure..."
mkdir -p ~/bin
mkdir -p ~/manuals/man1

echo "[2] - Migrating all config files to new version..."
[ -d ~/monopse ] && cp -rp ~/monopse/setup/*.conf ~/monopse.git/setup/
[ -d ~/monopse ] && cp -rp ~/monopse/monopserc ~/monopse.git/

echo "[3] - Switching to new version..."
cd ~
[ -d ~/monopse.old ] && rm -fr ~/monopse.old
[ -d ~/monopse ] && mv ~/monopse ~/monopse.old
[ -d ~/monopse.git ] && mv ~/monopse.git ~/monopse

echo "[4] - Installing unix documentation..."
cp ~/monopse/man1/monopse.1 ~/manuals/man1/
ln -sf ~/monopse/monopserc ~/.monopserc
ln -sf ~/monopse/monopse.sh ~/monopse/monopse

echo "[5] - Fixing permissiont..."
chmod 0640 ~/monopse/install.sh 
chmod 0750 ~/monopse/monopse.sh

echo "[*] - That's all..."
