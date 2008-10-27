cd /opt/weblogicsp4/bea/user_projects/domains/puc_P
./stopWebLogic.sh
sleep 60

ps -efx | grep puc | grep java | awk {'print $2'} | xargs kill -9
sleep 30

procesos=`ps -efx | grep puc | grep java | wc -l`

if [ procesos -eq 0 ]; then
 echo ...PUC Abajo
else
 echo ...PUC arriba!!, Revisar los siguientes procesos: $procesos
exit 1
fi
exit 0
