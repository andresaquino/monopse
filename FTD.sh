# Obtiene el PID del engine de Order Entry
PID_OE=`ps -feax | grep pvision | grep ftboot | grep -v pvisionConsulta | grep -v pvisionAplica | grep -v pvisionActiva | awk '{print $2}'`

# Obtiene el PID del engine de Consultas
PID_Cons=`ps -feax | grep pvisionConsulta | grep ftboot | awk '{print $2}'`

# Obtiene el PID del engine de Aplicaciones
PID_Aplica=`ps -feax | grep pvisionAplica | grep ftboot | awk '{print $2}'`

# Obtiene el PID del engine Activa
PID_Activa=`ps -feax | grep pvisionActiva | grep ftboot | awk '{print $2}'`

kill -3 $PID_OE
kill -3 $PID_Cons
kill -3 $PID_Aplica
kill -3 $PID_Activa

sleep 7

kill -3 $PID_OE
kill -3 $PID_Cons
kill -3 $PID_Aplica
kill -3 $PID_Activa

sleep 7

kill -3 $PID_OE
kill -3 $PID_Cons
kill -3 $PID_Aplica
kill -3 $PID_Activa

sleep 7

kill -3 $PID_OE
kill -3 $PID_Cons
kill -3 $PID_Aplica
kill -3 $PID_Activa

sleep 7

kill -3 $PID_OE
kill -3 $PID_Cons
kill -3 $PID_Aplica
kill -3 $PID_Activa

echo Se han lanzado 5 FTD cada 7 seg a los procesos OrderEntry:$PID_OE, Consultas:$PID_Cons, Aplicaciones: $PID_Aplica, Activa: $PID_Activa
