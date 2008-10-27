cd /opt/weblogicsp4/bea/user_projects/domains/SCV 

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_SCV
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 180 

cat nohup* | grep RUNNING > scv_falla.log
falla=`cat scv_falla.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start SCV ok" $lista < scv_falla.log
 echo SCV esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > scv_falla.log.$i
 mailx -s "SCV Fail" $lista < scv_falla.log.$i
 echo SCV parece que tener un problema para subir
 exit 1
fi 
exit 0
