#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 et si ai: 

# install.sh -- put here a short description 
# ----------------------------------------------------------------------------
# (c) 2009 Nextel de México S.A. de C.V.
# Andrés Aquino Morales <andres.aquino@gmail.com>
# All rights reserved.
# 

mkdir -p ~/bin
[ -d ~/monopse.git ] && mv ~/monopse.git ~/monopse
chmod 0750 ~/monopse/monopse.sh
ln -sf ~/monopse/monopse.sh ~/bin/monopse

#
