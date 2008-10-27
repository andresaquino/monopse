cd /opt/web8sp6/bea/user_projects/domains/sis_vis 

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_SIS_VIS
 
i=`date "+%d%m.%H:%M"`
nohup ./startManagedWebLogicMau.sh >> nohup-mau.out.$i 2>&1 &
sleep 200 

cat nohup* | grep RUNNING > sis_vis_falla.log
falla=`cat sis_vis_falla.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start SIS_VIS ok" $lista < sis_vis_falla.log
 echo SIS_VIS esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > sis_vis_falla.log.$i
 mailx -s "SIS_VIS Fail" $lista < sis_vis_falla.log.$i
 echo SIS_VIS parece que tener un problema para subir
 exit 1
fi 
exit 0
