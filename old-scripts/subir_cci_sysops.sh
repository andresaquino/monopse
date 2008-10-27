cd /opt/weblogicsp4/bea/user_projects/domains/cciprod

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_CCI
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 900 

cat nohup* | grep RUNNING > cciup.log
falla=`cat cciup.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start CCI ok" $lista < cciup.log
 echo CCI esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > ccifalla.log.$i
 mailx -s "Start CCI Fail" $lista < ccifalla.log.$i
 echo CCI parece que tener un problema para subir
 exit 1
fi 
exit 0
