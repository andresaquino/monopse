cd /opt/weblogicsp4/bea/user_projects/domains/cciprod
./stopWebLogic.sh
sleep 60

ps -efx | grep cci | grep java | awk {'print $2'} | xargs kill -9
sleep 30

cci_procesos=`ps -efx | grep cci | grep java | wc -l`

if [ cci_procesos -eq 0 ]; then
 echo ...CCI Abajo
else
 echo ...CCI arriba!!, Revisar los siguientes procesos: $cci_procesos
 exit 1
fi
exit 0

