cd /opt/weblogicsp4/bea/user_projects/domains/SCV 
./stopWebLogic.sh
sleep 60

ps -efx | grep scv | grep java | awk {'print $2'} | xargs kill -9
sleep 30

SCV=`ps -efx | grep scv | grep java | wc -l`

if [ SCV -eq 0 ]; then
 echo ...scv Abajo
else
 echo ...scv arriba!!, Revisar los siguientes procesos: $SCV
 exit 1
fi
exit 0

