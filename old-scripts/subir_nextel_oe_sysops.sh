cd /opt/web8sp6/bea/user_projects/domains/nextel_oe 

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_CAP_VIS
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 900 

cat nohup* | grep RUNNING > cap_vis_falla.log
falla=`cat cap_vis_falla.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start CAP_VIS ok" $lista < cap_vis_falla.log
 echo CAP_VIS esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > cap_vis_falla.log.$i
 mailx -s "CAP_VIS Fail" $lista < cap_vis_falla.log.$i
 echo CAP_VIS parece que tener un problema para subir
 exit 1
fi 
exit 0
