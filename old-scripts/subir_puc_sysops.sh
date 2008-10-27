cd /opt/weblogicsp4/bea/user_projects/domains/puc_P

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_PUC
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 500 

cat nohup* | grep RUNNING > pucup.log
falla=`cat pucup.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start PUC ok" $lista < pucup.log
 echo PUC esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > pucfalla.log.$i
 mailx -s "Start PUC Fail" $lista < pucfalla.log.$i
 echo PUC parece que tener un problema para subir
 exit 1
fi 
exit 0
