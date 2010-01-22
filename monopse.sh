#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai: 

# monopse.sh - An small shell for those applications that nobody wants to restart ;)
# =-=
# (c) 2008, 2009 Nextel de Mexico, S.A. de C.V.
# Andrés Aquino Morales <andres.aquino@gmail.com>
# 

#
. ${HOME}/monopse/libutils.sh

# set environment
APNAME="monopse"
APPATH=${HOME}/${APNAME}
APLOGD=${HOME}/logs
APLEVL="DEBUG"
TOSLEEP=0
MAILTOADMIN=
MAILTODEVELOPER=
MAILTORADIO=
MAXSAMPLES=3
MAXSLEEP=2

#
# log_backup
# respaldar logs para que no se generen problemas de espacio.
log_backup () {
	# local apps
	APTAR=`which tar`
	APZIP=`which gzip`

	#
	# filename: monopse/monopse-cci-20080516-2230.tar.gz
	DAYOF=`date '+%Y%m%d-%H%M'`
	cd ${APTEMP}
	if [ -e ${APLOGT}.date ]
	then
		DAYOF="`cat ${APLOGT}.date`"
		rm -f ${APLOGT}.date 
	fi
	
	mkdir -p ${DAYOF}
	touch ${APLOGP}.log
	touch ${APLOGT}.err
	touch ${APLOGT}.pid
	mv ${APLOGP}.log ${APLOGT}.err ${APLOGT}.pid ${DAYOF}/
	touch ${APLOGP}.log
	LOGSIZE=`du -sk "${DAYOF}" | cut -f1`
	RESULT=$((${LOGSIZE}/1024))
	
	# reportar action
	log_action "DEBUG" "The sizeof ${APLOGP}.log is ${LOGSIZE}M, proceeding to compress"
	
	# Si esta habilitado el fast-stop(--forced), no se comprime la informacion
	rm -f ${APLOGT}.lock
	${FASTSTOP} && log_action "WARN" "Ups,(doesn't compress) hurry up is to late for sysadmin !"
	${FASTSTOP} && return 0
	
	# si el tamaño del archivo .log sobrepasa los MAXLOGSIZE en megas 
	# entonces hacer un recorte para no saturar el filesystem
	if [ ${RESULT} -gt ${MAXLOGSIZE} ]
	then
		log_action "WARN" "The sizeof ${APLOGP}.log is ${LOGSIZE}M, i need reduce it to ${MAXLOGSIZE}M"
		SIZE=$((${MAXLOGSIZE}*1024*1024))
		tail -c${SIZE} ${DAYOF}/${APPRCS}.log > ${DAYOF}/${APPRCS}
		rm -f ${DAYOF}/${APPRCS}.log
		mv ${DAYOF}/${APPRCS} ${DAYOF}/${APPRCS}.log
	fi
	
	#
	# por que HP/UX tiene que ser taaan estupido ? ? 
	# backup de log | err | pid para análisis
	# tar archivos | gzip -c > file-log
	$APTAR -cvf ${APLOGP}_${DAYOF}.tar ${DAYOF} > /dev/null 2>&1
	$APZIP -c ${APLOGP}_${DAYOF}.tar > ${APLOGP}_${DAYOF}.tar.gz
	LOGSIZE=`du -sk ${APLOGP}_${DAYOF}.tar.gz | cut -f1`
	log_action "INFO" "Creating ${APLOGP}_${DAYOF}.tar.gz file with ${LOGSIZE}M of size"
	
	rm -f ${APLOGP}_${DAYOF}.tar
	rm -fr ${DAYOF}
}


#
# check_configuration
# corroborar que los parametros/archivos sean correctos y existan en el filesystem
check_configuration () {
	PROCESS="${1}"
	
	# existe el archivo de configuracion ?
	FILESETUP="${APPATH}/setup/${PROCESS}-${APNAME}.conf"
	log_action "DEBUG" "Testing ${FILESETUP}"
	
	CHECKTEST=false
	if [ -r "${FILESETUP}" ]
	then
		CHECKTEST=true
		. "${FILESETUP}"
		
		# Validar parametros
		[ -d ${PATHAPP} ] || CHECKTEST=false
		log_action "DEBUG" "Testing PATHAPP=${PATHAPP} ($CHECKTEST)"
		
		[ -f ${PATHAPP}/${STARTAPP} ] || CHECKTEST=false
		log_action "DEBUG" "Testing STARTAPP=${PATHAPP}/${STARTAPP} ($CHECKTEST)"
		
		[ ! -z "${FILTERAPP}" ] || CHECKTEST=false
		log_action "DEBUG" "Testing FILTER=/${FILTERAPP}//${FILTERLANG}/ ($CHECKTEST)"
		
		[ ! -z "${UPSTRING}" ] || CHECKTEST=false
		log_action "DEBUG" "Testing UPSTRING=${UPSTRING} ($CHECKTEST)"
	fi

	if ${CHECKTEST}
	then
		log_action "DEBUG" "All parameters seem to be correct "
		return 0
	else
		log_action "DEBUG" "Uhmmm, maybe some parameter is incorrect "
		return 1
	fi
}


# *
# verificar que el servidor weblogic (en el caso de los appsrv's se encuentre arriba y operando,
# de otra manera, ejecutar una rutina _plugin_ para iniciar el servicio )
check_weblogicserver() {
	# si se dio de alta la variable FILTERWL(weblogic.Server), entonces se tiene que buscar si existe el proceso de servidor WEBLOGIC
	if [ ${FILTERWL} != "_NULL_" ]
	then
		log_action "INFO" "Check if exists an application server manager of WebLogic"
		# existe algun proceso de weblogic.Server ?
		if [ "${APSYSO}" = "HP-UX" ]
		then
			WLPROCESS=`ps -fex | grep "${FILTERWL}" | wc -l | cut -f1 -d\ `
		else
			WLPROCESS=`ps fea | grep "${FILTERWL}" | wc -l | cut -f1 -d\ `
		fi
		
		# si no es así, levantar el servidor y esperar 3 minuto
		WLSLEEP=60*3
		if [ ${WLPROCESS} -eq "0" ]
		then
			log_action "WARN" "Dont exists an application server manager of WebLogic, starting an instance of"
			nohup sh ${WLSAPP} 2> ${APLOGP}-WLS.err > ${APLOGP}-WLS.log &
			sleep ${WLSLEEP}
		fi
	fi

}


# *
# realizar un kernel full thread dump sobre el proceso indicado.
# sobre procesos non-java va a valer queso, por que la señal 3 es para hacer un volcado de memoria.
# monopse --application=resin --threaddump=5 --mailto=cesar.aquino@nextel.com.mx
# por defecto, el ftd se almacena en el filesystem log de la aplicación; si se detecta que se esta
# incrementando el uso del filesystem, conserva los mas recientes 
make_fullthreaddump() {
	# para cuando son procesos JAVA StandAlone (WL, Tomcat, etc...) 
	log_action "DBUG" "Change to ${PATHAPP}"
	[ -r ${APLOGT}.pid ] && PID=`tail -n1 ${APLOGT}.pid`

	# para cuando son procesos ONDemand (iPlanet, ...)
	[ -r ${APLOGT}.plist -a ${FILTERAPP} ] && PID=`head -n1 ${APLOGT}.pid`
	
	# hacer un mark para saber desde donde vamos a sacar datos del log
	ftdFILE="${APLOGP}_`date '+%Y%m%d-%H%M%S'`.ftd"
	touch "${ftdFILE}"
	log_action "DBUG" "Taking ${APLOGP}.log to extract the FTP on ${ftdFILE}"
	tail -f "${APLOGP}.log" > ${ftdFILE} &

	# enviar el FTD al PID, N muestras cada T segs
	times=0
	timeStart=`date`
	while [ $times -ne $MAXSAMPLES ]
	do
		kill -3 $PID
		echo "Sending a FTD to PID $PID at `date '+%H:%M:%S'`, saving in $ftdFILE"
		log_action "INFO" "Sending a FTD to PID $PID at `date '+%H:%M:%S'`, saving in $ftdFILE"
		sleep $MAXSLEEP
		times=$(($times+1))
	done
	 
	# quitar el proceso de copia del log
	PROCESSES=`ps ${PSOPTS} | grep "tail -f ${APLOGP}.log" | grep -v grep | awk '/tail/{print $2}'`
	kill -15 ${PROCESSES}
	
	#
	# generar encabezado y limpiar basura
	tFILE=`wc -l ${ftdFILE} | awk '{print $1}'`
	gFILE=`nl -ba ${ftdFILE} | grep "Full thread dump" | grep "Java HotSpot" | head -n1 | awk '{print $1}'`
	total=$(($tFILE-$gFILE+1))
	log_action "DBUG" "Total: $total, where tFile=$tFILE and gFile=$gFILE"
	tail -n${total} ${ftdFILE} > ${ftdFILE}.tmp
	echo "-------------------------------------------------------------------------------" > ${ftdFILE}
	echo "-------------------------------------------------------------------------------" >> ${ftdFILE}
	echo "JAVA FTD" >> ${ftdFILE}
	echo "-------------------------------------------------------------------------------" >> ${ftdFILE}
	echo "Host: `hostname`" >> ${ftdFILE}
	echo "ID's: `id`" >> ${ftdFILE}
	echo "Date: ${timeStart}" >> ${ftdFILE}
	echo "Appl: ${APPRCS}" >> ${ftdFILE}
	echo "Smpl: ${MAXSAMPLES}" >> ${ftdFILE}
	echo "-------------------------------------------------------------------------------" >> ${ftdFILE}
	cat ${ftdFILE}.tmp >> ${ftdFILE}
 
	# enviar por correo 
	if [ "${MAILACCOUNTS}" != "_NULL_" ]
	then
		$APMAIL -s "${APPRCS} FULL THREAD DUMP ${timeStart} (${ftdFILE})" "${MAILACCOUNTS}" < ${ftdFILE} > /dev/null 2>&1 &
		log_action "INFO" "Sending a full thread dump(${ftdFILE}) by mail to ${MAILACCOUNTS}"
	fi
	#rm -f ${ftdFILE}
	rm -f ${ftdFILE}.tmp
	return 0

}


# *
# report_status
# generar reporte via mail para los administradores
reports_status () {
	local TYPEOPERATION STATUS STRSTATUS FILESTATUS 
	TYPEOPERATION=${1}
	STATUS=${2}

	if [ "${STATUS}" -eq "0" ]
	then
		STRSTATUS="SUCCESS"
		FILESTATUS="${APLOGP}.log"
		log_action "INFO" "The application ${TYPEOPERATION} ${STRSTATUS}"
	else
		STRSTATUS="FAILED"
		FILESTATUS="${APLOGT}.err"
		log_action "ERR" "The application ${TYPEOPERATION} ${STRSTATUS}"
	fi
	
	#
	# solo enviar si la operacion fue correcta o no
	echo "${APPRCS} ${TYPEOPERATION} ${STRSTATUS}, see also ${APLOGP}.log for information"
	if [ "${MAILACCOUNTS}" != "_NULL_" ]
	then
		# y mandarlo a bg, por que si no el so se apendeja, y por este; este arremedo de programa :-P
		$APMAIL -s "${APPRCS} ${TYPEOPERATION} ${STRSTATUS}" -r "${MAILACCOUNTS}" > /dev/null 2>&1 &
		log_action "INFO" "Report ${APPRCS} ${TYPEOPERATION} ${STRSTATUS} to ${MAILACCOUNTS}"
	fi

}


#
# show application's version
show_version () {
	VERSIONAPP="3"
	UPVERSION=`echo ${VERSIONAPP} | sed -e "s/..$//g"`
	RLVERSION=`awk '/2010/{t=substr($1,6,7);gsub("-"," Rev.",t);print t}' ${APPATH}/CHANGELOG | head -n1`
	echo "${APNAME} v${UPVERSION}.${RLVERSION}"
	echo "(c) 2008, 2009 Nextel de Mexico, S.A. de C.V.\n"
	
	if [ ${SVERSION} ]
	then
		echo "Written by"
		echo "Andres Aquino <andres.aquino@gmail.com>"
	fi

}


#
# get application's status
show_status () {
	REPORT=${APTEMP}/report.inf
	
	processes_running
	PROCESSES=$?
	if [ "${PROCESSES}" -ne "0" ]
	then
		WITHLOCK="out of control of ${APNAME}!"
		[ -f ${APLOGT}.lock ] && WITHLOCK="controlled by ${APNAME}."
		STR="${APPRCS} is running with ${PROCESSES} processes ${WITHLOCK}" 
		report_status "*" "${STR}"
		echo ${STR} >> ${REPORT}
		cat ${APLOGT}.pid >> ${REPORT}
		return 0
	else
		STR="${APPRCS} is not running" 
		[ -f ${APLOGT}.lock ] && rm -f ${APLOGT}.lock
		report_status "i" "${STR}"
		echo ${STR} >> ${REPORT}
		return 1
	fi

}


## MAIN ##
##
# corroborar que no se ejecute como usuario r00t
if [ "`id -u`" -eq "0" ]
then
	 if [ "${MAILACCOUNTS}" = "_NULL_" ]
	 then
			echo "Hey, i can't run as root user "
	 else
			$APMAIL -s "Somebody tried to run me as r00t user" "${MAILACCOUNTS}" < "$@" > /dev/null 2>&1 &
			log_action "WARN" "Somebod tried to run me as r00t, sending warn to ${MAILACCOUNTS}"
	 fi
	 
fi

#
# Opciones por defecto
APPRCS=
START=false
STOP=false
STATUS=false
NOTFORCE=true
FASTSTOP=false
VIEWLOG=true
MAILACCOUNTS="_NULL_"
FILTERWL="_NULL_"
CHECKCONFIG=false
SUPERTEST=false
STATUS=false
DEBUG=false
ERROR=true
MAXLOGSIZE=500
THREADDUMP=false
VIEWREPORT=false
VIEWHISTORY=false
MAINTENEANCE=false
LOGLEVEL="DBUG"
SVERSION=false
APPTYPE="STAYRESIDENT"
UNIQUELOG=false
PREEXECUTION="_NULL_"
OPTIONS="Options used when ${APNAME} was called:"


APMAIL=`which mail`
[ "${APSYSO}" = "HP-UX" ] && APMAIL=`which mailx`


#
# applications setup
if [ -r $HOME/.${APNAME}rc ]
then
	. $HOME/.${APNAME}rc
fi
set_environment

#
# parametros 
while [ $# -gt 0 ]
do
	case "${1}" in
		-a=*|--application=*)
			APPRCS=`echo "$1" | sed 's/^--[a-z-]*=//'`
			APPRCS=`echo "${APPRCS}" | sed 's/^-a=//'`
			set_proc "${APPRCS}"
			ERROR=false
		;;
		--start|start)
			START=true
			ERROR=false
			if ${STOP} || ${STATUS} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--stop|stop)
			STOP=true
			ERROR=false
			if ${START} || ${STATUS} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--restart|restart)
			RESTART=true
			ERROR=false
			if ${START} || ${STOP} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--status|-s)
			STATUS=true
			ERROR=false
			if ${START} || ${STOP} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--log|-l)
			VIEWHISTORY=true
			ERROR=false
			if ${START} || ${STOP} || ${CHECKCONFIG} || ${STATUS}
			then
				ERROR=true
			fi
		;;
		--mainteneance|-m)
			MAINTENEANCE=true
			ERROR=false
			if ${START} || ${STOP} || ${CHECKCONFIG} || ${STATUS}
			then
				ERROR=true
			fi
		;;
		--report|-r)
			VIEWREPORT=true
			ERROR=false
			if ${START} || ${STOP} || ${CHECKCONFIG} || ${STATUS}
			then
				ERROR=true
			fi
		;;
		--forced|-f)
			NOTFORCE=false
			FASTSTOP=true
			ERROR=false
		;;
		--unique-log|-u)
			UNIQUELOG=true
			ERROR=false
		;;
		-t=*|--threaddump=*)
			THREADDUMP=true
			ERROR=false
			MAXVALUES=`echo "$1" | sed 's/^--[a-z-]*=//'`
			MAXVALUES=`echo "${MAXVALUES}" | sed 's/^-t=//'`
			if [ $MAXVALUES != "--threaddump" ]
			then
				MAXSAMPLES=`echo $MAXVALUES | sed 's/\,.*//'`
				MAXSLEEP=`echo "$1" | sed 's/.*\,//'`
			fi
			if ${START} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--threaddump|-t)
			THREADDUMP=true
			ERROR=false
			MAXSAMPLES=3
			MAXSLEEP=10
			if ${START} || ${CHECKCONFIG}
			then
				ERROR=true
			fi
		;;
		--mailto=*)
			MAILACCOUNTS=`echo "$1" | sed 's/^--[a-z-]*=//'`
			ERROR=false
		;;
		--mailreport)
			MAILACCOUNTS="${MAILTOADMIN} ${MAILTODEVELOPER} ${MAILTORADIO}"
			VIEWLOG=false
			ERROR=false
		;;
		--quiet|quiet|-q)
			VIEWLOG=false
			ERROR=false
		;;
		--debug|debug|-d)
			DEBUG=true
			ERROR=false
			if ${START} || ${STOP} || ${STATUS}
			then
				ERROR=true
			fi
		;;
		--check-config|-c)
			CHECKCONFIG=true
			ERROR=false
			if ${START} || ${STOP} || ${STATUS} 
			then
				ERROR=true
			fi
		;;
		--test)
			SUPERTEST=true
		;;
		--version|-v)
			SVERSION=true
			show_version
			exit 0
		;;
		--help|-h)
			ERROR=false
			if ${START} || ${STOP} || ${STATUS} || ${CHECKCONFIG}
			then
				ERROR=true
			else
				echo "Usage: ${APNAME} [OPTION]..."
				echo "start up or stop applications like WebLogic, Fuego, Resin, etc.\n"
				echo "Mandatory arguments in long format."
				echo "\t-a, --application=APPNAME        use this appName, required "
				echo "\t    --start                      start appName "
				echo "\t    --stop                       stop appName "
				echo "\t-r, --report                     show an small report about domains "
				echo "\t-m, --mainteneance               execute all shell plugins in mainteneance directory"
				echo "\t-s, --status                     verify the status of appName "
				echo "\t-t, --threaddump                 send a 3 signal via kernel by 3 times "
				echo "\t    --threaddump=COUNT,INTERVAL  send a 3 signal via kernel, COUNT times between INTERVAL "
				echo "\t-c, --check-config               check config application (see ${APNAME}-${APNAME}.conf) "
				echo "\t-d, --debug                      debug logs and processes in the system "
				echo "\t-m, --mail                       send output to mail accounts configured in ${APNAME}.conf "
				echo "\t    --mailto=user@mail.com       send output to mail accounts or specified mail "
				echo "\t-q, --quiet                      don't send output to terminal "
				echo "\t-v, --version                    show version "
				echo "\t-h, --help                       show help\n "
				echo "Each APPLIST refers to one application on the server."
				echo "In case of threaddump options, COUNT refers to times sending kill -3 signal between "
				echo "INTERVAL time in seconds\n"
				echo "Report bugs to <andres.aquino@gmail.com>"
			fi
			exit 0
		;;
		*)
			ERROR=true
		;;
	esac
	OPTIONS="${OPTIONS}\n${1}"
	shift
done

# verificar opciones usadas
if ${SUPERTEST}
then
	echo ${OPTIONS}
	exit 0
fi

#
if ${ERROR}
then
	echo "Usage: ${APNAME} [OPTION]...[--help]"
	exit 0
else
	#
	# CHECKCONFIG -- Verificar los parámetros del archivo de configuración
	if ${CHECKCONFIG}
	then
		check_configuration "${APPRCS}"
		LASTSTATUS=$?
		if [ ${LASTSTATUS} -eq 0 ]
		then
			report_status "*" "${APPRCS} is good, go ahead"
		else
			report_status "?" "${APPRCS} is bad, please check the log file"
		fi
		exit ${LASTSTATUS}
	fi

	#
	# verificar que la configuración exista, antes de ejecutar el servicio 
	if [ ${#APPRCS} -ne 0 ]
	then
		check_configuration "${APPRCS}" 
		get_process_id "${FILTERAPP},${FILTERLANG}"
		[ "$?" -ne "0" ] && CHECKCONFIG=true
		[ "${TOSLEEP}" -eq "0" ] && TOSLEEP=5
		TOSLEEP="$((60*$TOSLEEP))"
	else
		CANCEL=true
		${STATUS} && CANCEL=false
		${VIEWREPORT} && CANCEL=false
		${VIEWHISTORY} && CANCEL=false
		if ${CANCEL}
		then
			echo "Usage: ${APNAME} [OPTION]...[--help]"
			exit 1
		fi
	fi

	#
	# START -- Iniciar la aplicación indicada en el archivo de configuración
	if ${START}
	then	 
		cd ${PATHAPP}
		#
		# que sucede si intentan dar de alta el proceso nuevamente
		# verificamos que no exista un bloqueo (Dummies of Proof) 
		TOSLEEP="$(($TOSLEEP*2))"
		processes_running
		LASTSTATUS=$?
		if [ -f ${APLOGT}.lock ]
		then
			# es posible que si existe el bloqueo, pero que el proceso
			# no este trabajando, entonces verificamos usando los PID's
			if [ "${LASTSTATUS}" -eq "0" ]
			then
				log_action "DEBUG" "${APPRCS} have a lock process file without application, maybe a bug brain developer ?"
				[ -f ${APLOGT}.lock ] && log_action "DEBUG" "Exists a lock process without an application in memory, remove it and start again automagically"
				# mover archivos a directorio monopse/20080527-0605
				log_backup
			else
				report_status "i" "${APPRCS} running right now!"
				exit 0
			fi
		else
			# es posible que el archivo de lock no exista pero la aplicación este ejecutandose
			if [ ${LASTSTATUS} -ne 0 ]
			then
				touch "${APLOGT}.lock"
				report_status "i" "${APPRCS} running right now!"
				log_action "DEBUG" "The application lost the lock file, but is running actually"
				exit 0
			fi
		fi
		
		#
		# ejecutar el shell para iniciar la aplicación y verificar que esta exista
		if [ -r "${STARTAPP}" ]
		then
			# si se indican la variables, entonces
			# verificar que el weblogic server este ejecutandose
			[ $WLSAPP ] && check_weblogicserver
			
			# 
			# ejecutar el PREEXECUTION
			if [ ${PREEXECUTION} != "_NULL_" ]
			then
				sh ${PREEXECUTION} > ${APLOGT}.pre 2>&1 
				log_action "DEBUG" "Executing ${PREEXECUTION}, logging to ${APLOGT}.pre"
			fi
				 
			#
			# iniciar la aplicación
			if ${UNIQUELOG}
			then
				nohup sh ${STARTAPP} > ${APLOGP}.log 2>&1 &
				log_action "DEBUG" "Executing ${STARTAPP} with ${APLOGP}.log as logfile, with unique output ..." 
			else
				nohup sh ${STARTAPP} 2> ${APLOGP}.err > ${APLOGP}.log &
				log_action "DEBUG" "Executing ${STARTAPP}, ${APLOGP}.log as logfile, ${APLOGP}.err as errfile ..."
			fi
			date '+%Y%m%d-%H%M' > ${APLOGT}.date
			# summary en lock para un post-analisis
			echo "${OPTIONS}" > ${APLOGT}.lock
			echo "\nDate:\n`date '+%Y%m%d %H:%M'`" >> ${APLOGT}.lock
		fi

		#
		# a trabajar ... !
		LASTSTATUS=1
		ONSTOP=1
		INWAIT=true
		LASTLINE=""
		LINE=" ...`tail -n1 ${APLOGP}.log | rev | cut -c 1-60 | rev`"
		while ($INWAIT)
		do
			filter_in_log "${UPSTRING}"
			LASTSTATUS=$?
			[ ${LASTSTATUS} -eq 0 ] && report_status "*" "process ${APPRCS} start successfully"
			[ ${LASTSTATUS} -eq 0 ] && log_action "DEBUG" "Great!, ${APPRCS} start successfully"
			[ ${LASTSTATUS} -eq 0 ] && INWAIT=false
			if [ "${LINE}" != "${LASTLINE}" ]
			then 
				${VIEWLOG} && echo "${LINE}" 
				LINE="$LASTLINE"
			fi
			sleep 2
			ONSTOP="$(($ONSTOP+1))"
			[ $ONSTOP -ge $TOSLEEP ] && report_status "?" "Uhm, something goes wrong with ${APPRCS}"
			[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false;
			LASTLINE=" ...`tail -n1 ${APLOGP}.log | rev | cut -c 1-60 | rev`"
		done
		
		# buscar los PID's
		processes_running
		echo "\nPID:\n`cat ${APLOGT}.pid`" >> "${APLOGT}.lock"
		# le avisamos a los admins 
		#[ "${LASTSTATUS}" -ne "0" ] && DEBUG=true
		
		# FIX
		# SI LA APLPICACION CORRE UNA SOLA VEZ, ELIMINAR EL .lock
		[ $APPTYPE = "RUNONCE" ] && rm -f "${APLOGT}.lock" && log_backup
	fi
	

	#
	# STOP -- Detener la aplicación sea por instrucción o deteniendo el proceso, indicado en el archivo de configuración
	if ${STOP} 
	then
		#
		# que sucede si intentan dar de baja el proceso nuevamente
		# verificamos que exista un bloqueo (DoP) y PID
		log_action "DEBUG" "Stopping the application, please wait ..."
		TOSLEEP="$(($TOSLEEP/2))"
		processes_running
		if [ ! -s ${APLOGT}.pid ]
		then
			echo "uh, ${APNAME} is not running currently, tip: ${APNAME} --report"
			log_action "INFO" "The application is down"
			exit 0
		fi
		
		#
		# verificar que la aplicación para hacer shutdown se encuentre en el dir 
		# checar en 10 ocasiones hasta que el servicio se encuentre abajo 
		LASTSTATUS=1
		STRSTATUS="FORCED SHUTDOWN"
		[ "x${STOPAPP}" != "x" ] && NOTFORCE=false

		#
		# si es necesario que el stop sea forzado
		if ${NOTFORCE}
		then
			# 
			if [ -r ${STOPAPP} ]
			then
				STRSTATUS="NORMAL SHUTDOWN"
				sh ${STOPAPP} >> ${APLOGP}.log 2>&1 &
				log_action "INFO" "Shutdown application, please wait..."
			fi
				 
			#
			# a trabajar ... !
			LASTSTATUS=1
			ONSTOP=1
			INWAIT=true
			LASTLINE=""
			LINE="`tail -n1 ${APLOGP}.log`"
			INWAIT=true
			while ($INWAIT)
			do
				filter_in_log "${DOWNSTRING}"
				processes_running
				LASTSTATUS=$?
				[ ${LASTSTATUS} -eq 0 ] && report_status "*" "process ${APPRCS} was killed in normal mode"
				[ ${LASTSTATUS} -eq 0 ] && log_action "DEBUG" "Yeah! ${APPRCS} died placid and successfully (npray for that)"
				[ ${LASTSTATUS} -eq 0 ] && INWAIT=false
				if [ "${LINE}" != "${LASTLINE}" ]
				then 
					${VIEWLOG} && echo "${LINE}" 
					LINE="$LASTLINE"
				fi
				
				# tiempo a esperar para refrescar out en la pantalla
				sleep 2
				
				ONSTOP="$((${ONSTOP}+1))"
				log_action "DEBUG" "uhmmm, OnStop = ${ONSTOP} vs ToSleep = ${TOSLEEP}"
				if [ ${ONSTOP} -gt ${TOSLEEP} ]
				then 
					INWAIT=false
					log_action "WARN" "We have a problem Houston, the app stills remains in memory !"
				fi
				LASTLINE="`tail -n1 ${APLOGP}.log`"
			done
		fi

		#
		# si no se cancelo el proceso por la buena, entonces pasamos a la mala
		if [ ${LASTSTATUS} -ne 0 ]
		then
			# si el stop es con FORCED, y es una aplicacion JAVA enviar FTD
			if [ ${FILTERLANG} = "java" -a ${THREADDUMP} = true ]
			then
				# monopse -a=app stop -f -t=3,10
				# se aplica un fullthreaddump de 3 muestras cada 10 segundos antes de detener el proceso de manera forzada. 
				log_action "DEBUG" "before kill the baby, we send 3 FTD's between 8 secs"
				~/bin/${APNAME} --application=${APPRCS} --threaddump=${MAXSAMPLES},${MAXSLEEP}
				THREADDUMP=false
			fi
			
			log_action "WARN" "time to using the secret weapon baby: _KILL'EM ALL_ !"
			# a trabajar ... 
			LASTSTATUS=1
			ONSTOP=1
			INWAIT=true
			while ($INWAIT)
			do
				#
				# obtenemos los PID, armamos los kills y shelleamos
				processes_running
				awk '{print "kill -9 "$0}' ${APLOGT}.pid | sh
				sleep 2
				${VIEWLOG} && tail -n10 ${APLOGP}.log
				
				# checar si existen los PID's, por si el archivo no regresa el shutdown
				processes_running
				LASTSTATUS=$?
				[ ${LASTSTATUS} -eq 0 ] && report_status "*" "process ${APPRCS} was killed in --forced mode"
				[ ${LASTSTATUS} -eq 0 ] && log_action "DEBUG" "you're dead successfully fucking monkey-process from hell"
				[ ${LASTSTATUS} -eq 0 ] && break
				ONSTOP="$(($ONSTOP+1))"
				[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false
				done
				STRSTATUS="KILLED"
			fi
			
			#
			# le avisamos a los admins 
			#[ "${LASTSTATUS}" -ne "0" ] && DEBUG=true
		fi

		#
		# hacer un full thread dump a un proceso X
		if ${THREADDUMP}
		then
			make_fullthreaddump
		fi

		#
		# STATUS -- Verificar el status de la aplicación
		if ${STATUS} 
		then
			if [ ${#APPRCS} -eq 0 ]
			then
				# si no se da el parametro --application, se busca en el monopse los .conf y se consulta su estado
				count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
				log_action "DEBUG" "Wow, we have $count applications in our environment"
				[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
				for app in ${APPATH}/setup/*-*.conf
				do
					app=`basename ${app%-*}`
					~/bin/${APNAME} --application=$app --status 
				done
				echo "\nTotal $count application(s)"
			else
				# si se da el parametro de --application, procede sobre esa aplicacion 
				show_status
				LASTSTATUS=$?
				log_action "DEBUG" "Yeap, the status for [${APPRCS}] is ${LASTSTATUS}"
				
				#
				# si no se solicita el --mailreport
				#if [ "${MAILACCOUNTS}" = "_NULL_" ]
				#then
					#${VIEWLOG} && cat ${REPORT}
				#else
				#	echo "`date`" >> ${REPORT}
				#	$APMAIL -s "${APPRCS} STATUS " "${MAILACCOUNTS}" < ${REPORT} > /dev/null 2>&1 &
				#	log_action "INFO" "Sending report by mail of STATUS to ${MAILACCOUNTS}"
				#fi
				rm -f ${REPORT}
			fi
		fi

		#
		# REPORT - Generar un reporte de aplicaciones ejecutandose
		#
		# PULGOSA
		#
		# APPLICATION   | EXECUTED      | PID   | STATS										
		# --------------+---------------+-------+---------
		# test          | 20080924-0046 |       | STOPPED
		# ...
		if ${VIEWREPORT} 
		then
			IPADDRESS=`echo $SSH_CONNECTION | cut -f3 -d" "`
			count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
			[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
			#~/bin/${APNAME} --status > /dev/null 2>&1
			echo "\n ${APHOST} (${IPADDRESS})\n"
			echo "APPLICATION:EXECUTED:PID:STATUS" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print " "substr($1"                             ",1,20),
											substr($2"              ",1,14),
											substr($3"              ",1,6),
											substr($4"              ",1,6)
							}'
			echo " --------------------+---------------+-------+---------"
			
			for app in ${APPATH}/setup/*-*.conf
			do
				appname=`basename ${app%-*}`
				apppath=`awk 'BEGIN{FS="="} /^PATHAPP/{print $2}' ${app}`
				[ -s ${APTEMP}/${appname}.date ] && appdate=`cat "${APTEMP}/${appname}.date"` || appdate=
				[ -s ${APTEMP}/${appname}.pid ] && apppidn=`cat "${APTEMP}/${appname}.pid"` || apppidn=
				[ -s ${APTEMP}/${appname}.pid ] && appstat="RUNNING" || appstat="STOPPED"
				
				echo "${appname}:${appdate}:${apppidn}:${appstat}" | 
					awk 'BEGIN{FS=":";OFS="| "}
							{
								print " "substr($1"                             ",1,20),
											substr($2"              ",1,14),
											substr($3"              ",1,6),
											substr($4"              ",1,9)
							}'
			done
			echo "\nTotal $count application(s)"
		fi
		

		#
		# LOG -- enerar un reporte de aplicaciones historico de operaciones realizadas
		#
		# PULGOSA
		#
		# DATE		 | STOP	| START | SERVER						 | BACKUP
		# ---------+-------+-------+--------------------+---------------------------
		# 20080924 | 0046	| 0120	| test							 | test_20080924_0120.tar.gz
		# ...
		if ${VIEWHISTORY} 
		then
			IPADDRESS=`echo $SSH_CONNECTION | cut -f3 -d" "`
			count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
			[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
			#~/bin/${APNAME} --status > /dev/null 2>&1
			echo "\n ${APHOST} (${IPADDRESS})\n"
			echo "STOP:START:HOST:" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print substr($1"                     ",1,18),
											substr($2"                     ",1,18),
											substr($3"                     ",1,7);
							}'
			echo "------------------+-------------------------------------------------"
			tail -n600 ${APLOGS}.log |	tr -d ":[]()-" | \
						awk 'BEGIN{LAST="";OFS="| "}
									/successfully/{
									if($0~"start")
									{
										LDATE=$1;
										LTIME=$2;
									}
									else
									{
										print substr(LDATE"                     ",1,9),
													substr(LTIME"                     ",1,7),
													substr($1"                     ",1,9),
													substr($2"                     ",1,7),
													substr($3"                     ",1,14);
									}
						}' > ${APTEMP}/${APNAME}.history
			
			if [ "${APPRCS}" = "NONSETUP" ]
			then
				cat ${APTEMP}/${APNAME}.history | uniq | sort -r	| head -n60
			else
				cat ${APTEMP}/${APNAME}.history | uniq | sort -r	| head -n60 | grep "${APPRCS} "
			fi
			echo ""
		fi

		#
		# MAINTENEANCE -- ejecutar shell plugs de mantenimiento
		if ${MAINTENEANCE}
		then 
			# mantenimiento de logs principal
			cd ${APTEMP}
			log_action "INFO" "Executing maintenance of application logs..."
			find . -name "*-*.tar.gz" -mtime +4 -type f -print | while read flog
			do
				rm -f ${flog} && log_action "WARN" " deleting ${flog}"
				echo " deleting ${flog}"
			done
			
			find . -name "*-*.ftd" -mtime +4 -type f -print | while read flog
			do
				rm -f ${flog} && log_action "WARN" " deleting ${flog}"
				echo " deleting ${flog}"
			done
			# mantenimiento de logs de aplicaciones en base a shell-plugins
			#for mplugin in ${APNAME}/*-maintenance.plug
			#do
			#	 sh ${mplugin}
			#done
		fi

		#
		# DEBUG -- Depurar la aplicación
		if ${DEBUG} 
		then
			FLDEBUG="${APLOGT}.debug"
			[ -f ${FLDEBUG} ] && rm -f ${FLDEBUG}
			IPADDRESS=`echo $SSH_CONNECTION | cut -f3 -d" "`
			echo "\nDEBUG" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}
			echo "\n`date`\n" >> ${FLDEBUG}
			show_version	>> ${FLDEBUG} 2>&1
			echo "HOSTNAME     : `hostname`" >> ${FLDEBUG}
			echo "USER         : `id -u -n`" >> ${FLDEBUG}
			echo "PROCESS      : ${APPRCS}" >> ${FLDEBUG}
			echo "IPADDRESS    : ${IPADDRESS}" >> ${FLDEBUG}
			echo "DESCRIPTION  : ${DESCRIPTION}" >> ${FLDEBUG}
			echo " " >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			echo "\nDATE " >> ${FLDEBUG}
			echo "${APLOGT}.date" >> ${FLDEBUG}
			cat ${APLOGT}.date >> ${FLDEBUG} 2>&1
			echo "\nPIDFILE " >> ${FLDEBUG}
			echo "${APLOGT}.pid" >> ${FLDEBUG}
			cat ${APLOGT}.pid >> ${FLDEBUG} 2>&1
			echo "\nPROCESSES TABLE" >> ${FLDEBUG}
			processes_running
			PROCESSES=$?
			if [ "${PROCESSES}" -ne "0" ]
			then
				echo "${APPRCS} is running with ${PROCESSES} processes" >> ${FLDEBUG} 2>&1
				cat ${APLOGT}.ps >> ${FLDEBUG} 2>&1
			else
				echo "${APPRCS} is not running." >> ${FLDEBUG} 2>&1
			fi
			echo "\nFILESYSTEM" >> ${FLDEBUG}
			df ${DFOPTS} >> ${FLDEBUG} 2>&1
			echo "\nLOGFILE" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			tail -n100 ${APLOGP}.log >> ${FLDEBUG} 2>&1
			echo "	" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}
		 
			#
			# si no se solicita el --mailreport
			if [ "${MAILACCOUNTS}" = "_NULL_" ]
			then
				cat ${FLDEBUG}
			else
				$APMAIL -s "${APPRCS} DEBUG INFO " "${MAILACCOUNTS}" < ${FLDEBUG} > /dev/null 2>&1 &
				log_action "INFO" "Send information from debug application to ${MAILACCOUNTS}"
			fi
			log_action "INFO" "Show the application debug information"
	 fi
	 
	 ${STOP} && log_backup;
	 exit ${LASTSTATUS}
fi

