#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 si ai: 
#  
#  cci_sysops.sh -- CCI 
#  ___________________________________________________________________
#  (c) 2008 NEXTEL DE MEXICO
#
#  $Id: fc6c25b90afefbd60c928fd96b1d481a34a71866 $
#

#
# filterProcess
# filtrar el log en busca de la cadena
filterProcess() 
{
	grep -q -i "${1}" "${fName}.log"
	return $?
}

#
# sendStatusToAdmins
# si allSuccess, avisar con ultimas lineas de log; caso contrario enviar 
# lineas de error y terminar con -1 
sendStatusToAdmins() 
{
	typeOperation=${1}
	allSuccess=${2}
	if [ "${allSuccess}" -eq "0" ]
	then
		strStatus="Success"
		fileStatus="${fName}.log"
	else
		strStatus="Failed"
		fileStatus="${fName}.err"
	fi

	tail -n200 ${fileStatus} > ${fName}.stat
	echo "${nameApp%.*} ${typeOperation} ${strStatus}, see also ${fName}.stat for information"
	mailx -s "${nameApp%.*} ${typeOperation} ${strStatus}" "${mailAdmins}" < ${fName}.stat
	exit ${lastStatus}
}

#
# getProcessID
# obtenemos los PID's de la aplicacion, para poder checar status del mismo
getProcessID()
{
	ps -fea | grep -i "${qryWords}" | awk '/java/{print $2}' > "applogs/${nameApp%.*}.pid"
}

#
#
#
processIsRunning()
{

	pss=`awk '{print "ps -fea | grep "$0" | grep java "}' "applogs/${nameApp%.*}.pid" | sh | wc -l`
	if [ "$pss" -ne "0" ]
	then
		return $pss
	else
		return 0
	fi

}

#
#
#
checkConfig()
{
	lastStatus=-1
	# checar que los datos del archivo de configuracion sean correctos
	[ "${1}" = "full" ] && echo "pathApp = ${pathApp}"
	[ -d ${pathApp} ] && lastStatus=0
	
	[ "${1}" = "full" ] && echo "startPath = ${pathApp}/${startApp}"
	[ -r "${pathApp}/${startApp}" ] && lastStatus=0
	
	[ "${1}" = "full" ] && echo "stopPath = ${pathApp}/${stopApp}"
	[ -r "${pathApp}/${stopApp}" ] && lastStatus=0
	
	if [ "${lastStatus}" -ne "0" ]
	then
		[ "${1}" = "full" ] && echo "Existen errores con la configuracion"
		return 1
	else
		[ "${1}" = "full" ] && echo "Ok"
	fi
	
}


#
#	MAIN
. "$HOME/apps/${0%.*}.conf"
nameApp="${0}"
fDate=`date "+%Y%m%d"`
fName="applogs/${nameApp%.*}_${fDate}"

checkConfig "quiet"
lastStatus=$?

case "${1:-''}" in
	'--start')
		[ "${lastStatus}" -ne "0" ] && exit 1
		cd ${pathApp}
		mkdir -p applogs
		
		if [ "${wlVersion}" = "WM" ]
		then
			# cuando se inician con el startManaged
			# ej. nohup sh bin/startManagedWebLogic.sh pucQA http://10.103.11.4:18001 
			nohup sh ${startApp} ${params} 2> ${fName}.err > ${fName}.log &
		else
			# cuando son dominios independientes
			# ej. sh bin/startWebLogic.sh
			nohup sh bin/${startApp} 2> ${fName}.err > ${fName}.log &
		fi
		
		#
		# a trabajar ... !
		lastStatus=-1
		for inWait in 10 9 8 7 6 5 4 3 2 1
		do
			filterProcess "running mode"
			lastStatus=$?
			[ "${lastStatus}" -eq "0" ] && break;
			sleep ${toSleep}
		done
		
		# buscar los PID's
		getProcessID
		sendStatusToAdmins "Startup" $lastStatus
		;;
		
	'--stop')
		[ "${lastStatus}" -ne "0" ] && exit 1
		cd ${pathApp}
		mkdir -p applogs
	
		#
		# consentimos al nene, pa'que se calle y deje de chillar ...
		# con el comercial ese de "cuente hasta 10 " jo jo jo ! 
		lastStatus=-1
		status="Shutdown"
		if [ "${wlVersion}" = "WM" ]
		then
			for inWait in 10 9 8 7 6 5 4 3 2 1
			do
				# filterProcess "was shutdown"
				# checar si existen los PID's, por si el archivo no regresa el shutdown
				processIsRunning
				lastStatus=$?
				[ "${lastStatus}" -eq "0" ] && break;
				sleep ${toSleep}
			done
		fi
		
		#
		# si no se cancelo el proceso por la buena, entonces pasamos a la mala
		# le damos matacran al alacran ... 
		if [ "${lastStatus}" -ne "0" ]
		then
			lastStatus=-1
			for inWait in 5 4 3 2 1
			do
				#
				# obtenemos los PID, armamos los kills y shelleamos
				awk '{print "kill -9 "$0}' "applogs/${nameApp%.*}.pid" | sh
				sleep ${toSleep}
				
				# checamos al muerto
				processIsRunning
				lastStatus=$?
				[ "${lastStatus}" -eq "0" ] && break;
			done
			status="Killed"
		fi
	
		#
		# y le avisamos a los slayers, "su proceso ya jue amartajado o no" :-P
		sendStatusToAdmins "${status}" ${lastStatus}
		;;
	
	'--status')
		[ "${lastStatus}" -ne "0" ] && exit 1
		cd ${pathApp}
		mkdir -p applogs
	
		# checar que la aplicacion este arriba o enviar error 
		processIsRunning
		if [ "$?" -ne "0" ]
		then
			echo "The application ${qryWord} is running"
		else
			echo "The application ${qryWord} is not running"
		fi
		exit 0
		;;
	
	'--config')
		lastStatus=-1
		checkConfig "full"
		exit $?
		;;

	*)
		echo "Usage: ${nameApp%.*} [--start | --stop | --status | --config ]"
		
esac

#
