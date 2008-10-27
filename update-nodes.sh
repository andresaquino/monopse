#!/bin/bash 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# update-nodes.sh -- short description 
# --------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
# 
# Andres Aquino <andres.aquino@nextel.com.mx>
# $Id: 436b2f745c61c2cf9cc6231cf1259d49ddd3da93 $


apps=${1}
path=${2}

# produccion
scp -r ${apps} web8sp6@192.168.120.120:${path}
#scp -r ${apps} weblogi6@192.168.120.120:${path}
scp -r ${apps} web8sp6@10.103.2.52:${path}
scp -r ${apps} weblogi8@10.103.2.52:${path}
scp -r ${apps} web8sp6@10.103.12.58:${path}
scp -r ${apps} web8sp6@10.103.138.150:${path}
scp -r ${apps} web8sp6@10.103.138.151:${path}
scp -r ${apps} web8sp6@10.103.138.152:${path}
scp -r ${apps} web8sp4@10.103.2.86:${path}

--
scp -r ${apps} aqua9@10.103.12.58:${path}
scp -r ${apps} fuego@10.103.12.63:${path}
scp -r ${apps} fuego@10.103.2.81:${path}
scp -r ${apps} resin1@10.103.2.81:${path}
#scp -r ${apps} fuegoree@10.103.2.81:${path}
scp -r ${apps} resinpto@10.103.2.61:${path}
scp -r ${apps} iplanet1@10.103.2.54:${path}

# desarrollo
scp -r ${apps} web8sp6@10.103.12.55:${path}
scp -r ${apps} web8sp6@10.103.12.51:${path}
scp -r ${apps} web8sp4@10.103.12.51:${path}
#scp -r ${apps} web8sp6@10.103.12.57:${path}
scp -r ${apps} weblogi9@10.103.12.91:${path}

#
