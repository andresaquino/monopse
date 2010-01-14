#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai: 

# starter.sh - An small shell for those applications that nobody wants to restart ;)
# =-=
# (c) 2009 StrategyLabs!
# Andrés Aquino Morales <andres.aquino@gmail.com>
# 

#
. ${HOME}/starter/libutils.sh

#
# filter_in_log
# filtrar la cadena sugerida en el log de la aplicacion
filter_in_log () {
	 local SEARCHSTR
	 SEARCHSTR="${1}"

	 [ "${SEARCHSTR}" = "_NULL_" ] && return 1
	 grep -q "${SEARCHSTR}" "${APLOGS}.log"
	 LASTSTATUS=$?

	 if [ "${LASTSTATUS}" -eq "0" ]
	 then
			log_action "DBUG" "Looking for ${SEARCHSTR} was succesfull"
	 fi
	 return ${LASTSTATUS}
}


#
# log_backup
# respaldar logs para que no se generen problemas de espacio.
log_backup () {
	 #
	 # filename: starter/starter-cci-20080516-2230.tar.gz
	 DAYOF=`date '+%Y%m%d-%H%M'`
	 cd ${DIRLOG}
	 if [ -e ${APLOGS}.date ]
	 then
			DAYOF="`cat ${APLOGS}.date`"
			rm -f ${APLOGS}.date 
	 fi
	 mkdir -p ${DAYOF}
	 touch ${APLOGS}.log
	 touch ${APLOGS}.err
	 touch ${APLOGS}.pid
	 mv ${APLOGS}.log ${APLOGS}.err ${APLOGS}.pid ${DAYOF}/
	 touch ${APLOGS}.log
	 LOGSIZE=`du -sk "${DAYOF}" | cut -f1`
	 RESULT=$((${LOGSIZE}/1024))
	 
	 # reportar action
	 log_action "INFO" "The sizeof ${APLOGS}.log is ${LOGSIZE}M, proceeding to compress"

	 # Si esta habilitado el fast-stop(--forced), no se comprime la informacion
	 rm -f ${APLOGS}.lock
	 ${FASTSTOP} && log_action "WARN" "Ups,(doesn't compress) hurry up is to late for sysadmin !"
	 ${FASTSTOP} && return 0

	 # si el tamaño del archivo .log sobrepasa los MAXLOGSIZE en megas 
	 # entonces hacer un recorte para no saturar el filesystem
	 if [ ${RESULT} -gt ${MAXLOGSIZE} ]
	 then
			log_action "WARN" "The sizeof ${APLOGS}.log is ${LOGSIZE}M, i need reduce it to ${MAXLOGSIZE}M"
			SIZE=$((${MAXLOGSIZE}*1024*1024))
			tail -c${SIZE} ${DAYOF}/${APPLICATION}.log > ${DAYOF}/${APPLICATION}
			rm -f ${DAYOF}/${APPLICATION}.log
			mv ${DAYOF}/${APPLICATION} ${DAYOF}/${APPLICATION}.log
	 fi
	 
	 #
	 # por que HP/UX tiene que ser taaan estupido ? ? 
	 # backup de log | err | pid para análisis
	 # tar archivos | gzip -c > file-log
	 $aptar -cvf ${APLOGS}_${DAYOF}.tar ${DAYOF} > /dev/null 2>&1
	 $apzip -c ${APLOGS}_${DAYOF}.tar > ${APLOGS}_${DAYOF}.tar.gz
	 LOGSIZE=`du -sk ${APLOGS}_${DAYOF}.tar.gz | cut -f1`
	 log_action "INFO" "Creating ${APLOGS}_${DAYOF}.tar.gz file with ${LOGSIZE}M of size"
	 
	 rm -f ${APLOGS}_${DAYOF}.tar
	 rm -fr ${DAYOF}

}


#
# guess !
# solo un estupido wrap por que el logger del SO no tenemos chance de usarlo ... 
log_action () {
	 LEVEL=${1}
	 ACTION=${2}
	 PID=0
	 LOGME=true
	 [ -r ${APLOGS}.pid ] && PID=`head -n1 ${APLOGS}.pid`
	 case "${LEVEL}" in
			"DBUG")
				 [ "${LOGLEVEL}" = "INFO" ] && LOGME=false
				 [ "${LOGLEVEL}" = "WARN" ] && LOGME=false
				 ;;
			"WARN")
				 [ "${LOGLEVEL}" = "INFO" ] && LOGME=false
				 ;;
	 esac

	 if ${LOGME}
	 then
			echo "`date '+%Y-%m-%d'` [`date '+%H:%M:%S'`] ${APPLICATION}(${PID}): ${LEVEL} ${ACTION}" >> ${APLOGS}.log
	 fi

}


#
# is_process_running
# verificar si un proceso se encuenta ejecutandose en base a su PID
is_process_running () {
	 #
	 # obtener los PID del proceso 
	 get_process_id
	 if [ ! -e "${APLOGS}.pid" ]
	 then
			[ $VIEWLOG ] && echo "The application is not running actually"
			log_action "INFO" "The application is down"
			exit 0
	 fi

	 if [ "`uname -s`" = "HP-UX" ]
	 then
			PROCESSES=`awk '{print "ps -fex | grep "$0" | grep -v grep"}' "${APLOGS}.pid" | sh | grep "${FILTERLANG}" | grep "${FILTERAPP}" | grep -v grep | wc -l | cut -f1 -d" " `
	 else
			PROCESSES=`awk '{print "ps fax | grep "$0" | grep -v grep"}' "${APLOGS}.pid" | sh | grep "${FILTERLANG}" | grep "${FILTERAPP}" | grep -v grep | wc -l | cut -f1 -d" " `
	 fi

	 if [ "${PROCESSES}" -gt 0 ]
	 then
			return "${PROCESSES}"
			log_action "INFO" "The application is running with ${PROCESSES} processes in memory"
	 else
			return 0
	 fi

}


#
# get_process_id
# obtener los PID de las aplicaciones
get_process_id () {
	 #
	 # filtrar primero por APP
	 rm -f "${APLOGS}.pid"

	 # FIX
	 # filtrar por usuario dueño del proceso
	 ps ${psopts} | grep "${FILTERAPP}" | grep -v "grep"	| grep -v "$NAMEAPP " | grep "${USER}" > "${APLOGS}.tmp"

	 # si existe, despues por LANG
	 if [ "${FILTERLANG}" != "" ]
	 then
			mv "${APLOGS}.tmp" "${APLOGS}.tmp.1"
			grep "${FILTERLANG}" "${APLOGS}.tmp.1" | grep -v "grep" > "${APLOGS}.tmp"
	 fi
	 
	 # si existe 1 o mas procesos, entonces averiguar el PPID (Parent Process ID) 
	 # y almacenarlo, en caso contrario solo generar archivo vacio
	 touch "${APLOGS}.pid"
	 if [ `wc -l "${APLOGS}.tmp" | cut -f1 -d\ ` -gt 0 ]
	 then
			log_action "DBUG" "The application still remains in memory ... "
			awk '{print $2}' "${APLOGS}.tmp" > "${APLOGS}.tmp.1"
			# FIX: sacar el proceso padre, ordenando los process id y sacando el primero
			cat "${APLOGS}.tmp.1" | sort -n | head -n1 > "${APLOGS}.pid"
			# FIX: para el caso de iPlanet, es necesario conservar todos los pids implicados
			#			 y así poder obtener el último pid para aplicar un FTD
			cat "${APLOGS}.tmp.1" | sort -nr > "${APLOGS}.plist"
	 fi
	 rm -f "${APLOGS}.tmp" "${APLOGS}.tmp.1"
}


#
# check_configuration
# corroborar que los parametros/archivos sean correctos y existan en el filesystem
check_configuration () {
	 local LASTSTATUS APPLICATION FILESETUP VERBOSE PARAM
	 LASTSTATUS=1
	 APPLICATION="${1}"
	 VERBOSE="${2}"
	 
	 "${VERBOSE}" && echo "Checking configuration of ${APPLICATION}"
	 # existe el archivo de configuracion ?
	 FILESETUP="${APHOME}/setup/${APPLICATION}-starter.conf"
	 [ -r "${FILESETUP}" ] && . "${FILESETUP}" || return ${LASTSTATUS}
	 
	 # leer los parametros minimos necesarios
	 for PARAM in STARTAPP STOPAPP PATHAPP FILTERAPP UPSTRING
	 do 
			#"${VERBOSE}" && grep "${PARAM}=" "${FILESETUP}" 
			# checar que los datos del archivo de configuracion sean correctos
			grep -q "${PARAM}=" "${FILESETUP}" && LASTSTATUS=0
	 done
	 
	 # como minimo, comprobamos que exista el PATH
	 [ -d ${PATHAPP} ] || LASTSTATUS=1

	 return ${LASTSTATUS}

}


#
# verificar que el servidor weblogic (en el caso de los appsrv's se encuentre arriba y operando,
# de otra manera, ejecutar una rutina _plugin_ para iniciar el servicio )
check_weblogicserver() {
	 # si se dio de alta la variable FILTERWL(weblogic.Server), entonces se tiene que buscar si existe el proceso de servidor WEBLOGIC
	 if [ ${FILTERWL} != "_NULL_" ]
	 then
				 log_action "INFO" "Check if exists an application server manager of WebLogic"
				 # existe algun proceso de weblogic.Server ?
				 if [ "`uname -s`" = "HP-UX" ]
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
						nohup sh ${WLSAPP} 2> ${APLOGS}-WLS.err > ${APLOGS}-WLS.log &
						sleep ${WLSLEEP}
				 fi
	 fi

}


#
# realizar un kernel full thread dump sobre el proceso indicado.
# sobre procesos non-java va a valer queso, por que la señal 3 es para hacer un volcado de memoria.
# starter --application=resin --threaddump=5 --mailto=cesar.aquino@nextel.com.mx
# por defecto, el ftd se almacena en el filesystem log de la aplicación; si se detecta que se esta
# incrementando el uso del filesystem, conserva los mas recientes 
make_fullthreaddump() {
	 # para cuando son procesos JAVA StandAlone (WL, Tomcat, etc...) 
	 log_action "DBUG" "Change to ${PATHAPP}"
	 [ -r ${APLOGS}.pid ] && PID=`tail -n1 ${APLOGS}.pid`

	 # para cuando son procesos ONDemand (iPlanet, ...)
	 [ -r ${APLOGS}.plist -a ${FILTERAPP} ] && PID=`head -n1 ${APLOGS}.pid`
	 
	 # hacer un mark para saber desde donde vamos a sacar datos del log
	 ftdFILE="${APLOGS}_`date '+%Y%m%d-%H%M%S'`.ftd"
	 touch "${ftdFILE}"
	 log_action "DBUG" "Taking ${APLOGS}.log to extract the FTP on ${ftdFILE}"
	 tail -f "${APLOGS}.log" > ${ftdFILE} &

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
	 if [ "`uname -s`" = "HP-UX" ]
	 then
			PROCESSES=`ps -fex | grep "tail -f ${APLOGS}.log" | grep -v grep | awk '/tail/{print $2}'`
	 else
			PROCESSES=`ps fax | grep "tail -f ${APLOGS}.log" | grep -v grep | awk '/tail/{print $2}'`
	 fi
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
	 echo "Appl: ${APPLICATION}" >> ${ftdFILE}
	 echo "Smpl: ${MAXSAMPLES}" >> ${ftdFILE}
	 echo "-------------------------------------------------------------------------------" >> ${ftdFILE}
	 cat ${ftdFILE}.tmp >> ${ftdFILE}
 
	 # enviar por correo 
	 if [ "${MAILACCOUNTS}" != "_NULL_" ]
	 then
			$apmail -s "${APPLICATION} FULL THREAD DUMP ${timeStart} (${ftdFILE})" "${MAILACCOUNTS}" < ${ftdFILE} > /dev/null 2>&1 &
			log_action "INFO" "Sending a full thread dump(${ftdFILE}) by mail to ${MAILACCOUNTS}"
	 fi
	 #rm -f ${ftdFILE}
	 rm -f ${ftdFILE}.tmp
	 return 0

}


#
# report_status
# generar reporte via mail para los administradores
report_status () {
	 local TYPEOPERATION STATUS STRSTATUS FILESTATUS 
	 TYPEOPERATION=${1}
	 STATUS=${2}

	 if [ "${STATUS}" -eq "0" ]
	 then
			STRSTATUS="SUCCESS"
			FILESTATUS="${APLOGS}.log"
			log_action "INFO" "The application ${TYPEOPERATION} ${STRSTATUS}"
	 else
			STRSTATUS="FAILED"
			FILESTATUS="${APLOGS}.err"
			log_action "ERR" "The application ${TYPEOPERATION} ${STRSTATUS}"
	 fi
	 
	 #
	 # solo enviar si la operacion fue correcta o no
	 echo "${APPLICATION} ${TYPEOPERATION} ${STRSTATUS}, see also ${APLOGS}.log for information"
	 if [ "${MAILACCOUNTS}" != "_NULL_" ]
	 then
			# y mandarlo a bg, por que si no el so se apendeja, y por este; este arremedo de programa :-P
			$apmail -s "${APPLICATION} ${TYPEOPERATION} ${STRSTATUS}" -r "${MAILACCOUNTS}" > /dev/null 2>&1 &
			log_action "INFO" "Report ${APPLICATION} ${TYPEOPERATION} ${STRSTATUS} to ${MAILACCOUNTS}"
	 fi

}


#
# obtiene la version de la aplicación
show_version () {
	 # como ya cambie de SVN a GIT, no puedo usar el Id keyword, entonces ... a pensar en otra opcion ! ! ! 
	 IDAPP='$Id$'
	 
	 VERSIONAPP="2"
	 UPVERSION=`echo ${VERSIONAPP} | sed -e "s/..$//g"`
	 RLVERSION=`awk '/200/{t=substr($2,6,7);gsub("-",".",t);print t}' ${HOME}/${NAMEAPP}/CHANGELOG | head -n1`
	 echo "${NAMEAPP} v${UPVERSION}.${RLVERSION}"
	 echo "(c) 2008, 2009, 2010 StrategyLabs! \n"

	 if ${SVERSION}
	 then
			echo "Written by"
			echo "Andres Aquino <andres.aquino@gmail.com>"
	 fi

}


#
# obtiene el estatus de la aplicación
show_status () {
	 REPORT="${DIRLOG}/report.inf"
	 [ ! -e ${REPORT} ] && rm -f ${REPORT}
	 is_process_running
	 PROCESSES=$?
	 if [ "${PROCESSES}" -ne "0" ]
	 then
			WITHLOCK="out of control of starter!"
			[ -r "${APLOGS}.lock" ] && WITHLOCK="controlled by ${NAMEAPP}."
			echo "${APPLICATION} is running with ${PROCESSES} processes ${WITHLOCK}" >> ${REPORT}
			cat ${APLOGS}.pid >> ${REPORT}
			return 0
	 else
			echo "${APPLICATION} is not running." >> ${REPORT}
			return 1
	 fi

}


#
# MAIN
NAMEAPP="`basename ${0%.*}`"
TOSLEEP=0
MAILTOADMIN=""
MAILTODEVELOPER=""
MAILTORADIO=""
MAXSAMPLES=3
MAXSLEEP=2

# corroborar que no se ejecute como usuario r00t
if [ "`id -u`" -eq "0" ]
then
	 if [ "${MAILACCOUNTS}" = "_NULL_" ]
	 then
			echo "Hey, i can't run as root user "
	 else
			$apmail -s "Somebody tried to run me as r00t user" "${MAILACCOUNTS}" < "$@" > /dev/null 2>&1 &
			log_action "WARN" "Somebod tried to run me as r00t, sending warn to ${MAILACCOUNTS}"
	 fi
	 
fi

#
# Opciones por defecto
APPLICATION="NONSETUP"
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
MAINTENANCE=false
LOGLEVEL="DBUG"
SVERSION=false
APPTYPE="STAYRESIDENT"
UNIQUELOG=false
PREEXECUTION="_NULL_"
OPTIONS="Options used when starter was called:"

#
# application's home by default
APHOME=$HOME/monopse
APLOGS=$HOME/logs

#
# applications setup
if [ -r $HOME/.starterrc ]
then
	. $HOME/.starterrc
fi

#
# esta parte esta reculera pero ni pedo, tengo weba de corregirlo en este momento...
aptar=`which tar`
apzip=`which gzip`
apmail=`which mail`
psopts="-fea"
bdf="df"
typeso="`uname -s`"
[ "${typeso}" = "HP-UX" ] && apmail=`which mailx`
[ "${typeso}" = "HP-UX" ] && bdf="bdf"
[ "${typeso}" = "HP-UX" ] && psopts="-fex"

#
# parametros 
while [ $# -gt 0 ]
do
	case "${1}" in
		-a=*|--application=*)
			APPLICATION=`echo "$1" | sed 's/^--[a-z-]*=//'`
			APPLICATION=`echo "${APPLICATION}" | sed 's/^-a=//'`
			if [ "x" = "x${APLOGS}" ]
			then
				APLOGS=${HOME}/logs
			fi
			DIRLOG=${APLOGS}
			mkdir -p ${DIRLOG}
			APLOGS=${APLOGS}/${APPLICATION}
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

		-t|--threaddump)
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
				echo "Usage: ${NAMEAPP} [OPTION]..."
				echo "start up or stop applications like WebLogic, Fuego, Resin, etc.\n"
				echo "Mandatory arguments in long format."
				echo "\t-a, --application=APPNAME        use this appName, required "
				echo "\t    --start                      start appName "
				echo "\t    --stop                       stop appName "
				echo "\t-s, --status                     verify the status of appName "
				echo "\t-t, --threaddump=COUNT,INTERVAL  send a 3 signal via kernel, COUNT times between INTERVAL "
				echo "\t-d, --debug                      debug logs and processes in the system "
				echo "\t-c, --check-config               check config application (see ${NAMEAPP}-starter.conf) "
				echo "\t-r, --report                     show an small report about domains "
				echo "\t-m, --mail                       send output to mail accounts configured in ${NAMEAPP}.conf "
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
	echo "Usage: ${NAMEAPP} [OPTION]...[--help]"
	exit 0
else
	#
	# verificar que la configuración exista, antes de ejecutar el servicio 
	if [ ${APPLICATION} != "NONSETUP" ]
	then
		check_configuration "${APPLICATION}" false
		[ "$?" -ne "0" ] && CHECKCONFIG=true
		[ "${TOSLEEP}" -eq "0" ] && TOSLEEP=5
		TOSLEEP="$((60*$TOSLEEP))"
	else
		CANCEL=true
		${STATUS} && CANCEL=false
		${VIEWREPORT} && CANCEL=false
		${VIEWHISTORY} && CANCEL=false
		${VIEWLOG} && CANCEL=false
		if ${CANCEL}
		then
			echo "Usage: starter [OPTION]...[--help]"
			exit 1
		fi
	fi

	#
	# CHECKCONFIG -- Verificar los parámetros del archivo de configuración
	if ${CHECKCONFIG}
	then
		check_configuration "${APPLICATION}" true
		LASTSTATUS=$?
		FILESETUP="${APHOME}/setup/${APPLICATION}-starter.conf"
		if [ "${LASTSTATUS}" -ne "0" ]
		then
			echo "${FILESETUP} have errors, check your parameters."
		else
			grep "^[A-Z]" "${FILESETUP}"
			echo "${FILESETUP} was configured correctly."
		fi
		exit ${LASTSTATUS}
	fi

	#
	# START -- Iniciar la aplicación indicada en el archivo de configuración
	if ${START}
	then	 
		#
		# que sucede si intentan dar de alta el proceso nuevamente
		# verificamos que no exista un bloqueo (Dummies of Proof) 
		TOSLEEP="$(($TOSLEEP*2))"
		is_process_running
		LASTSTATUS=$?
		if [ -e "${APLOGS}.lock" ]
		then
			# es posible que si existe el bloqueo, pero que el proceso
			# no este trabajando, entonces verificamos usando los PID's
			if [ "${LASTSTATUS}" -eq "0" ]
			then
				echo "${APPLICATION} have a lock process file without application, maybe a bug brain developer ?"
				rm -f "${APLOGS}.lock"
				log_action "WARN" "Exists a lock process without an application in memory, remove it and start again automagically"
				# mover archivos a directorio starter/20080527-0605
				log_backup
			else
				echo "${APPLICATION} is running right now !"
				exit 0
			fi
		else
			# es posible que el archivo de lock no exista pero la aplicación este ejecutandose
			if [ "${LASTSTATUS}" -gt "0" ]
			then
				touch "${APLOGS}.lock"
				echo "${APPLICATION} is running right now !"
				log_action "WARN" "The application lost the lck file, but is running actually"
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
				log_action "INFO" "Executing ${PREEXECUTION} before any app"
				PRELOG=${APLOGS}.pre
				sh ${PREEXECUTION} > ${PRELOG} 2>&1 
			fi
				 
			#
			# iniciar la aplicación
			if ${UNIQUELOG}
			then
				log_action "INFO" "Executing ${STARTAPP} with ${APLOGS}.log as logfile, with unique output ..." 
				nohup sh ${STARTAPP} > ${APLOGS}.log 2>&1 &
			else
				log_action "INFO" "Executing ${STARTAPP} with ${APLOGS}.log as logfile, with separate log ..."
				nohup sh ${STARTAPP} 2> ${APLOGS}.err > ${APLOGS}.log &
			fi
			date '+%Y%m%d-%H%M' > "${APLOGS}.date"
			# summary en lock para un post-analisis
			echo "${OPTIONS}" > "${APLOGS}.lock"
			echo "\nDate:\n`date '+%Y%m%d %H:%M'`" >> "${APLOGS}.lock"
		fi

		#
		# a trabajar ... !
		LASTSTATUS=1
		ONSTOP=1
		INWAIT=true
		LASTLINE=""
		LINE="`tail -n1 ${APLOGS}.log`"
		while ($INWAIT)
		do
			filter_in_log "${UPSTRING}"
			LASTSTATUS=$?
			[ "${LASTSTATUS}" -eq "0" ] && INWAIT=false;
			if [ "${LINE}" != "${LASTLINE}" ]
			then 
				${VIEWLOG} && echo "${LINE}" 
				LINE="$LASTLINE"
			fi
			sleep 2
			ONSTOP="$(($ONSTOP+1))"
			[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false;
			LASTLINE="`tail -n1 ${APLOGS}.log`"
		done
		
		# buscar los PID's
		get_process_id
		echo "\nPID:\n`cat ${APLOGS}.pid`" >> "${APLOGS}.lock"
		# le avisamos a los admins 
		[ "${LASTSTATUS}" -ne "0" ] && DEBUG=true
		report_status "STARTUP" "${LASTSTATUS}"
		# CASO ESPECIAL
		# SI LA APLPICACION CORRE UNA SOLA VEZ, ELIMINAR EL .lock
		[ $APPTYPE = "RUNONCE" ] && rm -f "${APLOGS}.lock"
		[ $APPTYPE = "RUNONCE" ] && log_backup
	fi
	

	#
	# STOP -- Detener la aplicación sea por instrucción o deteniendo el proceso, indicado en el archivo de configuración
	if ${STOP} 
	then
		#
		# que sucede si intentan dar de baja el proceso nuevamente
		# verificamos que exista un bloqueo (DoP) y PID
		log_action "INFO" "Stopping the application, please wait ..."
		TOSLEEP="$(($TOSLEEP/2))"
		is_process_running
		if [ `wc -l "${APLOGS}.pid" | cut -f1 -d\ ` -le 0 ]
		then
			echo "uh, ${NAMEAPP} is not running currently, tip: starter --report"
			log_action "INFO" "The application is down"
			exit 0
		fi
		
		#
		# verificar que la aplicación para hacer shutdown se encuentre en el dir 
		# checar en 10 ocasiones hasta que el servicio se encuentre abajo 
		LASTSTATUS=1
		STRSTATUS="FORCED SHUTDOWN"
		[ ${STOPAPP} = "_NULL_" ] && NOTFORCE=false

		#
		# si es necesario que el stop sea forzado
		if ${NOTFORCE}
		then
			# 
			if [ -r ${STOPAPP} ]
			then
				STRSTATUS="NORMAL SHUTDOWN"
				sh ${STOPAPP} >> ${APLOGS}.log 2>&1 &
				log_action "INFO" "Shutdown application, please wait..."
			fi
				 
			#
			# a trabajar ... !
			LASTSTATUS=1
			ONSTOP=1
			INWAIT=true
			LASTLINE=""
			LINE="`tail -n1 ${APLOGS}.log`"
			INWAIT=true
			while ($INWAIT)
			do
				filter_in_log "${DOWNSTRING}"
				is_process_running
				LASTSTATUS=$?
				[ "${LASTSTATUS}" -eq "0" ] && INWAIT=false
				if [ "${LINE}" != "${LASTLINE}" ]
				then 
					${VIEWLOG} && echo "${LINE}" 
					LINE="$LASTLINE"
				fi
				
				# tiempo a esperar para refrescar out en la pantalla
				sleep 2
				
				ONSTOP="$((${ONSTOP}+1))"
				log_action "DBUG" "uhmmm, OnStop = ${ONSTOP} vs ToSleep = ${TOSLEEP}"
				if [ ${ONSTOP} -gt ${TOSLEEP} ]
				then 
					INWAIT=false
					log_action "WARN" "We have a problem Houston, the app stills remains in memory !"
				fi
				LASTLINE="`tail -n1 ${APLOGS}.log`"
			done
		fi

		#
		# si no se cancelo el proceso por la buena, entonces pasamos a la mala
		if [ "${LASTSTATUS}" -ne "0" ]
		then
			# si el stop es con FORCED, y es una aplicacion JAVA enviar FTD
			if [ ${FILTERLANG} = "java" -a ${THREADDUMP} = true ]
			then
				# starter -a=app stop -f -t=3,10
				# se aplica un fullthreaddump de 3 muestras cada 10 segundos antes de detener el proceso de manera forzada. 
				log_action "INFO" "before kill the baby, we send 3 FTD's between 8 secs"
				~/bin/starter --application=${APPLICATION} --threaddump=${MAXSAMPLES},${MAXSLEEP}
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
				is_process_running
				awk '{print "kill -9 "$0}' "${APLOGS}.pid" | sh
				sleep 2
				${VIEWLOG} && tail -n10 "${APLOGS}.log"
				
				# checar si existen los PID's, por si el archivo no regresa el shutdown
				is_process_running
				LASTSTATUS=$?
				[ "${LASTSTATUS}" -eq "0" ] && break
				ONSTOP="$(($ONSTOP+1))"
				[ $ONSTOP -ge $TOSLEEP ] && INWAIT=false
				done
				STRSTATUS="KILLED"
			fi
			
			#
			# le avisamos a los admins 
			[ "${LASTSTATUS}" -ne "0" ] && DEBUG=true
			report_status "${STRSTATUS}" "${LASTSTATUS}"
		fi

		#
		# hacer un full thread dump a un proceso X
		if ${THREADDUMP}
		then
			make_fullthreaddump
		fi

		#
		# Verificar el status de la aplicación
		if ${STATUS} 
		then
			if [ ${APPLICATION} = "NONSETUP" ]
			then
				# si no se da el parametro --application, se busca en el starter los .conf y se consulta su estado
				ls -l ${APHOME}/setup/*-starter.conf > /dev/null 2>&1
				[ "$?" != "0" ] && echo "Cannot access any config file! " && exit 1
				for app in ${APHOME}/setup/*-starter.conf
				do
					app=`basename ${app%-starter.*}`
					echo "Checking $app using [ ~/bin/starter --application=$app --status ] " 
					~/bin/starter --application=$app --status 
				done
			else
				# si se da el parametro de --application, procede sobre esa aplicacion 
				show_status
				LASTSTATUS=$?
				
				#
				# si no se solicita el --mailreport
				if [ "${MAILACCOUNTS}" = "_NULL_" ]
				then
					${VIEWLOG} && cat ${REPORT}
				else
					echo "`date`" >> ${REPORT}
					$apmail -s "${APPLICATION} STATUS " "${MAILACCOUNTS}" < ${REPORT} > /dev/null 2>&1 &
					log_action "INFO" "Sending report by mail of STATUS to ${MAILACCOUNTS}"
				fi
				log_action "INFO" "Show the application status information"
				rm -f ${REPORT}
			fi
		fi

		#
		# Generar un reporte de aplicaciones ejecutandose
		#
		# PULGOSA
		#
		# SERVER				| EXECUTED			| PID	 | STATS | FILESYSTEM											
		# --------------+---------------+-------+-------+---------------------------
		# test					| 20080924-0046 |			 | DOWN	| 0/ 21520/ 65575 Mb							
		# ...
		if ${VIEWREPORT} 
		then
			apphost=`hostname | tr "[:lower:]" "[:upper:]"`
			appipmc=`echo $SSH_CONNECTION | cut -f3 -d" "`
			appuser=`id -u -n`
			ls -l ${APHOME}/setup/*-starter.conf > /dev/null 2>&1
			[ $? != "0" ] && echo "Cannot access any config file! " && exit 1
			echo "\n"
			echo "${apphost}"
			echo "${appipmc}"
			echo "SERVER:EXECUTED:PID:STATS" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print substr($1"														 ",1,20),
											substr($2"							",1,14),
											substr($3"							",1,6),
											substr($4"							",1,6)
							}'
			echo "--------------------+---------------+-------+-------"
			
			~/bin/starter --status > /dev/null 2>&1
			for app in ${APHOME}/setup/*-starter.conf
			do
				appname=`basename ${app%-starter.*}`
				apppath=`awk 'BEGIN{FS="="} /^PATHAPP/{print $2}' ${app}`
				# verificar que exista el PID del usuario
				touch "${DIRLOG}/${appname}.pid"
				touch "${DIRLOG}/${appname}.date"
				# si el PID file existe y es mayor a 0, entonces es un proceso valido
				pidsize=`du -s "${DIRLOG}/${appname}.pid" | cut -f1`
				appdate=`cat "${DIRLOG}/${appname}.date"`
				apppidn=`cat "${DIRLOG}/${appname}.pid"`
				[ ${pidsize} -ne "0" ] && appstat="UP" || appstat="DOWN"
				appsize="0"
				appfsiz="0"
				
				echo "${appname}:${appdate}:${apppidn}:${appstat}" | 
					awk 'BEGIN{FS=":";OFS="| "}
							{
								print substr($1"															 ",1,20),
											substr($2"							",1,14),
											substr($3"							",1,6),
											substr($4"							",1,6)
							}'
			done
			echo ""
		fi

		#
		# Generar un reporte de aplicaciones historico de operaciones realizadas
		#
		# PULGOSA
		#
		# DATE		 | STOP	| START | SERVER						 | BACKUP
		# ---------+-------+-------+--------------------+---------------------------
		# 20080924 | 0046	| 0120	| test							 | test_20080924_0120.tar.gz
		# ...
		if ${VIEWHISTORY} 
		then
			apphost=`hostname | tr "[:lower:]" "[:upper:]"`
			appipmc=`echo $SSH_CONNECTION | cut -f3 -d" "`
			appuser=`id -u -n`
			# checando el estado de las aplicaciones
			~/bin/starter --status > /dev/null 2>&1
			echo "\n"
			echo "${apphost}"
			echo "${appipmc}"
			echo "STOP:START:SERVER" | 
				awk 'BEGIN{FS=":";OFS="| "}
							{
								print substr($1"										 ",1,18),
											substr($2"										 ",1,18),
											substr($3"										 ",1,7);
							}'
			echo "------------------+-------------------------------------------------"
			tail -n600 ${APLOGS}.log |	tr -d ":[]()-" | \
						awk 'BEGIN{LAST="";OFS="| "}
									/SUCCESS/{
									if($0~"STARTUP")
									{
										LDATE=$1;
										LTIME=$2;
									}
									else
									{
										print substr(LDATE"									",1,9),
													substr(LTIME"									",1,7),
													substr($1"								",1,9),
													substr($2"								",1,7),
													substr($3"									",1,14);
									}
						}' > ${DIRLOG}/starter.history
			
			if [ "${APPLICATION}" = "NONSETUP" ]
			then
				cat ${DIRLOG}/starter.history | uniq | sort -r	| head -n60
			else
				cat ${DIRLOG}/starter.history | uniq | sort -r	| head -n60 | grep "${APPLICATION} "
			fi
			echo ""
		fi

		# ejecutar el mantenimiento
		# eliminar archivos de log que sean mayores a 4 dias
		# find . -name '${nameapp}*.tar.gz' -mtime +4 -type f -exec 
		if ${MAINTENANCE}
		then 
			# mantenimiento de logs principal
			cd ${DIRLOG}
			log_action "WARN" "Executing maintenance of application logs..."
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
			#for mplugin in starter/*-maintenance.plug
			#do
			#	 sh ${mplugin}
			#done
		fi

		#
		# Depurar la aplicación
		if ${DEBUG} 
		then
			touch ${APLOGS}.log
			touch ${APLOGS}.err
			touch ${APLOGS}.pid
			touch ${APLOGS}.date
			FLDEBUG="${APLOGS}.debug"
			echo "\n\n">> ${FLDEBUG}
			echo "DEBUG" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}
			echo "	" >> ${FLDEBUG}
			echo "GENERAL INFORMATION" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}
			echo "`date`\n" >> ${FLDEBUG}
			show_version	>> ${FLDEBUG} 2>&1
			echo "HOSTNAME `hostname`" >> ${FLDEBUG}
			echo "	" >> ${FLDEBUG}
			echo "USER `id -u -n`" >> ${FLDEBUG}
			echo "	" >> ${FLDEBUG}
			echo "CONFIGURATION" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			~/bin/starter --application=${APPLICATION} --check-config >> ${FLDEBUG}
			echo "	" >> ${FLDEBUG}
			echo "${APLOGS}.date" >> ${FLDEBUG}
			cat ${APLOGS}.date >> ${FLDEBUG} 2>&1
			echo "	" >> ${FLDEBUG}
			echo "${APLOGS}.pid" >> ${FLDEBUG}
			cat ${APLOGS}.pid >> ${FLDEBUG} 2>&1
			echo "	" >> ${FLDEBUG}
			echo "Processes" >> ${FLDEBUG}
			is_process_running
			PROCESSES=$?
			if [ "${PROCESSES}" -ne "0" ]
			then
				echo "${APPLICATION} is running with ${PROCESSES} processes" >> ${FLDEBUG} 2>&1
				if [ "`uname -s`" = "HP-UX" ]
				then
					awk '{print "ps -fex | grep "$0}' "${APLOGS}.pid" | sh | grep "$FILTERLANG" | grep "$FILTERAPP" >> ${FLDEBUG} 2>&1
				else
					awk '{print "ps fea | grep "$0}' "${APLOGS}.pid" | sh | grep "$FILTERLANG" | grep "$FILTERAPP" >> ${FLDEBUG} 2>&1
				fi
			else
				echo "${APPLICATION} is not running." >> ${FLDEBUG} 2>&1
			fi
			echo "	" >> ${FLDEBUG}
			echo "FileSystem" >> ${FLDEBUG}
			$bdf >> ${FLDEBUG} 2>&1
			echo "	" >> ${FLDEBUG}
			echo "FILE LOG" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}			
			tail -n500 ${APLOGS}.log >> ${FLDEBUG} 2>&1
			echo "	" >> ${FLDEBUG}
			echo "-------------------------------------------------------------------------------" >> ${FLDEBUG}
		 
			#
			# si no se solicita el --mailreport
			if [ "${MAILACCOUNTS}" = "_NULL_" ]
			then
				cat ${FLDEBUG}
			else
				$apmail -s "${APPLICATION} DEBUG INFO " "${MAILACCOUNTS}" < ${FLDEBUG} > /dev/null 2>&1 &
				log_action "INFO" "Send information from debug application to ${MAILACCOUNTS}"
			fi
			log_action "INFO" "Show the application debug information"
	 fi
	 
	 ${STOP} && log_backup;
	 exit ${LASTSTATUS}
fi

