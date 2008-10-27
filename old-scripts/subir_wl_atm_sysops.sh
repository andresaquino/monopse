cd /opt/weblogicsp4/bea/user_projects/domains/wl_ATM 

/usr/contrib/bin/gzip nohup*
mv nohup* LOGS_WL_ATM
 
i=`date "+%d%m.%H:%M"`
nohup ./startWebLogic.sh >> nohup.out.$i 2>&1 &
sleep 200 

cat nohup* | grep RUNNING > str_wl_atm.log
falla=`cat str_wl_atm.log | wc -l`
lista="roberto.gomez@nextel.com.mx carlos.patlan@nextel.com.mx"

if [ $falla -ne 0  ]; then
 mailx -s "Start WL_ATM ok" $lista < str_wl_atm.log 
 echo WL_ATM esta arriba
 echo `cat nohup* | grep RUNNING`
else
 tail -200 nohup* > str_wl_atm.log.$i
 mailx -s "Start WL_ATM Fail" $lista < tr_wl_atm.log.$i
 echo  WL_ATM parece que tener un problema para subir
 exit 1
fi 
exit 0 
