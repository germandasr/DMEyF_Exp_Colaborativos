#!/bin/bash
# Lanza el workflow del experimento 15B para una lista de semillas primigenias, una atras de otra.
# Uso (desde Exp_15B):
#   nohup bash lanzar_15B.sh <brazo> <primigenia1> [<primigenia2> ...] > lanzar_15B.log 2>&1 &
# - saltea las primigenias que ya tienen resumen.csv (permite retomar si la VM spot se apago)
# - mide tiempo y pico de RAM de cada corrida (/usr/bin/time -v, al final de cada log)
# - sube la carpeta de resultados y el log al bucket
# - avisa por ntfy el resultado de cada corrida
# - al final apaga la VM solo si al menos una corrida termino bien y todo se subio al bucket

BUCKET="gs://veroestadisticamonzonvero123/15B"
NOTIFY="https://ntfy.sh/dmeyf15b-escopetamonzon"   # mismo canal que config_15B.yaml

cd "$(dirname "$0")"
EXP_DIR="../../exp"

BRAZO="$1"
shift
if [ -z "$BRAZO" ] || [ $# -eq 0 ]; then
  echo "Uso: bash lanzar_15B.sh <brazo> <primigenia1> [<primigenia2> ...]"
  exit 1
fi

ok=0
fallas=0
sin_subir=0

for PRIM in "$@"; do
  NOMBRE="15B_${BRAZO}_${PRIM}"

  if [ -f "$EXP_DIR/$NOMBRE/resumen.csv" ]; then
    echo "$(date): $NOMBRE ya estaba terminado, lo salteo"
    continue
  fi

  echo "$(date): arranca $NOMBRE"
  /usr/bin/time -v Rscript Exp_15B_VM.R "$BRAZO" "$PRIM" > "log_$NOMBRE.txt" 2>&1
  estado=$?

  if [ $estado -eq 0 ] && [ -f "$EXP_DIR/$NOMBRE/resumen.csv" ]; then
    ok=$((ok + 1))
    resultado="OK"
  else
    fallas=$((fallas + 1))
    resultado="FALLO (exit $estado)"
  fi
  echo "$(date): $NOMBRE $resultado"

  cp "log_$NOMBRE.txt" "$EXP_DIR/$NOMBRE/" 2>/dev/null
  rm -f "$EXP_DIR/$NOMBRE/modelito.txt"   # modelo temporal de la BO: pesa mucho y no hace falta subirlo
  gcloud storage cp -r "$EXP_DIR/$NOMBRE" "$BUCKET/" || { echo "$(date): OJO, no se pudo subir $NOMBRE al bucket"; sin_subir=$((sin_subir + 1)); }
  gcloud storage cp "log_$NOMBRE.txt" "$BUCKET/logs/" || true
  curl -s -d "$NOMBRE: $resultado" "$NOTIFY" > /dev/null || true
done

echo "$(date): fin. OK: $ok | con error: $fallas"
curl -s -d "15B $BRAZO terminado. OK: $ok | con error: $fallas" "$NOTIFY" > /dev/null || true

if [ $ok -gt 0 ] && [ $sin_subir -eq 0 ]; then
  echo "$(date): al menos una corrida OK, apago la VM"
  sudo shutdown -h now
else
    echo "$(date): NO apago la VM: fallaron todas las corridas o no se pudo subir algo al bucket (revisar los logs)"
fi
