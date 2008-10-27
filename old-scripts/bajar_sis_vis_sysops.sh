cd /opt/web8sp6/bea/user_projects/domains/sis_vis 

ps -efx | grep mau | grep java | awk {'print $2'} | xargs kill -9
sleep 30

sis_vis=`ps -efx | grep mau | grep java | wc -l`

if [ sis_vis -eq 0 ]; then
 echo ...sis_vis Abajo
else
 echo ...sis_vis arriba!!, Revisar los siguientes procesos: $sis_vis
 exit 1
fi
exit 0

