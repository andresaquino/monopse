#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai: 

# libutils.sh -- library with some util functions
# =-=
# (c) 2009 StrategyLabs!
# Andrés Aquino Morales <andres.aquino@gmail.com>
# 

#
# constants
# initialize app enviroment
APSYSO="`uname -s`"
APHOST=`hostname `
APUSER=`id -u -n`
APDATE=`date "+%Y%m%d"`
APHOUR=`date "+%H%M"`
APLEVL="NOTICE"

# globals
APNAME=
APPATH=
APLOGD=
APLOGS=
APLOGP=
APPRCS=
APTEMP=
APFLTR=

#
# get the enviroment for the SO running
set_environment () {
	# terminal line settings
	stty erase '^?'
	stty intr '^C' 
	stty kill '^U' 
	stty stop '^S'
	stty susp '^Z'
	stty werase '^W'
	stty 2> /dev/null > /dev/null 

	if [ "$?" = "0" ]
	then
		# command line _eye candy_
		CCLEAR="\033[00m"
		CWHITE="\033[01;37m"
		CRED="\033[01;31m"
		CGREEN="\033[01;32m"
		CYELLOW="\033[01;33m"
		CBLUE="\033[01;34m"
		CGRAY="\033[01;30m"
	else
		# command line _eye candy_
		CCLEAR=
		CWHITE=
		CRED=
		CGREEN=
		CYELLOW=
		CBLUE=
		CGRAY=
	fi
	
	# application's structure
	# [monopse]
	# /opt/usrapp/monopse

	# applications's name
	if [ -z "${APNAME}" ]
	then
		APNAME="`basename ${0}`"
		APNAME="${APNAME%.*}"
	fi

	# application's path
	if [ -z "${APPATH}" ]
	then
		APPATH=${HOME}/${APNAME}
	fi
	[ ! -d ${APPATH} ] && mkdir -p ${APPATH}

	# log's path
	if [ -z "${APLOGD}" ]
	then
		APLOGD=${APPATH}/logs
		log_action "DEBUG" "APLOGD unset, using default values: ${APLOGD}"
	fi
	APLOGS=${APLOGD}/${APNAME}
	[ ! -d ${APLOGD} ] && mkdir -p ${APLOGD}

	# temporal's path
	if [ -z "${APTEMP}" ]
	then
		APTEMP=${APLOGD}/temp
		log_action "DEBUG" "APTEMP unset, using default values: ${APTEMP}"
	fi
	[ ! -d ${APTEMP} ] && mkdir -p ${APTEMP}

	APLOGP=${APTEMP}/${APNAME}
	
	case "${APSYSO}" in
		"HP-UX")
			PSOPTS="-l -f -a -x -e"
			PSPOS=1
			DFOPTS="-P -k"
			MKOPTS="-d /tmp -p "
			APUSER=`id -u -n`
		;;
			
		"Linux")
			PSOPTS="lax"
			PSPOS=0
			DFOPTS="-Pk"
			MKOPTS="-t "
			APUSER=`id -u `
			;;
		
		"Darwin")
			PSOPTS="-leax"
			PSPOS=-1
			DFOPTS="-P -k"
			MKOPTS="-t "
			APUSER=`id -u `
		;;
			
		*)
			PSOPTS="-l"
			PSPOS=0
		;;
	esac
	log_action "DEBUG" "starting ${APNAME}, using a ${APSYSO} Platform System"
}


#
# set Application's Name
set_name () {
	local AP_NAME=${1}
	local AP_PATH=${2}

	APNAME=${AP_NAME}
	APPATH=${AP_PATH}
	[ ! -d ${APPATH} ] && mkdir -p ${APPATH}
	
	APLOGD=${APPATH}/logs
	APLOGS=${APLOGD}/${APNAME}
	[ ! -d ${APLOGD} ] && mkdir -p ${APLOGD}

	APTEMP=${APLOGD}/temp
	[ ! -d ${APTEMP} ] && mkdir -p ${APTEMP}

	APLOGP=${APTEMP}/${APPRCS}
	
}


#
# set log
set_log () {
	local AP_LOGD=${1}

	# log's path
	[ -d ${APLOGD} ] && echo "del ${APLOGD}"
	APLOGD=${AP_LOGD}
	APLOGS=${APLOGD}/${APNAME}
	[ ! -d ${APLOGD} ] && mkdir -p ${APLOGD}

	[ -d ${APTEMP} ] && echo "del ${APTEMP}"
	APTEMP=${APLOGD}/temp
	[ ! -d ${APTEMP} ] && mkdir -p ${APTEMP}

}


#
# set processes
set_proc () {
	local AP_PROC=${1}

	# process name
	APPRCS=${AP_PROC}
	APLOGP=${APLOGD}/${APPRCS}
	APLOGT=${APTEMP}/${APPRCS}

}

#
# get the process ID of an app
#  FILTER = strings to look for in process list (ej. java | rmi;java | iplanet,cci)
#  PROCID = IDname for process (ej. iplanets)
get_process_id () {
	#
	local FILTER="${1}"
	
	[ ${#FILTER} -ne 0 ] && APFLTR=${FILTER}
	PIDFILE=${APLOGT}
	WRDSLIST=`echo "${APUSER},${APFLTR}" | sed -e "s/\///g;s/,/\/\&\&\//g;s/;/\/\|\|\//g"` 
	# extraer procesos existentes y filtrar las cadenas del archivo de configuracion
	ps ${PSOPTS} > ${PIDFILE}.allps
	log_action "DEBUG" "Using ${PIDFILE}.{pid,ppid,ps}"
	
	# extraer los procesos que nos interesan 
	awk "/${WRDSLIST}/{print}" ${PIDFILE}.allps > ${PIDFILE}.ps
	log_action "DEBUG" "looking for process using /${WRDSLIST}/ owned by ${APUSER}"
	
	# el archivo existe y es mayor a 0 bytes 
	if [ -s ${PIDFILE}.ps ]
	then
		# extraer los procesos y reordenarlos
		sort -n -k8 ${PIDFILE}.ps > ${PIDFILE}.pss
		log_action "DEBUG" "hey, we have one ${APPRCS} process alive!"
		
		# extraer los pid de los procesos implicados 
		awk -v P=${PSPOS} '{print $(3+P)}' ${PIDFILE}.pss > ${PIDFILE}.pid
		
		# reodernar los PPID para dejar el proceso raiz al final
		awk -v P=${PSPOS} '{print $(4+P)}' ${PIDFILE}.pss | sort -rn | uniq > ${PIDFILE}.ppid

	else
		# eliminar archivos ppid, en caso de que el proceso ya no exista
		log_action "DEBUG" "hey, ${APPRCS} is not running.."
		rm -f ${PIDFILE}.{pid,ppid}
	fi
	rm -f ${PIDFILE}.{pss,allps}
}


#
# verify the PID's for a specific process
processes_running () {
	local COUNT=0
	local EACH=""

	get_process_id
	PIDFILE=${APLOGT}
	# si no existe el archivo de .pid, reportarlo y terminar
	if [ ! -s "${PIDFILE}.pid" ]
	then
		log_action "DEBUG" "process${PROCID} is not running"
		return 0
	else
		for EACH in $(cat "${PIDFILE}.pid")
		do
			# cuantos son propiedad del usuario y estan activos
			kill -0 ${EACH} > /dev/null 2>&1
			[ $? -eq 0 ] && COUNT=$((${COUNT}+1))
			log_action "DEBUG" "checking, process ${EACH} is running"
		done
		log_action "DEBUG" "${PIDFILE}.pid report ${COUNT} instances"
		return ${COUNT}
	fi

}


#
# event log
log_action () {
	local LEVEL="${1}"
	local ACTION="${2}"
	
	# filelog y process id
	local TIME="`date '+%H:%M:%S'`"
	local DATE="`date '+%Y-%m-%d'`"
	local PID="$$"
	# verificar que existe (mayor a 0 bytes) y ademas se cuenta con el process id
	if [ -s "${APLOGS}.pid" ] 
	then 
		PID=`head -n1 ${APLOGP}.pid`
	fi
	  
	# severity level: http://www.aboutdebian.com/syslog.htm
	# do you need make something for whatever level on your app ? 
	LOGTHIS=false
	case "${LEVEL}" in
		"ALERT")
			LOGTHIS=true
		;;
		"EMERG"|"CRIT"|"ERR")
			LOGTHIS=true
		;;
		"WARN")
			[ ${APLEVL} = "WARN" ] && LOGTHIS=true
			[ ${APLEVL} = "NOTICE" ] && LOGTHIS=true
		;;
		"NOTICE")
			[ ${APLEVL} = "NOTICE" ] && LOGTHIS=true
			[ ${APLEVL} = "DEBUG" ] && LOGTHIS=true
		;;
		"DEBUG")
			[ ${APLEVL} = "DEBUG" ] && LOGTHIS=true
		;;
		"INFO")
			[ ${APLEVL} = "INFO" ] && LOGTHIS=true
			[ ${APLEVL} = "NOTICE" ] && LOGTHIS=true
			[ ${APLEVL} = "DEBUG" ] && LOGTHIS=true
		;;
	esac 
	
	if ${LOGTHIS}
	then
		if [ ${#APLOGS} -ne 0 ]
		then
			echo "${DATE} ${TIME} ${APHOST} ${PRNAME}[${PID}]: (${LEVEL}) ${ACTION}" >> ${APLOGS}.log
		else
			echo "${DATE} ${TIME} ${APHOST} ${PRNAME}[${PID}]: (${LEVEL}) ${ACTION}" 
		fi
	fi
}


#
# show status of app execution
report_status () {
	local STATUS="${1}"
	local MESSAGE="${2}"
	
	# cadena para indicar proceso correcto o con error
	if [ -z "${CBLUE}" ]
	then 
		echo " ${MESSAGE} ..." | awk -v STATUS=${STATUS} '{print substr($0"                                                                                        ",1,70),STATUS}'
	else
		echo " ${MESSAGE} ... "
		tput sc 
		tput cuu1 && tput cuf 70
		case "${STATUS}" in
			"*")
				echo "${CCLEAR}[${CGREEN} ${STATUS} ${CCLEAR}]"
			;;
			"?")
				echo "${CCLEAR}[${CRED} ${STATUS} ${CCLEAR}]"
			;;
			"i")
				echo "${CCLEAR}[${CYELLOW} ${STATUS} ${CCLEAR}]"
			;;
		esac
	fi
}


#
# filter_in_log
filter_in_log () {
	local FILTER="${1}"
	local WRDSLIST=`echo "${FILTER}" | sed -e "s/\///g;s/,/\/\&\&\//g;s/;/\/\|\|\//g"` 

	# la long de la cad no esta vacia
	[ -z "${FILTER}" ] && return 1
	
	# extraer los procesos que nos interesan 
	awk "/${WRDSLIST}/{print}" ${APLOGP}.log
	LASTSTATUS=$?
	[ "${LASTSTATUS}" -eq 0 ] && \
		log_action "DEBUG" "looking for /${FILTER}/ was succesfull" || \
		log_action "DEBUG" "looking for /${FILTER}/ was failed"

	return ${LASTSTATUS}
}


#
# waiting process indicator
wait_for () {
	local WAITSTR="- \ | / "
	local STATUS="${1}"
	local TIMETO=0
	local GOON=true
	local WAITCHAR="-"
	
	if [ ! -z "${CBLUE}" ] 
	then
		TIMETO=${2}
		echo "${STATUS}"
		while(${GOON})
		do
			sleep 1
			TIMETO=$((${TIMETO}-1))
			[ ${TIMETO} -eq 0 ] && GOON=false
		done
	else
		if [ "${STATUS}" != "CLEAR" ]
		then
			TIMETO=$((${2}*5))
			echo "${STATUS}"
			tput sc
			CHARPOS=1
			while(${GOON})
			do
				WAITCHAR=`echo ${WAITSTR} | cut -d" " -f${CHARPOS}`
				# recuperar la posicion en pantalla, ubicar en la columna 70 y subirse un renglon 
				tput rc
				tput cuu1 && tput cuf 70 
				echo "${CCLEAR}[${CYELLOW} ${WAITCHAR} ${CCLEAR}]"
				# incrementar posicion, si es igual a 5 regresar al primer caracter 
				CHARPOS=$((${CHARPOS}+1))
				[ ${CHARPOS} -eq 5 ] && CHARPOS=1
				perl -e 'select(undef,undef,undef,.1)'
				TIMETO=$((${TIMETO}-1))
				[ ${TIMETO} -eq 0 ] && GOON=false
			done
		fi
		# limpiar linea de mensajes
		tput rc 
		tput cuu1
		tput el
	fi
}


# TEST

# --
# [ok] test para verificar el log y la busqueda de cadenas
#. test.mconf
#get_enviroment
#log_action "INFO" "Verificar el estado de los pid's"

# --
# [ok] test para verificar procesos
#get_enviroment
#get_process_id "gvfs,spaw;gnome" 

#
# [] test para verificar los procesos asociados a un .pid
#get_enviroment
#processes_running "gvfs"
#wait_for "CLEAR"

# [ok] test para mostrar procesos
#get_enviroment
#report_status "OK" "Reinicio WebLogic 9.2 "
#report_status "ERR" "Reinicio WebLogic 9.2 "

# [ok] test para mostrar indicador de espera
#get_enviroment
#wait_for "Revisando el log de servicios " 5
#wait_for "CLEAR"
#while (true)
#do
#	wait_for "STANDBY"
#	# como el usleep no funciona con milliseconds, usamos un perlliner
#	perl -e 'select(undef,undef,undef,.3)'
#done

#
