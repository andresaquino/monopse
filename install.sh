#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# install.sh -- instalar monopse en el directorio
# --------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
# 
# César Andrés Aquino <cesar.aquino@nextel.com.mx>

mkdir -p ~/bin
chmod 0750 ~/monopse/monopse.sh
ln -sf ~/monopse/monopse.sh ~/bin/monopse
PATH=$HOME/bin:$PATH
echo "Set this:\n${PATH}"

#
