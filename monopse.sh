#!/bin/sh 
# vim: set ts=2 sw=2 sts=2 si ai et: 

# monopse.sh - An small shell for those applications that nobody wants to restart ;)
# =-=
# Developer
# Andres Aquino Morales <andres.aquino@gmail.com>
# 

#
# set minimal environment
APNAME="monopse"
APHOME=${HOME}
APPATH=${APHOME}/${APNAME}
APLOGD=${APPATH}/logs
APTEMP=${APLOGD}/temp
APLEVL="DEBUG"
APLOGS=
VIEWLOG=false
VIEWMLOG=false

# user environment
. ${APHOME}/.${APNAME}rc

# load user functions
. ${APPATH}/libutils.sh
set_environment

## MAIN ##
##
# corroborar que no se ejecute como usuario r00t
if [ "`id -u`" -eq "0" ]
then
   if [ "${MAILACCOUNTS}" = "_NULL_" ]
   then
      printto  "Hey, i can't run as root user "
   else
      ${MAIL} -s "Somebody tried to run me as r00t user" "${MAILACCOUNTS}" < "$@" > /dev/null 2>&1 &
      log_action "WARN" "Somebod tried to run me as r00t, sending warn to ${MAILACCOUNTS}"
   fi
   
fi

# set complete application's environment
TOSLEEP=0
MAILTOADMIN=
MAILTODEVELOPER=
MAILTORADIO=
MAXSAMPLES=3
MAXSLEEP=2
APVISUALS=false
APPRCS=
START=false
STOP=false
RESTART=false
STATUS=false
ALLAPPLICATIONS=false
NOTFORCE=true
FASTSTOP=false
MAILACCOUNTS="_NULL_"
FILTERWL="_NULL_"
CHECKCONFIG=false
SUPERTEST=false
STATUS=false
DEBUG=false
ERROR=true
FAST=false
MAXLOGSIZE=500
THREADDUMP=false
VIEWREPORT=false
VIEWHISTORY=false
MAINTENANCE=false
SVERSION=false
APPTYPE="STAYRESIDENT"
UNIQUELOG=false
PREEXECUTION="_NULL_"
POSTEXECUTION="_NULL_"
OPTIONS=
VERSION="`cat ${APPATH}/VERSION | sed -e 's/-rev/ Rev./g'`"
RELEASE=`openssl dgst -md5 ${APPATH}/${APNAME}.sh | rev | cut -c-4 | rev`

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
  mv ${APLOGP}.log ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGP}.err ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.allps ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.lock ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.pid ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.ppid ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.ps ${DAYOF}/ > /dev/null 2>&1
  mv ${APLOGT}.pss ${DAYOF}/ > /dev/null 2>&1
  rm ${APLOGT}.inprogress > /dev/null 2>&1
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

    [ ! -z "{DOMAIN_NAME}" ] && export DOMAIN_NAME

  fi

  if ${CHECKTEST}
  then
    if [ "${SHOWLOG}" = "YES" ]
    then
      printto  "File: ${FILESETUP}\n--"
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
# monopse --application=resin --threaddump=5 
# por defecto, el ftd se almacena en el filesystem log de la aplicación; si se detecta que se esta
# incrementando el uso del filesystem, conserva los mas recientes 
make_fullthreaddump() {
  # para cuando son procesos JAVA StandAlone (WL, Tomcat, etc...) 
  log_action "DEBUG" "Change to ${PATHAPP}"
  [ -r ${APLOGT}.pid ] && PID=`tail -n1 ${APLOGT}.pid`

  # para cuando son procesos ONDemand (iPlanet, ...)
  [ -r ${APLOGT}.plist -a ${FILTERAPP} ] && PID=`head -n1 ${APLOGT}.pid`
  
  # meter una marca para saber desde donde vamos a sacar datos del log
  ftdFILE="${APLOGP}_`date '+%Y%m%d-%H%M%S'`.ftd"
  touch "${ftdFILE}"
  log_action "DEBUG" "Taking ${APLOGP}.log to extract the FTP on ${ftdFILE}"
  tail -f "${APLOGP}.log" > ${ftdFILE} 2>&1 & 

  # enviar el FTD al PID, N muestras cada T segs
  times=0
  timeStart=`date`
  while [ $times -ne $MAXSAMPLES ]
  do
    #kill -3 $PID
    printto  "Sending a FTD to PID $PID at `date '+%H:%M:%S'`"
    log_action "INFO" "Sending a FTD to PID $PID at `date '+%H:%M:%S'`"
    wait_for "Getting information of $PID... " $MAXSLEEP
    times=$(($times+1))
  done
  
  #
  # generar encabezado y limpiar basura
  log_action "INFO" "Check file: $ftdFILE"
  printto  "Ok, check file $ftdFILE"
  tFILE=`wc -l ${ftdFILE} | awk '{print $1}'`
  gFILE=`nl -ba ${ftdFILE} | grep "Full thread dump" | grep "Java HotSpot" | head -n1 | awk '{print $1}'`
  total=$(($tFILE-$gFILE+1))
  log_action "DEBUG" "Total: $total, where tFile=$tFILE and gFile=$gFILE"
  tail -n${total} ${ftdFILE} > ${ftdFILE}.tmp
  printto  "-------------------------------------------------------------------------------" > ${ftdFILE}
  printto  "-------------------------------------------------------------------------------" >> ${ftdFILE}
  printto  "JAVA FTD" >> ${ftdFILE}
  printto  "-------------------------------------------------------------------------------" >> ${ftdFILE}
  printto  "Host: `hostname`" >> ${ftdFILE}
  printto  "ID's: `id`" >> ${ftdFILE}
  printto  "Date: ${timeStart}" >> ${ftdFILE}
  printto  "Appl: ${APPRCS}" >> ${ftdFILE}
  printto  "Smpl: ${MAXSAMPLES}" >> ${ftdFILE}
  printto  "-------------------------------------------------------------------------------" >> ${ftdFILE}
  cat ${ftdFILE}.tmp >> ${ftdFILE}
 
  # enviar por correo 
  if [ "${MAILACCOUNTS}" != "_NULL_" ]
  then
    ${MAIL} -s "${APPRCS} FULL THREAD DUMP ${timeStart} (${ftdFILE})" "${MAILACCOUNTS}" < ${ftdFILE} > /dev/null 2>&1 &
    log_action "INFO" "Sending a full thread dump(${ftdFILE}) by mail to ${MAILACCOUNTS}"
  fi
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
  printto  "${APPRCS} ${TYPEOPERATION} ${STRSTATUS}, see also ${APLOGP}.log for information"
  if [ "${MAILACCOUNTS}" != "_NULL_" ]
  then
    # y mandarlo a bg, por que si no el so se apendeja, y por este; este arremedo de programa :-P
    ${MAIL} -s "${APPRCS} ${TYPEOPERATION} ${STRSTATUS}" -r "${MAILACCOUNTS}" > /dev/null 2>&1 &
    log_action "INFO" "Report ${APPRCS} ${TYPEOPERATION} ${STRSTATUS} to ${MAILACCOUNTS}"
  fi

}


#
# show application's version
show_version () {
  printto "${APNAME} ${VERSION} (${RELEASE})"
  printto "(c) 2010 ${APPROF}\n"
  
  if [ ${SVERSION} ]
  then
    printto  "Developed by"
    printto  "Andres Aquino <andres.aquino@gmail.com>"
  fi

}


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
    --all|all)
      ALLAPPLICATIONS=true
      ERROR=false
      if ${DEBUG} || ${VIEWHISTORY} || ${VIEWREPORT} || ${STATUS}
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
    -v|--verbose)
      VIEWLOG=true
      ERROR=false
    ;;
    -vv)
      VIEWLOG=true
      VIEWMLOG=true
      ERROR=false
    ;;
    --quiet|-q)
      VIEWLOG=false
      VIEWMLOG=false
      ERROR=false
    ;;
    --fast|fast)
      FAST=true
      ERROR=false
      if ${CHECKCONFIG} || ${THREADDUMP} || ${VIEWMLOG} || ${VIEWREPORT} || ${MAINTENANCE}
      then
        ERROR=true
      fi
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
      printto  "Usage: ${APNAME} [OPTION]..."
      printto  "start up or stop applications like WebLogic, Fuego, Resin, etc."
      printto  "Mandatory arguments in long format."
      printto  "\t-a, --application=APPNAME       use this application, required "
      printto  "\t    --all                       all registered applications "
      printto  "\t    --start                     start appName "
      printto  "\t    --stop                      stop appName "
      printto  "\t    --restart                   restart appName "
      printto  "\t    --fast                      send execution to background "
      printto  "\t-s, --status                    verify the status of appName "
      printto  "\t    --quiet                     doesn't show execution output of application "
      printto  "\t-v, --verbose                   send output execution to terminal "
      printto  "\t-r, --report                    show an small report about domains "
      printto  "\t-m, --maintenance               execute all shell plugins in maintenance directory "
      printto  "\t-t, --threaddump                send a 3 signal via kernel by 3 times "
      printto  "\t    --threaddump=COUNT,INTERVAL send a 3 signal via kernel, COUNT times between INTERVAL "
      printto  "\t-c, --check-config              check config application (see ${APNAME}-${APNAME}.conf) "
      printto  "\t-vv                             send output execution and ${APNAME} execution to terminal "
      printto  "\t-d, --debug                     debug logs and processes in the system "
      printto  "\t    --version                   show version "
      printto  "\t-h, --help                      show help "
      printto  "Each APPNAME refers to one application on the server. "
      printto  "In case of threaddump options, COUNT refers of times sending kill -3 signal between "
      printto  "INTERVAL time in seconds \n"
      printto  "Report bugs to <andres.aquino@gmail.com> \n"
      exit 0
    ;;
    *)
      # FEAT
      # ahora ya es posible usar el monopse $APP [options] sin usar el parametro -a o --application
      # cute ^.^!
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
  printto "Apps Environment"
  printto "--"
  printto "APPNAME   = ${APNAME}"
  printto "USER      = ${APUSER}"
  printto "HOME      = ${APHOME}"
  printto "VERSION   = ${VERSION}"
  printto "RELEASE   = ${RELEASE}"
  printto "PROCESS   = ${APPRCS}"
  printto "CURRENT   = ${APDATE}"
  printto "IPADDRESS = ${IPADDRESS}"
  printto "HOSTNAME  = ${APHOST}"
  printto "--"
  printto "APLEVL    = ${APLEVL}"
  printto "APPATH    = ${APPATH}"
  printto "APLOGD    = ${APLOGD}"
  printto "APLOGS    = ${APLOGS}"
  printto "APLOGP    = ${APLOGP}"
  printto "APTEMP    = ${APTEMP}"
  for app in ${APPATH}/setup/*-*.conf
  do
    echo "APSETP   = ${app}"
  done

  exit 0
fi

#
if ${ERROR}
then
  printto  "Usage: ${APNAME} [OPTION]...[--help]"
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
  if ! ${ALLAPPLICATIONS} 
  then
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
      ${DEBUG} && CANCEL=false
      if ${CANCEL}
      then
        printto  "Usage: ${APNAME} [OPTION]...[--help]"
        exit 1
      fi
    fi
  fi

  #
  # RESTART -- guess... ?
  if ${RESTART}
  then
    OPTIONAL=
    ${VIEWLOG} && OPTIONAL="${OPTIONAL} --verbose" || OPTIONAL="${OPTIONAL} --quiet"
    ${FAST} && OPTIONAL="${OPTIONAL} --fast"

    if ${ALLAPPLICATIONS} 
    then
      for APMAIN in ${APPATH}/setup/*.conf
      do
        MAPPFILE=`basename ${APMAIN%-*.conf}`
        log_action "DEBUG" "Executing restart over ${MAPPFILE} "
        wait_for "Stopping ${MAPPFILE} application" 1
        ${APPATH}/${APNAME} --application=${MAPPFILE} stop --forced --quiet 
        RESULT=$?
        wait_for "Starting ${MAPPFILE} application" 1
        [ ${RESULT} -eq 0 ] && ${APPATH}/${APNAME} --application=${MAPPFILE} start ${OPTIONAL}
      done
    else
      wait_for "Stopping ${APPRCS} application" 2
      ${APPATH}/${APNAME} --application=${APPRCS} stop --forced ${OPTIONAL}
      RESULT=$?
      wait_for "Starting ${APPRCS} application" 2
      [ ${RESULT} -eq 0 ] && ${APPATH}/${APNAME} --application=${APPRCS} start ${OPTIONAL}
    fi
  fi

  
  #
  # START -- Iniciar la aplicación indicada en el archivo de configuración
  if ${START}
  then   
    #
    # que sucede si intentan dar de alta el proceso nuevamente
    # verificamos que no exista un bloqueo (Dummies of Proof) 
    if ${ALLAPPLICATIONS}
    then
      OPTIONAL=
      ${VIEWLOG} && OPTIONAL="${OPTIONAL} --verbose" || OPTIONAL="${OPTIONAL} --quiet"
      ${FAST} && OPTIONAL="${OPTIONAL} --fast"

      for APMAIN in ${APPATH}/setup/*.conf
      do
        MAPPFILE=`basename ${APMAIN%-*}`
        ${APPATH}/${APNAME} --application=${MAPPFILE} start ${OPTIONAL}
      done
      # como ya termino, no tiene caso seguir
      exit 0
    fi
  
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
      wait_for "${APPRCS} in progress of execution" 1
      wait_for "CLEAR"
      if ${UNIQUELOG}
      then
        ${VIEWMLOG} && wait_for "${APPRCS} executing, wait wait wait! (uniquelog)\n" 1
        nohup sh ${STARTAPP} > ${APLOGP}.log 2>&1 &
        log_action "DEBUG" "Executing ${STARTAPP} with ${APLOGP}.log as logfile, with unique output ..." 
      else
        ${VIEWMLOG} && wait_for "${APPRCS} executing, wait wait wait! (log and err)\n" 1
        nohup sh ${STARTAPP} 2> ${APLOGP}.err > ${APLOGP}.log &
        log_action "DEBUG" "Executing ${STARTAPP}, ${APLOGP}.log as logfile, ${APLOGP}.err as errfile ..."
      fi
      date '+%Y%m%d-%H%M' > ${APLOGT}.date
      # summary en lock para un post-analisis
      printto  "Options used when monopse was called:\n ${OPTIONS}" > ${APLOGT}.lock
      printto  "\nDate:\n`date '+%Y%m%d %H:%M'`" >> ${APLOGT}.lock
    fi

    #
    # a trabajar ... !
    LASTSTATUS=1
    ONSTOP=1
    LASTLINE=""
    LINE="`tail -n1 ${APLOGP}.log`"
    INWAIT=true
    if ${FAST}
    then
      touch ${APLOGT}.inprogress 
      INWAIT=false
    fi

    wait_for "Getting PID's and lock process files ..." 1
    while (${INWAIT})
    do
      filter_in_log "${UPSTRING}"
      LASTSTATUS=$?
      wait_for "Waiting for ${APPRCS} execution, be patient ..." 2
      [ ${LASTSTATUS} -eq 0 ] && report_status "*" "process ${APPRCS} start successfully"
      [ ${LASTSTATUS} -eq 0 ] && log_action "DEBUG" "Great!, the ${APPRCS} start successfully"
      [ ${LASTSTATUS} -eq 0 ] && INWAIT=false
      [ ${LASTSTATUS} -eq 0 ] && break
      if [ "${LINE}" != "${LASTLINE}" ]
      then 
        ${VIEWLOG} && printto  "   | ${LINE}" 
        LINE="$LASTLINE"
        wait_for "CLEAR"
        printto  "   | ${LINE}"
      fi
      ONSTOP="$(($ONSTOP+1))"
      [ $ONSTOP -ge $TOSLEEP ] && report_status "?" "Uhm, something goes wrong with ${APPRCS}"
      [ $ONSTOP -ge $TOSLEEP ] && INWAIT=false;
      LASTLINE="`tail -n1 ${APLOGP}.log`"
    done
    
    # buscar los PID's
    ${FAST} && report_status "*" "process ${APPRCS} started, please verify..."
    get_process_id "${FILTERAPP},${FILTERLANG}"
    printto  "\nPID:\n" >> "${APLOGT}.lock" 2>&1
    cat ${APLOGT}.pid >> "${APLOGT}.lock" 2>&1

    # FIX
    # SI LA APLPICACION CORRE UNA SOLA VEZ, ELIMINAR EL .lock
    [ ${APPTYPE} = "RUNONCE" ] && rm -f "${APLOGT}.lock" && log_backup
    exit ${LASTSTATUS}
  fi
  

  #
  # STOP -- Detener la aplicación sea por instrucción o deteniendo el proceso, indicado en el archivo de configuración
  if ${STOP} 
  then
    # para todas las aplicaciones
    if ${ALLAPPLICATIONS}
    then
      OPTIONAL=
      ${VIEWLOG} && OPTIONAL="${OPTIONAL} --verbose" || OPTIONAL="${OPTIONAL} --quiet"
      ${FASTSTOP} && OPTIONAL="${OPTIONAL} --forced"
      ${FAST} && OPTIONAL="${OPTIONAL} --fast"

      for APMAIN in ${APPATH}/setup/*.conf
      do
        MAPPFILE=`basename ${APMAIN%-*.conf}`
        ${APPATH}/${APNAME} --application=${MAPPFILE} stop ${OPTIONAL}
      done
      
      # como ya termino, no tiene caso seguir 
      exit 0
    fi

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
    process_running
    FNEXIST=true
    [ -s ${APLOGT}.pid ] && FNEXIST=false
    if ${FNEXIST}
    then
      printto  "uh, ${APPRCS} is not running currently, tip: ${APNAME} --report"
      log_action "INFO" "The application is down"
      exit 0
    fi
    
    # ejecutar el postexecution
    if [ ${POSTEXECUTION} != "_NULL_" ]
    then
      log_action "DEBUG" "Executing ${POSTEXECUTION}, logging to ${APLOGT}.post"
      sh ${POSTEXECUTION} > ${APLOGT}.post 2>&1 
      LASTSTATUS=$?
      if [ ${LASTSTATUS} -ne 0 ]
      then
        report_status "?" "some problems with ${POSTEXECUTION}, ERROR_CODE: ${LASTSTATUS}"
        exit 1
      fi
      report_status "*" "Good, all clear..."
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
          ${VIEWLOG} && printto "   | ${LINE}" 
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
      log_backup
    fi

    #
    # si no se cancelo el proceso por la buena, entonces pasamos a la mala
    if [ ${LASTSTATUS} -eq 0 ]
    then
      # si el stop es con FORCED, y es una aplicacion JAVA enviar FTD
      #if [ ${FILTERLANG} = "java" -a ${THREADDUMP} = true ]
      if [ ${THREADDUMP} = true ]
      then
        # monopse -a=app stop -f -t=3,10
        # se aplica un fullthreaddump de 3 muestras cada 10 segundos antes de detener el proceso de manera forzada. 
        log_action "DEBUG" "before kill the baby, we send 3 FTD's between 8 secs"
        ${APPATH}/${APNAME} --application=${APPRCS} --threaddump=${MAXSAMPLES},${MAXSLEEP}
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
        wait_for "Uhmmm, you're a impatient guy !!" 1
        wait_for "CLEAR"
        process_running
        if [ $? -eq 0 ]
        then
          awk '{print "kill -9 "$0}' ${APLOGT}.pid | sh
          ${VIEWMLOG} && wait_for "Ok, sending the kill-bill signal, can you wait some seconds?\n" 2
          if ! ${FAST}
          then
            LASTLINE="`tail -n1 ${APLOGP}.log `"
            ${VIEWLOG} && printto "   | ${LASTLINE}"
          fi
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
        log_backup
      fi

      [ ${LASTSTATUS} -ne 0 ] && exit 0
      
      processes_running
    fi

    #
    # hacer un full thread dump a un proceso X
    if ${THREADDUMP}
    then
      make_fullthreaddump
      
      # quitar el proceso de copia del log
      PROCESSES=`ps ${PSOPTS} | grep "tail -f ${APLOGP}.log" | grep -v grep | awk '/tail/{print $2}'`
      log_action "DEBUG" "Killing tail processes of FTD: ${PROCESSES}"
      kill -15 ${PROCESSES} > /dev/null 2>&1

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
          ${APPATH}/${APNAME} --application=$app --status ${OPTIONAL}
        done
        printto  "\nTotal $count application(s)"
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
      count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
      [ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
      processes_running
      printto  "\n ${APHOST} (${IPADDRESS})"
      printto  "APPLICATION:EXECUTED:PID:STATUS" | 
        awk 'BEGIN{FS=":";OFS="| "}
              {
                print " "substr($1"                             ",1,20),
                      substr($2"              ",1,14),
                      substr($3"              ",1,6),
                      substr($4"              ",1,6)
              }'
      printto  " --------------------+---------------+-------+---------"
      
      for app in ${APPATH}/setup/*-*.conf
      do
        appname=`basename ${app%-*.conf}`
        apppath=`awk 'BEGIN{FS="="} /^PATHAPP/{print $2}' ${app}`
        apppidn=""
        log_action "DEBUG" "report from ${APTEMP}/${appname}"
        [ -s ${APTEMP}/${appname}.date ] && appdate=`head -n1 "${APTEMP}/${appname}.date"` || appdate=
        if [ -s ${APTEMP}/${appname}.pid ]
        then
          apppidn=`head -n1 "${APTEMP}/${appname}.pid"`
          [ ${#apppidn} -gt 0 ] && kill -0 $apppidn > /dev/null 2>&1
          [ $? -ne 0 ] && rm -f ${APTEMP}/${appname}.p* && apppidn=
          [ $? -ne 0 ] && rm -f ${APTEMP}/${appname}.inprogress > /dev/null 2>&1
        fi
        [ ${#apppidn} -gt 0 ] && appstat="RUNNING" || appstat="STOPPED"
        [ -f ${APTEMP}/${appname}.inprogress ] && appstat="INPROGRESS"
        
        printto "${appname}:${appdate}:${apppidn}:${appstat}" | 
          awk 'BEGIN{FS=":";OFS="| "}
              {
                print " "substr($1"                             ",1,20),
                      substr($2"              ",1,14),
                      substr($3"              ",1,6),
                      substr($4"              ",1,9)
              }'
      done
      printto  "\nTotal $count application(s)"
    fi
    

    #
    # LOG -- enerar un reporte de aplicaciones historico de operaciones realizadas
    #
    # PULGOSA
    #
    # DATE     | STOP | START | SERVER             | BACKUP
    # ---------+-------+-------+--------------------+---------------------------
    # 20080924 | 0046 | 0120  | test               | test_20080924_0120.tar.gz
    # ...
    if ${VIEWHISTORY} 
    then
      count=`ls -l ${APPATH}/setup/*-*.conf | wc -l | sed -e "s/ //g"`
      [ $count -eq 0 ] && report_status "?" "Cannot access any config file " && exit 1
      printto  "\n ${APHOST} (${IPADDRESS})\n"
      printto  "START:STOP:APPLICATION:" | 
        awk 'BEGIN{FS=":";OFS="| "}
              {
                print " "substr($1"                     ",1,18),
                      substr($2"                     ",1,18),
                      substr($3"                     ",1,28);
              }'
      printto  " ------------------+-------------------------------------------------"
      log_action "DEBUG" "report from ${APLOGS}.log "
      tail -n5000 ${APLOGS}.log | tr -d ":[]()-" | sort -r | \
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
                    print " "substr(LDATE"                     ",1,9),
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
      printto  ""
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
          report_status "i" "Uhmm, yeah... nothing to do with ${MLOGFILE}"
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
      printto  "\nDEBUG" >> ${FLDEBUG}
      printto  "-------------------------------------------------------------------------------\n" >> ${FLDEBUG}
      printto  "HOSTNAME     : ${APHOST}" >> ${FLDEBUG}
      printto  "USER         : ${APUSER}" >> ${FLDEBUG}
      printto  "VERSION      : ${VERSION}" >> ${FLDEBUG}
      printto  "RELEASE      : ${RELEASE}" >> ${FLDEBUG}
      printto  "PROCESS      : ${APPRCS}" >> ${FLDEBUG}
      printto  "CURRENT      : ${APDATE}" >> ${FLDEBUG}
      printto  "IPADDRESS    : ${IPADDRESS}" >> ${FLDEBUG}
      printto  "DESCRIPTION  : ${DESCRIPTION}" >> ${FLDEBUG}
      printto  " " >> ${FLDEBUG}
      printto  "-------------------------------------------------------------------------------" >> ${FLDEBUG}      
      printto  "\nDATE " >> ${FLDEBUG}
      printto  "${APLOGT}.date" >> ${FLDEBUG}
      cat ${APLOGT}.date >> ${FLDEBUG} 2>&1
      printto  "\nPIDFILE " >> ${FLDEBUG}
      printto  "${APLOGT}.pid" >> ${FLDEBUG}
      cat ${APLOGT}.pid >> ${FLDEBUG} 2>&1
      printto  "\nPROCESSES TABLE" >> ${FLDEBUG}
      process_running
      PROCESSES=$?
      if [ ${PROCESSES} -eq 0 ]
      then
        printto  "${APPRCS} is running" >> ${FLDEBUG} 2>&1
        cat ${APLOGT}.ps >> ${FLDEBUG} 2>&1
      else
        printto  "${APPRCS} is not running." >> ${FLDEBUG} 2>&1
      fi
      printto  "\nFILESYSTEM" >> ${FLDEBUG}
      df ${DFOPTS} >> ${FLDEBUG} 2>&1
      printto  "\nLOGFILE" >> ${FLDEBUG}
      printto  "-------------------------------------------------------------------------------" >> ${FLDEBUG}      
      tail -n100 ${APLOGP}.log >> ${FLDEBUG} 2>&1
      printto  "  " >> ${FLDEBUG}
      printto  "-------------------------------------------------------------------------------" >> ${FLDEBUG}
     
      #
      cat ${FLDEBUG}
      log_action "INFO" "Show the application debug information"
   fi
   
   ${STOP} && log_backup;
   exit ${LASTSTATUS}
fi

