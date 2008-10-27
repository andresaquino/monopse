cd /opt/web8sp60/bea/user_projects/domains/nextel_oe_service

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_SERV_CAP_VIS
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 900 

cat nohup* | grep RUNNING > serv_cap_vis_falla.log
falla=`cat serv_cap_vis_falla.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start SERV_CAP_VIS ok" $lista < serv_cap_vis_falla.log
 echo SERV_CAP_VIS esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > serv_cap_vis_falla.log.$i
 mailx -s "SERV_CAP_VIS Fail" $lista < serv_cap_vis_falla.log.$i
 echo CSERV_CAP_VIS parece que tener un problema para subir
 exit 1
fi 
exit 0
