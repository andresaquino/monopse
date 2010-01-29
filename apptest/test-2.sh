#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# apptest.sh 
# =-=
# (c) 2008 NEXTEL DE MEXICO
# Andres Aquino <cesar.aquino@nextel.com.mx>
#

echo "WORM TEST"
cuteworm=0

while(true)
do
   sleep 1
   echo "wake up little little worm 2 - (`date`) "
   [ $cuteworm -eq 5  ] && echo "ujuu little little worm you're RUNNING OK"
   [ $cuteworm -gt 800  ] && break
   cuteworm=$(($cuteworm+1))
done

#
