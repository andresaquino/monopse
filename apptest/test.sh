#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# apptest.sh 
# --------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
# 
# Andres Aquino <cesar.aquino@nextel.com.mx>
# $Id: 00e752e105349ecc0583f5b1ede4e44b997c99ed $

echo "WORM TEST"
cuteworm=0

while(true)
do
   sleep 5
   echo "little little worm ... "
   [ $cuteworm -eq 5  ] && echo "RUNNING OK"
   [ $cuteworm -gt 800  ] && break
   cuteworm=$(($cuteworm+1))
done

#
