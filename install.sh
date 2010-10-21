#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# install.sh -- instalar monopse en el directorio
# =-=
# Developer
# Andres Aquino Morales <andres.aquino@gmail.com>
# 

mkdir -p ~/bin
mkdir -p ~/manuals/man1

cd $HOME

# respaldar setup actual
echo "Migrando configuraciones"
[ -d ~/monopse ] && cp -rp ~/monopse/setup/*-monopse.conf ~/monopse.git/setup/ 

# mover actual como backup
echo "Se respaldo la anterior configuracion en $HOME/monopse.old"
[ -d ~/monopse.old ] && rm -fr ~/monopse.old
[ -d ~/monopse ] && mv ~/monopse ~/monopse.old

# instalar nuevo componente
[ -d ~/monopse.git ] && mv ~/monopse.git ~/monopse

# asignar permisos y ligas
chmod 0750 ~/monopse/monopse.sh
ln -sf ~/monopse/monopse.sh ~/bin/monopse
echo "Recuerda, la configuracion ahora se encuentra en $HOME/.monopserc"
ln -sf ~/monopse/monopserc ~/.monopserc

# copiar manual
echo "Siempre podras consultar el manual con monopse -h o man monopse"
cp ~/monopse/man1/monopse.1 ~/manuals/man1/

chmod 0640 ~/monopse/*.*
chmod 0750 ~/monopse/monopse.sh

# establecer nuevo path
PATH=$HOME/bin:$PATH

#
