#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# install.sh -- instalar monopse en el directorio
# --------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
# 
# César Andrés Aquino <cesar.aquino@nextel.com.mx>

mkdir -p ~/bin
# si existe, moverlo
[ -d ~/monopse ] && mv ~/monopse ~/monopse.old
[ -d ~/monopse.git ] && mv ~/monopse.git ~/monopse
[ -d ~/monopse.old ] && cp -rp ~/monopse.old/*-monopse.conf ~/monopse/setup/ 
chmod 0750 ~/monopse/monopse.sh
ln -sf ~/monopse/monopse.sh ~/bin/monopse
PATH=$HOME/bin:$PATH

#
