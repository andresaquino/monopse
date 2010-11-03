#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai: 

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
if [ -d ~/monopse ]
then
   find ~/monopse -name '*-monopse.con' -exec mv {} ~/monopse.git/setup/ \;
fi

# mover actual como backup
echo "Se respaldo la anterior configuracion en $HOME/monopse.old"
[ -d ~/monopse.old ] && rm -fr ~/monopse.old
[ -d ~/monopse ] && mv ~/monopse ~/monopse.old

# instalar nuevo componente
if [ -d ~/monopse.git ]
then
   mv ~/monopse.git ~/monopse
   
   cd ~/monopse
   ln -sf ~/monopse/monopse.sh monopse
   echo "Recuerda, la configuracion ahora se encuentra en $HOME/.monopserc"
   ln -sf ~/monopse/monopserc ~/.monopserc
   echo "Siempre podras consultar el manual con monopse -h o man monopse"
   cp ~/monopse/man1/monopse.1 ~/manuals/man1/

   chmod -R 0640 *.*
   chmod 0750 monopse.sh

   # establecer nuevo path
   PATH=$HOME/monopse:$PATH
fi

#
