cd /opt/weblogicsp4/bea/user_projects/domains/wl_ATM 
./stopWebLogic.sh
sleep 60

ps -efx | grep wl_ATM | grep java | awk {'print $2'} | xargs kill -9
sleep 30

procesos=`ps -efx | grep wl_ATM | grep java | wc -l`

if [ procesos -eq 0 ]; then
 echo ...WL ATM Abajo
else
 echo ...WL ATM arriba!!, Revisar los siguientes procesos: $procesos
 exit 1
fi
exit 0

