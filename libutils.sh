#!/bin/sh 
# vim: set ts=3 sw=3 sts=3 et si ai: 

# lib-utils.sh -- library with some util functions
# ---------------------------------------------------------------------------- 
# (c) 2009 Nextel de México S.A. de C.V.
# Andrés Aquino Morales <andres.aquino@gmail.com>
# All rights reserved.
# 

#
# constants
# initialize app enviroment
systemSO="`uname -s`"
apHost=`hostname `
apUser=`id -u -n`
apDate=`date "+%Y%m%d"`
apHour=`date "+%H%M"`


#
# get the enviroment for the SO running
get_enviroment () {
   # terminal line settings
   stty 2> /dev/null > /dev/null 
   if [ "$?" = "0" ]
   then
	   stty erase '^?'
	   stty intr '^C' 
	   stty kill '^U' 
	   stty stop '^S'
	   stty susp '^Z'
	   stty werase '^W'
	   
	   # command line _eye candy_
	   CCLEAR="\033[00m"; CWHITE="\033[01;37m"
	   CRED="\033[01;31m"; CYELLOW="\033[01;33m"
	   CBLUE="\033[01;34m"; CGRAY="\033[01;30m"
      appProfile=true

   else
	   # command line _eye candy_
	   CCLEAR=""; CWHITE=""
	   CRED=""; CYELLOW=""
	   CBLUE=""; CGRAY=""
      appProfile=false

   fi

   # nombre de la aplicacion
   if [ -z "${APPNAME}" ]
   then
      APPNAME="`basename ${0}`"
      APPNAME="${APPNAME%.*}"
   fi

   # path de la aplicacion
   if [ -z "${APPPATH}" ]
   then
      APPPATH="`dirname ${0}`"
      [ "${APPPATH}" = "." ] && APPPATH="`pwd`"
   fi
   
   # nombre del proceso
   if [ -z "${PROCNAME}" ]
   then
      PROCNAME="${APPNAME}"
   fi

   # path de los archivos del proceso
   if [ -z "${PROCPATH}" ]
   then
      PROCPATH="${APPPATH}"
   fi
   
   case "${systemSO}" in
      "HP-UX")
         PSOPTS="-l -f -a -x -e"
         PSPOS=1
         DFOPTS="-P -k"
         MKOPTS="-d /tmp -p "
         ;;
         
      "Linux")
         PSOPTS="lfaex"
         PSPOS=0
         DFOPTS="-Pk"
         MKOPTS="-t "
         ;;
         
      "Solaris")
         PSOPTS="fax"
         PSPOS=0
         DFOPTS="-P -k"
         MKOPTS="-t "
         ;;
         
      *)
         PSOPTS="-l"
         PSPOS=0
         ;;
   esac
   #log_action "NOTICE" "Iniciando ${PROCNAME}, ${systemSO}"
   log_action "NOTICE" "starting ${PROCNAME}, ${systemSO}"

}


#
# get the process ID of an app
#  FILTER = strings to look for in process list (ej. java | rmi;java | iplanet,cci)
#  PROCID = IDname for process (ej. iplanets)
get_process_id () {
   #
   local FILTER="${1}"
   local PROCID="${2}"
   local PSLIST="`mktemp ${MKOPTS} ${PROCNAME}.XXXXX`"
   local WRDSLIST=`echo "${FILTER}" | sed -e "s/\///g;s/,/\/\&\&\//g;s/;/\/\|\|\//g"` 

   # verificar si se cuenta con una ruta para almacenar los pid's
   if [ -n "${PROCESSNAME}" ]
   then
      PROCESSNAME="utils"
   fi  
   mkdir -p /tmp/${PROCESSNAME}
   PROCID="/tmp/${PROCESSNAME}/${APPNAME}"

   # extraer procesos existentes y filtrar las cadenas del archivo de configuracion
   #log_action "NOTICE" "Buscando procesos ${WRDSLIST} propiedad de ${apUser}"
   log_action "NOTICE" "looking for process ${WRDSLIST} owned by ${apUser}"
   ps ${PSOPTS} | grep ${apUser} > ${PSLIST}.1
   
   # extraer los procesos que nos interesan 
   awk "/${WRDSLIST}/{print}" ${PSLIST}.1 > ${PSLIST}
   
   # el archivo existe y es mayor a 0 bytes 
   if [ -s ${PSLIST} ]
   then      
      # extraer los procesos y reordenarlos
      sort -n -k8 ${PSLIST} > ${PROCID}.pall
      
      # extraer los pid de los procesos implicados 
      awk -v P=${PSPOS} '{print $(3+P)}' ${PROCID}.pall > ${PROCID}.pid
      
      # reodernar los PPID para dejar el proceso raiz al final
      awk -v P=${PSPOS} '{print $(4+P)}' ${PROCID}.pall | sort -rn | uniq > ${PROCID}.ppid

      # registrar evento
      #log_action "NOTICE" "El proceso ${PROCNAME} se encuentra en memoria"
      log_action "NOTICE" "the ${PROCNAME} process is executing"
   else
      # eliminar archivos ppid, en caso de que el proceso ya no exista
      #log_action "WARN" "No existe ese proceso en memoria"
      log_action "WARN" "the ${PROCNAME} process is not executing"
      rm -f ${PROCID}.{pall,pid,ppid}
   fi
   rm -f ${PSLIST}
   rm -f ${PSLIST}.1

}


#
# verify the PID's for a specific process
processes_running () {
   #
   local COUNT=0
   local EACH=""
   local PROCID="${1}"

   # verificar si se cuenta con una ruta para almacenar los pid's
   if [ -n "${PROCESSNAME}" ]
   then
      PROCESSNAME="utils"
   fi  
   mkdir -p /tmp/${PROCESSNAME}
   PROCID="/tmp/${PROCESSNAME}/${APPNAME}"

   # si no existe el archivo de .pid, reportarlo y terminar
   if [ ! -s "${PROCID}.pid" ]
   then
      #log_action "ERR" "No existen procesos ${PROCNAME} activos"
      log_action "ERR" "the ${PROCNAME} process is not executing"
      return 1
   else
      for EACH in $(cat "${PROCID}.pid")
      do
         # cuantos son propiedad del usuario y estan activos
         kill -0 ${EACH} > /dev/null 2>&1
         [ $? -eq 0 ] && COUNT=$((${COUNT}+1))
         wait_for "Revisando procesos existentes" 1
      done
      #log_action "INFO" "Existen ${COUNT} procesos ${PROCNAME} activos"
      log_action "INFO" "the ${PROCNAME} process has ${COUNT} instances"
      return 0
   fi

}


#
# event log
log_action () {
   local LEVEL="${1}"
   local ACTION="${2}"
   local APPLOG="${APPPATH}/${APPNAME}"

   # verificar si se cuenta con una ruta para almacenar los pid's
   if [ -n "${PROCESSNAME}" ]
   then
      PROCESSNAME="utils"
   fi
   mkdir -p /tmp/${PROCESSNAME}
   PROCID="/tmp/${PROCESSNAME}/${APPNAME}"

   # filelog y process id
   local MTIME="`date '+%H:%M:%S'`"
   local MDATE="`date '+%Y-%m-%d'`"
   local PID="$$"
   # verificar que existe (mayor a 0 bytes) y ademas se cuenta con el process id
   if [ -s "${PROCID}.pid" ] 
   then 
      PID=`head -n1 ${PROCID}.pid`
   fi
     
   # severity level: http://www.aboutdebian.com/syslog.htm
   # do you need make something for whatever level on your app ? 
      case "${LEVEL}" in
         "EMERG")
            ;;

         "ALERT")
            ;;

         "CRIT")
            ;;

         "ERR")
            report_status "ER" "${ACTION}"
            ;;

         "WARN")
            ;;

         "NOTICE")
            ;;

         "DEBUG")
            ;;

         "INFO")
            report_status "OK" "${ACTION}"
            ;;
      esac 
   echo "${MDATE} ${MTIME} ${apHost} ${PROCNAME}[${PID}]: (${LEVEL}) ${ACTION}" >> ${APPLOG}.log

}


#
# show status of app execution
report_status () {
   local STATUS="${1}"
   local MESSAGE="${2}"
   
   # cadena para indicar proceso correcto o con error
   if [ "${STATUS}" = "OK" ]
   then 
      STATUS="OK"
   else
      STATUS="ER"
   fi

   # si no es proceso con terminal
   if ! ${appProfile}
   then 
      echo "${MESSAGE} ..." | awk -v STATUS=${STATUS} '{print substr($0"                                                                           ",1,70),STATUS}'
   else
      echo "${MESSAGE} ... "
      tput sc 
      tput cuu1 && tput cuf 70
      if [ "${STATUS}" = "OK" -o "$STATUS" = "*" ]
      then
         echo "${CCLEAR}[${CGREEN} ${STATUS} ${CCLEAR}]"
      else
         echo "${CCLEAR}[${CRED} ${STATUS} ${CCLEAR}]"
      fi
   fi
}


#
# filter_in_log
filter_in_log () {
   local FILTER="${1}"
   local PROCID="${2}"
   local WRDSLIST=`echo "${FILTER}" | sed -e "s/\///g;s/,/\/\&\&\//g;s/;/\/\|\|\//g"` 
   local APPLOG="${APPPATH}/${APPNAME}"

   # verificar si se cuenta con una ruta para almacenar los pid's
   if [ -n "${PROCESSNAME}" ]
   then
      PROCESSNAME="utils"
   fi  
   mkdir -p /tmp/${PROCESSNAME}
   PROCID="/tmp/${PROCESSNAME}/${APPNAME}"

   # la long de la cad no esta vacia
   if [ -n "${SEARCHSTR}" ]
   then
      # extraer los procesos que nos interesan 
      awk "/${WRDSLIST}/{print}" ${PROCID}
 
      LASTSTATUS=1
   else
      awk 
      grep -q "${SEARCHSTR}" "${PROCLOG}"
      LASTSTATUS=$?
      [ "${LASTSTATUS}" -eq 0 ] && log_action "DEBUG" "Looking for ${SEARCHSTR} was succesfull"
   fi   
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
   
   if ! ${appProfile}
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
#   wait_for "STANDBY"
#   # como el usleep no funciona con milliseconds, usamos un perlliner
#   perl -e 'select(undef,undef,undef,.3)'
#done

#
