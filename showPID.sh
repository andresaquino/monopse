# Obtiene el PID del engine de Order Entry
PID_OE=`ps -feax | grep pvision | grep ftboot | grep -v pvisionConsulta | grep -v pvisionAplica | grep -v pvisionActiva | awk '{print $2}'`

# Obtiene el PID del engine de Consultas
PID_Cons=`ps -feax | grep pvisionConsulta | grep ftboot | awk '{print $2}'`

#Obtiene el PID del engine de Aplicaciones
PID_Aplica=`ps -feax | grep pvisionAplica | grep ftboot | awk '{print $2}'`

#Obtiene el PID del engine de Activa
PID_Activa=`ps -feax | grep pvisionActiva | grep ftboot | awk '{print $2}'`


echo PID_OE=$PID_OE
echo PID_Aplica=$PID_Aplica
echo PID_Cons=$PID_Cons
echo PID_Activa=$PID_Activa
