#!/usr/bin/ksh
# Nombre del programa           : alertasfn.sh
# Objetivo del programa         : Monitoreo y envio de alertas UNIX y DB
# Idea original                 : L.I. Mireya MÅndez GodÕnez
# Modificado por                : Ing. Andres Franco
# Fecha de ElaboraciÆn          : 7 de Septiembre de 1999
# Fecha Ultima ModificaciÆn     : 29 de Agosto del 2002
#
# DescripciÆn Variables Globales
#
# BK_ARC        : Variable numerica, registra el porcentaje de disco utilizado
#                 por el filesystem de archivelog
# HOSTNAME      : Nombre del host, variable que se exporta para ser
#                 utilizada por el script ftps.sh, el valor es obtenido
#                 a traves del comando hostname
# ALERTS_MSG    : Path y nombre del archivo que contiene los errores recopilados
#                 durante la ejecuciÆn del programa para registrarse en el
#                 archivo de log.  Este archivo es destruido al terminar la
#                 ejecuciÆn del programa
# ALERTS_SEND   : Path y nombre del archivo que contiene las alertas a enviar
#                 Este archivo es destruido al terminar la ejecuciÆn del
#                 programa
# TMP           : Path y nombre del archivo que sirve para filtrar y dar formato
#                 a las alertas enviar.  Este archivo es destruido al terminar
#                 la ejecuciÆn del programa
# FTP_SEND      : Path y nombre del script que ejecuta un ftp a la maquina
#                 SUN telamon para enviar las alertas.
# DATE          : Fecha y hora en la que se ejecuto este script
#                 Formato mm/dd/yy hh:mm:ss
# LOG           : Path y nombre del archivo de log donde se registran las
#                 alertas enviadas
# err#          : Variable que guarda cada uno de los errores encontrados
#                 durante el monitoreo
#                 Se declara una variable para cada posible error que se
#                 verifica indicando el mensaje de alerta que se debe enviar


# Obtencion de informacion de conexion a los servidores
#


# Obtencion de informacion de la base de datos ADMN
#
AD_DBALL=4

# Obtencion de informacion del filesystem de archivelog
#
BK_ARC=$(bdf /archivelog/PBSCS | awk '{print $5}' | cut -d% -f1)

# Manipulacion de archivos para alertas y logs
#
export HOSTNAME=$(hostname)
ALERTS_MSG="/home/soptec/alertas/$HOSTNAME.txt"
ALERTS_SEND="/home/soptec/alertas/$(hostname)_alertas"
TMP="/home/soptec/alertas/$(hostname|cut -c6-7)tmp"
FTP_SEND="/home/soptec/alertas/ftps.sh"
DATE=$(date "+%m/%d/%Y %X")
LOG="/home/soptec/alertas/alertas$(hostname|cut -c6-7).log"
CURRENT="/home/soptec/alertas/current_errors"
LAST="/home/soptec/alertas/last_errors"
FS="/home/soptec/alertas/fs.$(hostname|cut -c6-7)"
ERR=1

# Funcion que determina si el mensaje de error encontrado debe ser
# enviado o no a los iDENS
# Si el error a enviar fue registrado en la Çltima ejecuciÆn del script
# entonces espera hasta una tercera ejecuciÆn para reenviar el mismo mensaje
# de error si es que este continua apareciendo
#
function check_error
{
  if [ -a $LAST ]
  then
        error_on=$(grep -c "$1" $LAST)
  else
        error_on=0
  fi

  if [ $error_on -eq 1 ]
  then
        unset err$3
  else
        print $1 >> $CURRENT
        print $2 >> $ALERTS_MSG
  fi
}

# Genera el archivo que sirve como bandera para la funcion check_error
# para verificar el registro de errores actuales y ultimos errores enviados
#
if [ -a $CURRENT ]
then
	mv $CURRENT $LAST
else
	touch $CURRENT
	mv $CURRENT $LAST
fi

# Evalua el status de conexion a los servidores
# Modificado todo el proceso 290802

for i in `cat /home/soptec/alertas/servers.txt|awk {'print $1'}`
do
        PINGSVR=$(ping $i -n 3 | grep loss | cut -d, -f3 | cut -d% -f1)
        if [ $PINGSVR -eq 100 ]
        then
                err_uno="`cat /home/soptec/alertas/servers.txt|grep $i|awk {'print $2'}` : IP $i connection lost or system reboot"
                err_uno_uno="`cat /home/soptec/alertas/servers.txt|grep $i|awk {'print $2'}` : IP $i connection lost or system reboot"
                check_error "$err_uno" "$err_uno_uno" $ERR
		ERR_TMP=$(($ERR + 1))
		ERR=$ERR_TMP
		print "$err_uno," >> $TMP
        fi
done

# Evalua el status de las bases de datos de declaradas en el archivo bases.txt
#
for i in `cat /home/soptec/alertas/bases.txt`
do
        PMON=$(ps -fea | grep -v grep | grep -c ora_pmon_$i )
        RECO=$(ps -fea | grep -v grep | grep -c ora_reco_$i)
        LGWR=$(ps -fea | grep -v grep | grep -c ora_lgwr_$i)
        SMON=$(ps -fea | grep -v grep | grep -c ora_smon_$i)
        AD_DBSUM=$(($PMON + $RECO + $LGWR + $SMON ))
        if [ $AD_DBSUM -lt $AD_DBALL ]
        then
                err_uno="`hostname`: DB $i down"
                err_uno_uno="`hostname`: Database $i down"
                check_error "$err_uno" "$err_uno_uno" $ERR
		ERR_TMP=$(($ERR + 1))
                ERR=$ERR_TMP
		print "$err_uno," >> $TMP
        fi
done

# Evalua el espacio ocupado por el filesystem de archivelog
#
if [ $BK_ARC -gt 70 ]
then
	err_uno="archivelog 70%"
	err_uno_uno="mexhpbk2: archivelog 70%"
	check_error "$err_uno" "$err_uno_uno" $ERR 
	ERR_TMP=$(($ERR + 1))
        ERR=$ERR_TMP
	print "$err_uno," >> $TMP
fi

# Evalua el espacio ocupado por los file systems
#
/home/soptec/alertas/checa_espacio.sh >> $FS

# Determina si el mensaje de error de filesystem encontrado debe ser
# enviado o no a los iDENS
# Si el error a enviar fue registrado en la Çltima ejecuciÆn del script
# entonces espera hasta una tercera ejecuciÆn para reenviar el mismo mensaje
# de error si es que este continua apareciendo
#
ini=1
num=$(cat $FS | wc -l)
max=$(($num + 1))
last=$num
cp $ALERTS_MSG /home/soptec/alertas/prueba11.txt
while [ $ini -lt $max ]
do
	fs=$(tail -$last $FS | head -1)
	error_on=$(grep -c "$fs" $LAST)
	if [ $error_on != 1 ]
	then
		print $fs >> $CURRENT
		print $fs >> $ALERTS_MSG
	fi
	ini=$(($ini + 1))
	last=$(($last - 1))
done
rm $FS
cp $ALERTS_MSG /home/soptec/alertas/prueba111.txt
# Evalua la existencia de alertas a enviar, si exiten alertas las envia
# por ftp a la maquina SUN telamon, de lo contrario termina la ejecuciÆn
# del script
#
if [ -s $ALERTS_MSG ]
then

	# Recopila todos los errores de las variables err# en un solo archivo
	# llamado $TMP .  Cada error es separado por una coma (,)
	#
	#print "$err1, $err2, $err3, $err4, $err5, $err6, $err7, $err8, $err9" > $TMP
	
	grep FS $ALERTS_MSG >> $TMP

        # Elimina las comas y espacios generados por las variables err# vacias
	# del archivo $TMP
	#
	sed s/" ,"//g $TMP > $ALERTS_SEND
	mv $ALERTS_SEND $TMP
	# Elimina las lineas que solo tengan el nombre del servidor del archivo
	# $TMP
	#
	ini=1
	num=$(cat $TMP | wc -l)
	max=$(($num + 1))
	last=$num
	while [ $ini -lt $max ]
	do
		not_empty=$(tail -$last $TMP | head -1 | wc -w)
		if [ $not_empty -gt 1 ]
		then
			tail -$last $TMP | head -1 >> $ALERTS_SEND
		fi
                ini=$(($ini + 1))
		last=$(($last - 1))
	done
	# Inserta hora y fecha del envio del mensaje
	date "+%H:%M %d/%m" > $TMP
	
	cat $ALERTS_SEND >> $TMP
	mv $TMP $ALERTS_SEND 
        # Envia por ftp los mensajes de alertas a la maquina SUN telamon
	# a todos los radios registrados en el archivo lista_idens.txt
	#. $FTP_SEND $ALERTS_SEND
	for i in `cat /home/soptec/alertas/lista_idens.txt`
	do 
		mailx -s $i mensajes@nextel.com.mx < $ALERTS_SEND
	done
	#mailx -s 525525883911 andres.franco@nextel.com.mx < $ALERTS_SEND

	# Genera el log de las alertas enviadas y clasifica cada alerta
	# por tipo de error
	#
	NUM_ALERTAS=$(cat $ALERTS_MSG | wc -l)
	NUM=1
	MAX=$(($NUM_ALERTAS + 1))
	LAST=$NUM_ALERTAS
	while [ $NUM -lt $MAX ]
	do
                ALERTA=$(tail -$LAST $ALERTS_MSG | head -1)
		ERROR=$(tail -$LAST $ALERTS_MSG | head -1 | egrep "IP|PACKAGE|NODE|Database|Listener|switched|CONCURRENTS|archivelog|process|VANTIVE" | awk '{print $2}')
		case $ERROR in

  		      connection ) TIPO_ERROR="conexion";;
	   PACKAGE|NODE|switched ) TIPO_ERROR="cluster";;
			Database ) TIPO_ERROR="database";;
		        Listener ) TIPO_ERROR="listener";;
		     CONCURRENTS ) TIPO_ERROR="concurrent";;
		      archivelog ) TIPO_ERROR="archivelog";;
		 	 process ) TIPO_ERROR="switch-processes";;
			 VANTIVE ) TIPO_ERROR="vantive-servicios";;
			       * ) TIPO_ERROR="filesystem-full";;
		esac
		print "$DATE|$ALERTA|$TIPO_ERROR" >> $LOG
		NUM=$(($NUM + 1))
		LAST=$(($LAST - 1))
	done

        # Borra todos los archivos temporales utilizados durante la ejecucion
	#
	rm $ALERTS_MSG $ALERTS_SEND $TMP
fi
