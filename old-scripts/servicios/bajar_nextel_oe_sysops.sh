cd /opt/web8sp60/bea/user_projects/domains/nextel_oe_service 
./stopWebLogic.sh
sleep 60

ps -efx | grep /opt/web8sp60/ | grep java | awk {'print $2'} | xargs kill -9
sleep 30

SERV_CAP_VIS=`ps -efx | grep /opt/web8sp60/ | grep java | wc -l`

if [ SERV_CAP_VIS -eq 0 ]; then
 echo ...nextel_oe Abajo
else
 echo ...nextel_oe arriba!!, Revisar los siguientes procesos: $SERV_CAP_VIS
 exit 1
fi
exit 0

