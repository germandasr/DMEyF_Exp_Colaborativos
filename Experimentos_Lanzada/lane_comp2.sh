#!/bin/bash
# ============================================================
# Lane Comp2: corre los experimentos uno atras del otro en la VM,
# sube cada carpeta de resultados + su log al bucket apenas termina
# (haya salido OK o con error). Al final se apaga sola SOLO SI al
# menos un experimento salio OK - si fallan todos (ej: algo mal
# instalado/configurado en la VM), NO se apaga, para poder
# diagnosticar sin gastar otro ciclo de prendido/apagado.
#
# A diferencia de la Lane A/B de Competencia 1 (que era un pipeline
# con dependencias entre etapas), estos experimentos son INDEPENDIENTES
# entre si (todos parten del mismo baseline + 1 cambio puntual cada uno),
# asi que si uno falla, NO se corta la cadena - se sigue con el resto
# para no perder las corridas de los demas.
#
# Uso:  nohup bash lane_comp2.sh > log_lane_comp2.txt 2>&1 &
# ============================================================

BUCKET="gs://reintgeng_buckito2026/Competencia_2/Resultados"

EXPERIMENTOS=(Exp_0 Exp_8 Exp_9 Exp_10 Exp_11 Exp_12 Exp_13 Exp_24 Exp_25)

cd "$(dirname "$0")"
echo "$(date): Lane Comp2 arranca."

ok_count=0
falla_count=0

for exp in "${EXPERIMENTOS[@]}"; do
  script="${exp}_VM.R"
  echo "$(date): arranca $script"

  Rscript "$script" > "log_${exp}.txt" 2>&1
  status=$?

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
done

echo "$(date): Lane Comp2 completa. Resultado: ${ok_count} OK / ${falla_count} con error."

if [ $ok_count -gt 0 ]; then
  echo "$(date): Al menos 1 experimento OK. Apagando la VM..."
  sudo shutdown -h now
else
  echo "$(date): Fallaron todos los experimentos - NO se apaga la VM, revisar los logs (algo esta mal configurado)."
fi
