cd /opt/web8sp6/bea/user_projects/domains/nextel_oe
./stopWebLogic.sh
sleep 60

ps -efx | grep /opt/web8sp6/ | grep java | awk {'print $2'} | xargs kill -9
sleep 30

nextel_oe=`ps -efx | grep /opt/web8sp6/ | grep java | wc -l`

if [ nextel_oe -eq 0 ]; then
 echo ...nextel_oe Abajo
else
 echo ...nextel_oe arriba!!, Revisar los siguientes procesos: $nextel_oe
 exit 1
fi
exit 0

