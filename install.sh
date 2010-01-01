#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# install.sh -- instalar starter en el directorio
# --------------------------------------------------------------------
# (c) 2009 Strategies Labs!
# 

mkdir -p ~/bin
# si existe, moverlo
[ -d ~/starter ] && mv ~/starter ~/starter.old
[ -d ~/starter.git ] && mv ~/starter.git ~/starter
[ -d ~/starter.old ] && cp -rp ~/starter.old/*-starter.conf ~/starter/setup/ 
chmod 0750 ~/starter/starter.sh
ln -sf ~/starter/starter.sh ~/bin/starter
PATH=$HOME/bin:$PATH

#
