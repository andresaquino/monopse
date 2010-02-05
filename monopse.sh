#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai: 

# monopse.sh - An small shell for those applications that nobody wants to restart ;)
# =-=
# (c) 2008, 2009 Nextel de Mexico, S.A. de C.V.
# Andrés Aquino Morales <andres.aquino@gmail.com>
# 

#
APNAME="monopse"
. ${HOME}/${APNAME}/libutils.sh

# set environment
APPATH=${HOME}/${APNAME}
APLOGD=${HOME}/logs
APLEVL="DEBUG"
TOSLEEP=0
MAILTOADMIN=
MAILTODEVELOPER=
MAILTORADIO=
MAXSAMPLES=3
MAXSLEEP=2
APVISUALS=false

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
	mv ${APLOGP}.log ${APLOGT}.* ${DAYOF}/
	touch ${APLOGP}.log
	LOGSIZE=`du -sk "${DAYOF}" | cut -f1`
	RESULT=$((${LOGSIZE}/1024))
	
	# Si esta habilitado el fast-stop(--forced), no se comprime la informacion
	#rm -f ${APLOGT}.lock
	${FASTSTOP} && log_action "WARN" "Ups,(doesn't compress) hurry up is to late for sysadmin !"
	${FASTSTOP} && return 0
	
	# reportar action
	log_action "DEBUG" "The sizeof ${APLOGP}.log is ${LOGSIZE}M, proceeding to compress"
	
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
	PROCESS=${1}
	SHOWLOG=${2}
	
	# existe el archivo de configuracion ?
	FILESETUP="${APPATH}/setup/${PROCESS}-${APNAME}.conf"
	log_action "DEBUG" "Testing ${FILESETUP}"
	
	CHECKTEST=false
	if [ -r ${FILESETUP} ]
	then
		CHECKTEST=true
		. ${FILESETUP}
		
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
		if [ "${SHOWLOG}" = "YES" ]
		then
			echo  "File: ${FILESETUP}\n--"
			awk '/^[a-zA-Z]/{print}' ${FILESETUP}
		fi
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
		echo  "Sending a FTD to PID $PID at `date '+%H:%M:%S'`, saving in $ftdFILE"
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
	echo  "-------------------------------------------------------------------------------" > ${ftdFILE}
	echo  "-------------------------------------------------------------------------------" >> ${ftdFILE}
	echo  "JAVA FTD" >> ${ftdFILE}
	echo  "-------------------------------------------------------------------------------" >> ${ftdFILE}
	echo  "Host: `hostname`" >> ${ftdFILE}
	echo  "ID's: `id`" >> ${ftdFILE}
	echo  "Date: ${timeStart}" >> ${ftdFILE}
	echo  "Appl: ${APPRCS}" >> ${ftdFILE}
	echo  "Smpl: ${MAXSAMPLES}" >> ${ftdFILE}
	echo  "-------------------------------------------------------------------------------" >> ${ftdFILE}
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
	echo  "${APPRCS} ${TYPEOPERATION} ${STRSTATUS}, see also ${APLOGP}.log for information"
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
	VERSIONAPP="`cat ${APPATH}/VERSION | sed -e 's/-rev/ Rev./g'`"
	RELEASE=`openssl dgst -md5 ${APPATH}/${APNAME}.sh | rev | cut -c-4 | rev`
	echo "${APNAME} ${VERSIONAPP} (${RELEASE})"
	echo "(c) 2008, 2009 Nextel de Mexico, S.A. de C.V.\n"
	
	if [ ${SVERSION} ]
	then
		echo  "Written by"
		echo  "Andres Aquino <andres.aquino@gmail.com>"
	fi

}


## MAIN ##
##
# corroborar que no se ejecute como usuario r00t
if [ "`id -u`" -eq "0" ]
then
	 if [ "${MAILACCOUNTS}" = "_NULL_" ]
	 then
			echo  "Hey, i can't run as root user "
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
RESTART=false
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
MAINTENANCE=false
LOGLEVEL="DBUG"
SVERSION=false
APPTYPE="STAYRESIDENT"
UNIQUELOG=false
PREEXECUTION="_NULL_"
OPTIONS=


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
		--status|-s|status)
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
		--maintenance|-m)
			MAINTENANCE=true
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
		--uniquelog|-u)
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
				MAXSLEEP=`echo  "$1" | sed 's/.*\,//'`
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
			# deprecated option since 3.01-rev27
			MAILACCOUNTS=`echo "$1" | sed 's/^--[a-z-]*=//'`
			ERROR=false
		;;
		--mailreport)
			# deprecated option since 3.01-rev27
			MAILACCOUNTS="${MAILTOADMIN} ${MAILTODEVELOPER} ${MAILTORADIO}"
			VIEWLOG=false
			ERROR=false
		;;
		-v|--verbose)
			VIEWLOG=true
			ERROR=false
		;;
		--quiet|quiet|q)
			VIEWLOG=false
			ERROR=false
		;;
		--debug|-d)
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
		--version)
			SVERSION=true
			show_version
			exit 0
		;;
		--help|-h)
			echo  "Usage: ${APNAME} [OPTION]..."
			echo  "start up or stop applications like WebLogic, Fuego, Resin, etc.\n"
			echo  "Mandatory arguments in long format."
			echo  "\t-a, --application=APPNAME        use this appName, required "
			echo  "\t    --start                      start appName "
			echo  "\t    --stop                       stop appName "
			echo  "\t    --restart                    restart appName "
			echo  "\t-r, --report                     show an small report about domains "
			echo  "\t-m, --maintenance                execute all shell plugins in maintenance directory"
			echo  "\t-s, --status                     verify the status of appName "
			echo  "\t-t, --threaddump                 send a 3 signal via kernel by 3 times "
			echo  "\t    --threaddump=COUNT,INTERVAL  send a 3 signal via kernel, COUNT times between INTERVAL "
			echo  "\t-c, --check-config               check config application (see ${APNAME}-${APNAME}.conf) "
			echo  "\t-v, --verbose                    send output execution to terminal "
			echo  "\t-d, --debug                      debug logs and processes in the system "
			echo  "\t    --version                    show version "
			echo  "\t-h, --help                       show help\n "
			echo  "Each APPLIST refers to one application on the server."
			echo  "In case of threaddump options, COUNT refers to times sending kill -3 signal between "
			echo  "INTERVAL time in seconds\n"
			echo  "Report bugs to <andres.aquino@gmail.com>"
			exit 0
		;;
		*)
			# FEAT
			# ahora ya es posible usar el monopse $APP [options] sin usar el parametro -a o --application
			# bonito no ^.^!
			[ ${#APPRCS} -eq 0 ] && APPRCS="${1}"
			check_configuration "${APPRCS}" 
			LASTSTATUS=$?
			if [ ${LASTSTATUS} -eq 0 ]
			then
				log_action "DEBUG" "${APPRCS} seems correct"
				set_proc "${APPRCS}"
			else
				log_action "DEBUG" "${APPRCS} seems corrupted"
				report_status "i" "${APPRCS} does not exist, please check your parameters."
				exit 1
			fi
		;;
	esac
	OPTIONS="${OPTIONS}\n${1}"
	shift
done

# verificar opciones usadas
if ${SUPERTEST}
then
	echo  "Options used when monopse was called:\n ${OPTIONS}"
	exit 0
fi

#
if ${ERROR}
then
	echo  "Usage: ${APNAME} [OPTION]...[--help]"
	exit 0
else
	#
	# CHECKCONFIG -- Verificar los parámetros del archivo de configuración
	if ${CHECKCONFIG}
	then
		check_configuration "${APPRCS}" "YES"
		LASTSTATUS=$?
		if [ ${LASTSTATUS} -eq 0 ]
		then
			report_status "*" "${APPRCS} seems correct"
		else
			report_status "?" "${APPRCS} seems corrupted"
		fi
		exit ${LASTSTATUS}
	fi

	#
	# verificar que la configuración exista, antes de ejecutar el servicio 
	if [ ${#APPRCS} -ne 0 ]
	then
		BVIEWLOG=${VIEWLOG}
		VIEWLOG=false
		check_configuration "${APPRCS}" 
		get_process_id "${FILTERAPP},${FILTERLANG}"
		[ $? -ne 0 ] && CHECKCONFIG=true
		[ ${TOSLEEP} -eq 0 ] && TOSLEEP=5
		TOSLEEP="$((60*$TOSLEEP))"
		VIEWLOG=${BVIEWLOG}
	else
		CANCEL=true
		${STATUS} && CANCEL=false
		${VIEWREPORT} && CANCEL=false
		${VIEWHISTORY} && CANCEL=false
		${MAINTENANCE} && CANCEL=false
		if ${CANCEL}
		then
			echo  "Usage: ${APNAME} [OPTION]...[--help]"
			exit 1
		fi
	fi

	#
	# RESTART -- guess... ?
	if ${RESTART}
	then
		wait_for "Stopping ${APPRCS} application" 2
		${VIEWLOG} && OPTIONAL=" --verbose"
		${APNAME} --application=${APPRCS} stop --forced ${OPTIONAL}
		RESULT=$?
		wait_for "Starting ${APPRCS} application" 3
		[ ${RESULT} -eq 0 ] && ${APNAME} --application=${APPRCS} start ${OPTIONAL}
	fi

	
	#
	# START -- Iniciar la aplicación indicada en el archivo de configuración
	if ${START}
	then	 
		#
		# que sucede si intentan dar de alta el proceso nuevamente
		# verificamos que no exista un bloqueo (Dummies of Proof) 
		TOSLEEP="$(($TOSLEEP*2))"
		process_running
		LASTSTATUS=$?
		if [ -f ${APLOGT}.lock ]
		then
			# es posible que si existe el bloqueo, pero que el proceso
			# no este trabajando, entonces verificamos usando los PID's
			if [ ${LASTSTATUS} -ne 0 ]
			then
				log_action "DEBUG" "${APPRCS} have a lock process file without application, maybe a bug brain developer ?"
				[ -f ${APLOGT}.lock ] && log_action "DEBUG" "Exists a lock process without an application in memory, remove it and start again automagically"
				# mover archivos a directorio monopse/20080527-0605
				wait_for "We need a backup of logfiles right?, wait" 1
				log_backup
			else
				report_status "i" "${APPRCS} running right now!"
				exit 0
			fi
		else
			# es posible que el archivo de lock no exista pero la aplicación este ejecutandose
			if [ ${LASTSTATUS} -eq 0 ]
			then
				touch "${APLOGT}.lock"
				report_status "i" "${APPRCS} running right now!"
				log_action "DEBUG" "The application lost the lock file, but is running actually"
				exit 0
			fi
		fi
		
		#
		# ejecutar el shell para iniciar la aplicación y verificar que esta exista
		cd ${PATHAPP}
		if [ ${#STARTAPP} -ne 0 ]
		then
			log_action "DEBUG" "ready to execute ${STARTAPP} " 
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
			wait_for "${APPRCS} in process" "1"
			if ${UNIQUELOG}
			then
				${VIEWLOG} && wait_for "${APPRCS} executing, wait wait wait! (uniquelog)" 1
				nohup sh ${STARTAPP} > ${APLOGP}.log 2>&1 &
				log_action "DEBUG" "Executing ${STARTAPP} with ${APLOGP}.log as logfile, with unique output ..." 
			else
				${VIEWLOG} && wait_for "${APPRCS} executing, wait wait wait! (log and err)" 1
				nohup sh ${STARTAPP} 2> ${APLOGP}.err > ${APLOGP}.log &
				log_action "DEBUG" "Executing ${STARTAPP}, ${APLOGP}.log as logfile, ${APLOGP}.err as errfile ..."
			fi
			date '+%Y%m%d-%H%M' > ${APLOGT}.date
			# summary en lock para un post-analisis
			echo  "Options used when monopse was called:\n ${OPTIONS}" > ${APLOGT}.lock
			echo  "\nDate:\n`date '+%Y%m%d %H:%M'`" >> ${APLOGT}.lock
		fi

		#
		# a trabajar ... !
		LASTSTATUS=1
		ONSTOP=1
		INWAIT=true
		LASTLINE=""
		LINE="`tail -n1 ${APLOGP}.log`"
		while ($INWAIT)
		do
			filter_in_log "${UPSTRING}"
			LASTSTATUS=$?
			[ ${LASTSTATUS} -eq 0 ] && report_status "*" "process ${APPRCS} start successfully"
			[ ${LASTSTATUS} -eq 0 ] && log_action "DEBUG" "Great!, the ${APPRCS} start successfully"
			[ ${LASTSTATUS} -eq 0 ] && INWAIT=false
			sleep 1
			[ ${LASTSTATUS} -eq 0 ] && break
			if [ "${LINE}" != "${LASTLINE}" ]
			then 
				${VIEWLOG} && echo  "${LINE}" || wait_for "Waiting for ${APPRCS} execution, be patient ..." 1
				LINE="$LASTLINE"
			fi
			ONSTOP="$(($ONSTOP+1))"
			[ $ONSTOP -ge $TOSLEEP ] && report_status "?" "Uhm, something goes wrong with ${APPRCS}"
			[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false;
			LASTLINE="`tail -n1 ${APLOGP}.log`"
		done
		
		# buscar los PID's
		sleep 3
		get_process_id "${FILTERAPP},${FILTERLANG}"
		echo  "\nPID:\n" >> "${APLOGT}.lock" 2>&1
		cat ${APLOGT}.pid >> "${APLOGT}.lock" 2>&1

		# le avisamos a los admins 
		#[ "${LASTSTATUS}" -ne "0" ] && DEBUG=true
		
		# FIX
		# SI LA APLPICACION CORRE UNA SOLA VEZ, ELIMINAR EL .lock
		[ $APPTYPE = "RUNONCE" ] && rm -f "${APLOGT}.lock" && log_backup
		exit ${LASTSTATUS}
	fi
	

	#
	# STOP -- Detener la aplicación sea por instrucción o deteniendo el proceso, indicado en el archivo de configuración
	if ${STOP} 
	then
		#
		# verificar que la aplicación para hacer shutdown se encuentre en el dir 
		# checar en 10 ocasiones hasta que el servicio se encuentre abajo 
		LASTSTATUS=0
		STRSTATUS="FORCED SHUTDOWN"
		[ ${#STOPAPP} -eq 0 ] && NOTFORCE=false && FASTSTOP=true
		[ ${#DOWNSTRING} -eq 0 ] && NOTFORCE=false && FASTSTOP=true

		#
		# que sucede si intentan dar de baja el proceso nuevamente
		# verificamos que exista un bloqueo (DoP) y PID
		log_action "DEBUG" "Stopping the application, please wait ..."
		TOSLEEP="$(($TOSLEEP/2))"
		log_backup
		process_running
		if [ ! -s ${APLOGT}.pid ]
		then
			echo  "uh, ${APPRCS} is not running currently, tip: ${APNAME} --report"
			log_action "INFO" "The application is down"
			exit 0
		fi
		
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
			LINE="`tail -n1 ${APLOGP}.log `"
			INWAIT=true
			while ($INWAIT)
			do
				filter_in_log "${DOWNSTRING}"
				process_running
				LASTSTATUS=$?
				[ ${LASTSTATUS} -ne 0 ] && report_status "*" "process ${APPRCS} was killed in normal mode"
				[ ${LASTSTATUS} -ne 0 ] && log_action "DEBUG" "Yeah! the ${APPRCS} died placid and successfully (pray for it)"
				[ ${LASTSTATUS} -ne 0 ] && INWAIT=false
				if [ "${LINE}" != "${LASTLINE}" ]
				then 
					${VIEWLOG} && echo "${LINE}" 
					LINE="$LASTLINE"
				fi
				
				# tiempo a esperar para refrescar out en la pantalla
				wait_for "Waiting for ${APPRCS} termination, be patient ..." 1
				
				ONSTOP="$((${ONSTOP}+1))"
				log_action "DEBUG" "uhmmm, OnStop = ${ONSTOP} vs ToSleep = ${TOSLEEP}"
				if [ ${ONSTOP} -gt ${TOSLEEP} ]
				then 
					INWAIT=false
					log_action "WARN" "We have a problem Houston, ${APPRCS} stills remains in memory !"
				fi
				LASTLINE="`tail -n1 ${APLOGP}.log `"
			done
		fi

		#
		# si no se cancelo el proceso por la buena, entonces pasamos a la mala
		if [ ${LASTSTATUS} -eq 0 ]
		then
			# si el stop es con FORCED, y es una aplicacion JAVA enviar FTD
			if [ ${FILTERLANG} = "java" -a ${THREADDUMP} = true ]
			then
				# monopse -a=app stop -f -t=3,10
				# se aplica un fullthreaddump de 3 muestras cada 10 segundos antes de detener el proceso de manera forzada. 
				log_action "DEBUG" "before kill the baby, we send 3 FTD's between 8 secs"
				${APNAME} --application=${APPRCS} --threaddump=${MAXSAMPLES},${MAXSLEEP}
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
				wait_for "Uhmmm, you're a impatient guy !!" 2
				process_running
				if [ $? -eq 0 ]
				then
					awk '{print "kill -9 "$0}' ${APLOGT}.pid | sh
					wait_for "Ok, sending the kill-bill signal, can you wait some seconds?" 2
					LASTLINE="`tail -n3 ${APLOGP}.log `"
					${VIEWLOG} && echo "${LASTLINE}"
				fi

				# checar si existen los PID's, por si el archivo no regresa el shutdown
				process_running
				LASTSTATUS=$?
				[ ${LASTSTATUS} -ne 0 ] && report_status "*" "process ${APPRCS} was killed in --forced mode"
				[ ${LASTSTATUS} -ne 0 ] && log_action "DEBUG" "fucking monkey-process ${APPRCS} is dead successfully "
				[ ${LASTSTATUS} -ne 0 ] && break
				ONSTOP="$(($ONSTOP+1))"
				[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false
				done
				STRSTATUS="KILLED"
			fi

			[ ${LASTSTATUS} -ne 0 ] && exit 0
			
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
				${VIEWLOG} && OPTIONAL=" --verbose"
				count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
				log_action "DEBUG" "Wow, we have $count applications in our environment"
				[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
				for app in ${APPATH}/setup/*-*.conf
				do
					app=`basename ${app%-*}`
					${APNAME} --application=$app --status ${OPTIONAL}
				done
				echo  "\nTotal $count application(s)"
			else
				# si se da el parametro de --application, procede sobre esa aplicacion 
				process_running
				PROCESSES=$?
				if [ ${PROCESSES} -eq 0 ]
				then
					WITHLOCK="out of control of ${APNAME}"
					[ -f ${APLOGT}.lock ] && WITHLOCK="controlled by ${APNAME}"
					STR="${APPRCS} is running ${WITHLOCK}" 
					report_status "*" "${STR}"
				else
					STR="${APPRCS} is not running" 
					[ -f ${APLOGT}.lock ] && rm -f ${APLOGT}.lock
					[ -f ${APLOGT}.pid ] && rm -f ${APLOGT}.pid
					report_status "i" "${STR}"
				fi
				log_action "DEBUG" "hey, ${STR}"
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
			IPADDRESS=`${PING} ${APHOST} ${PINGPARAMS} 1 2> /dev/null | awk '/bytes from/{gsub(":","",$4);print $4}' | sed -e "s/[a-zA-Z][a-zA-Z]*[\.]*[ ]*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`echo $SSH_CONNECTION 2> /dev/null | awk '{print $3}' | sed -e "s/.*://g;s/ .*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}0 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}1 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
			[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
			processes_running
			echo  "\n ${APHOST} (${IPADDRESS})\n"
			echo  "APPLICATION:EXECUTED:PID:STATUS" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print " "substr($1"                             ",1,20),
											substr($2"              ",1,14),
											substr($3"              ",1,6),
											substr($4"              ",1,6)
							}'
			echo  " --------------------+---------------+-------+---------"
			
			for app in ${APPATH}/setup/*-*.conf
			do
				appname=`basename ${app%-*}`
				apppath=`awk 'BEGIN{FS="="} /^PATHAPP/{print $2}' ${app}`
				log_action "DEBUG" "report from ${APTEMP}/${appname}"
				[ -s ${APTEMP}/${appname}.date ] && appdate=`head -n1 "${APTEMP}/${appname}.date"` || appdate=
				[ -s ${APTEMP}/${appname}.pid ] && apppidn=`head -n1 "${APTEMP}/${appname}.pid"` || apppidn=
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
			echo  "\nTotal $count application(s)"
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
			IPADDRESS=`${PING} ${APHOST} ${PINGPARAMS} 1 2> /dev/null | awk '/bytes from/{gsub(":","",$4);print $4}' | sed -e "s/[a-zA-Z][a-zA-Z]*[\.]*[ ]*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`echo $SSH_CONNECTION 2> /dev/null | awk '{print $3}' | sed -e "s/.*://g;s/ .*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}0 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}1 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
			[ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
			echo  "\n ${APHOST} (${IPADDRESS})\n"
			echo  "START:STOP:APPLICATION:" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print substr($1"                     ",1,18),
											substr($2"                     ",1,18),
											substr($3"                     ",1,28);
							}'
			echo  "------------------+-------------------------------------------------"
			log_action "DEBUG" "report from ${APLOGS}.log "
			tail -n5000 ${APLOGS}.log |	tr -d ":[]()-" | sort -r | \
						awk 'BEGIN{LAST="";OFS="| "}
									/successfully/{
									if($0~"start")
									{
										LDATE=$1;
										LTIME=$2;
										PROCS=$8;
									}
									else
									{
										print substr(LDATE"                     ",1,9),
													substr(LTIME"                     ",1,7),
													substr($1"                     ",1,9),
													substr($2"                     ",1,7),
													substr($8"                     ",1,28);
									}
						}' > ${APTEMP}/${APNAME}.history
			
			if [ "${APPRCS}" = "NONSETUP" ]
			then
				cat ${APTEMP}/${APNAME}.history | uniq | sort | head -n25
			else
				cat ${APTEMP}/${APNAME}.history | uniq | sort | head -n25 | grep "${APPRCS} "
			fi
			echo  ""
		fi

		#
		# MAINTENANCE -- ejecutar shell plugs de mantenimiento
		if ${MAINTENANCE}
		then 
			# mantenimientos
			count=`ls -l ${APPATH}/setup/*-shell.plug | wc -l | sed -e "s/ //g"`
			[ $count -eq 0 ] && report_status "?" "Cannot access any maintenance file " && exit 1
			cd ${APPATH}/setup/
			for APMAIN in *-shell.plug
			do
				MLOGFILE=${APMAIN%-shell*}
				log_action "DEBUG" "Executing maintenance ${MDESCRIPTION} "
				. ${APMAIN}
				log_action "DEBUG" "Moving to ${MPATH}"
				cd ${MPATH}
				
				log_action "DEBUG" "Getting files using: find . -name ${MFILTER} -mtime ${MTIME} -type ${MTYPE}"
				wait_for "Getting files from pattern (${MFILTER})" 2
				if [ "${MTYPE}" = "DIRECTORY" ]
				then
					find . -name "${MFILTER}" -mtime "${MTIME}" -type d > ${APTEMP}/${MLOGFILE}.objects 2> /dev/null
					
					# by the moment, only DELETE and CLEAR action supported
					awk '{print "rm -fr "$0}' ${APTEMP}/${MLOGFILE}.objects > ${APTEMP}/${MLOGFILE}.execs
					[ "${MACTION}" = "CLEAR" ] && awk '{print "rm -f "$0"/*}' ${APTEMP}/${MLOGFILE}.objects > ${APTEMP}/${MLOGFILE}.execs
				else
					find . -name "${MFILTER}" -mtime "${MTIME}" -type f > ${APTEMP}/${MLOGFILE}.objects 2> /dev/null
					
					# by the moment, only DELETE and CLEAR action supported
					awk '{print "rm -f "$0}' ${APTEMP}/${MLOGFILE}.objects > ${APTEMP}/${MLOGFILE}.execs
					[ "${MACTION}" = "CLEAR" ] && awk '{print "echo ""> "$0}' ${APTEMP}/${MLOGFILE}.objects > ${APTEMP}/${MLOGFILE}.execs
				fi
				if [ -s ${APTEMP}/${MLOGFILE}.execs ]
				then
					log_action "DEBUG" "Please check ${APTEMP}/${MLOGFILE}.execs"
					report_status "*" "Check ${APTEMP}/${MLOGFILE}.execs"
					if [ "${MDEBUG}" = "NO" ]
					then
						sh -x ${APTEMP}/${MLOGFILE}.execs > ${APTEMP}/${MLOGFILE}.log 2>&1
						log_action "DEBUG" "Well, you'ld pray because the system remains stable"
						report_status "i" "You should pray because the system remains stable"
					else
						log_action "DEBUG" "Good, you're a good boy (lamer) but, a good boy"
					fi 
				else
					report_status "i" "Uhmm, yeah... time to scratching eyes!"
				fi
				cd ${APPATH}/setup/
				report_status "*" "Ok, ${APMAIN} executed"
			done
		fi

		#
		# DEBUG -- Depurar la aplicación
		if ${DEBUG} 
		then
			FLDEBUG="${APLOGT}.debug"
			[ -f ${FLDEBUG} ] && rm -f ${FLDEBUG}
			IPADDRESS=`${PING} ${APHOST} ${PINGPARAMS} 1 2> /dev/null | awk '/bytes from/{gsub(":","",$4);print $4}' | sed -e "s/[a-zA-Z][a-zA-Z]*[\.]*[ ]*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`echo $SSH_CONNECTION 2> /dev/null | awk '{print $3}' | sed -e "s/.*://g;s/ .*//g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}0 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			[ "x$IPADDRESS" = "x" ] && IPADDRESS=`${IFCONFIG} ${IFPARAMS}1 2> /dev/null | awk '/ inet/{print $2}' | head -n1 | sed -e "s/[a-z]*://g"`
			echo  "\nDEBUG" >> ${FLDEBUG}
			echo  "-------------------------------------------------------------------------------" >> ${FLDEBUG}
			show_version	>> ${FLDEBUG} 2>&1
			echo  "\n\nHOSTNAME     : ${APHOST}" >> ${FLDEBUG}
			echo  "USER         : ${APUSER}" >> ${FLDEBUG}
			echo  "PROCESS      : ${APPRCS}" >> ${FLDEBUG}
			echo  "CURRENT      : ${APDATE}" >> ${FLDEBUG}
			echo  "IPADDRESS    : ${IPADDRESS}" >> ${FLDEBUG}
			echo  "DESCRIPTION  : ${DESCRIPTION}" >> ${FLDEBUG}
			echo  " " >> ${FLDEBUG}
			echo  "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			echo  "\nDATE " >> ${FLDEBUG}
			echo  "${APLOGT}.date" >> ${FLDEBUG}
			cat ${APLOGT}.date >> ${FLDEBUG} 2>&1
			echo  "\nPIDFILE " >> ${FLDEBUG}
			echo  "${APLOGT}.pid" >> ${FLDEBUG}
			cat ${APLOGT}.pid >> ${FLDEBUG} 2>&1
			echo  "\nPROCESSES TABLE" >> ${FLDEBUG}
			process_running
			PROCESSES=$?
			if [ ${PROCESSES} -eq 0 ]
			then
				echo  "${APPRCS} is running" >> ${FLDEBUG} 2>&1
				cat ${APLOGT}.ps >> ${FLDEBUG} 2>&1
			else
				echo  "${APPRCS} is not running." >> ${FLDEBUG} 2>&1
			fi
			echo  "\nFILESYSTEM" >> ${FLDEBUG}
			df ${DFOPTS} >> ${FLDEBUG} 2>&1
			echo  "\nLOGFILE" >> ${FLDEBUG}
			echo  "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			tail -n100 ${APLOGP}.log >> ${FLDEBUG} 2>&1
			echo  "	" >> ${FLDEBUG}
			echo  "-------------------------------------------------------------------------------" >> ${FLDEBUG}
		 
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

