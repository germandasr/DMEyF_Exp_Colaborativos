#!/bin/bash
# ============================================================
# Lane Comp2 batch2: Exp_26 a Exp_31, todos completos de cero
# (bayesiana + produccion). Sube cada carpeta de resultados al
# bucket apenas termina esa etapa (OK o con error, no corta la
# cadena). Al final se apaga sola SOLO SI al menos uno salio OK.
# El apagado es inline/bloqueante en este mismo proceso (NO hay
# watcher aparte con pgrep - esa fue la causa de un bug anterior).
#
# Uso:  nohup bash lane_comp2_batch2.sh > log_lane_comp2_batch2.txt 2>&1 &
# ============================================================

BUCKET="gs://reintgeng_buckito2026/Competencia_2/Resultados"

cd "$(dirname "$0")"
echo "$(date): Lane Comp2 batch2 arranca."

ok_count=0
falla_count=0

run_stage () {
  local script=$1
  local exp=$2

  echo "$(date): arranca $script"
  Rscript "$script" > "log_${exp}.txt" 2>&1
  local status=$?

  if [ -d "../exp/$exp" ]; then
    cp "log_${exp}.txt" "../exp/$exp/" 2>/dev/null
    echo "$(date): subo $exp al bucket..."
    gsutil -m cp -r "../exp/$exp" "$BUCKET/"
  else
    echo "$(date): OJO: no existe la carpeta ../exp/$exp, no hay nada que subir (revisar log_${exp}.txt)"
    gsutil cp "log_${exp}.txt" "$BUCKET/$exp/log_${exp}.txt"
  fi

  if [ $status -ne 0 ]; then
    echo "$(date): $exp termino con error (exit $status) - sigo con el siguiente experimento."
    falla_count=$((falla_count + 1))
  else
    echo "$(date): $exp OK."
    ok_count=$((ok_count + 1))
  fi
}

for exp in Exp_26 Exp_27 Exp_28 Exp_29 Exp_30 Exp_31; do
  run_stage "${exp}_VM.R" "$exp"
done

echo "$(date): Lane Comp2 batch2 completa. Resultado: ${ok_count} OK / ${falla_count} con error."

if [ $ok_count -gt 0 ]; then
  echo "$(date): Al menos 1 experimento OK. Apagando la VM..."
  sudo shutdown -h now
else
  echo "$(date): Fallaron todos los experimentos - NO se apaga la VM, revisar los logs (algo esta mal configurado)."
fi
