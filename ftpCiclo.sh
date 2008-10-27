#!/bin/bash 
# vim: set ts=3 sw=3 sts=3 et si ai: 
# 
# ftpCiclo.sh -- short description 
# --------------------------------------------------------------------
# (c) 2008 NEXTEL DE MEXICO
# 
# $Id: ffac6eaee6aa4ff3db2f95a52597347a5b66950b $

_FILE=conexiones.log

while [ true ];do
   _DATE=`date "+%d%m.%H:%M"`
   _PORT="10.103.2.61.1537"
   touch /monitor_fuego/$_FILE
   echo "******************************  $_DATE  **********************************" >> $_FILE
   echo "===================== visionDB $_PORT  ============================================ "
   >> $_FILE
   EST=`netstat -na | grep $_PORT | grep ESTABLISHED | wc -l`
   LIS=`netstat -na | grep $_PORT | grep LISTEN | wc -l`
   WT=`netstat -na | grep $_PORT | grep TIME_WAIT | wc -l`
   echo "ESTABLISHED $EST" >> $_FILE
   echo "LISTEN $LIS" >> $_FILE
   echo "TIME_WAIT $WT" >> $_FILE


# Obtiene el PID del engine de Order Entry
PID_OE=`ps -feax | grep pvision | grep ftboot | grep -v pvisionConsulta | grep -v pvisionAplica | grep -v pvisionActiva | awk '{print $2}'`

# Obtiene el PID del engine de Consultas
PID_Cons=`ps -feax | grep pvisionConsulta | grep ftboot | awk '{print $2}'`

#Obtiene el PID del engine de Aplicaciones
PID_Aplica=`ps -feax | grep pvisionAplica | grep ftboot | awk '{print $2}'`

#Obtiene el PID del engine de Activa
PID_Activa=`ps -feax | grep pvisionActiva | grep ftboot | awk '{print $2}'`

i=0
while [ "$i" -ne 3 ]
do
   kill -3 $PID_OE $PID_Cons $PID_Aplica $PID_Activa
   echo "1 FTD a cada engine a las $_DATE " >> $_FILE
   sleep 15
   let i="$i + 1"
done

sleep 1800
done

#
