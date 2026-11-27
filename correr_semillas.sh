#!/usr/bin/env bash
# =============================================================================
# Corre BF_nuevo.ipynb una vez por primigenia (las 6 del experimento colaborativo v3),
# en secuencia: cada corrida usa casi toda la RAM y todos los nucleos.
#
#   nohup ./correr_semillas.sh > correr_semillas.log 2>&1 &
#
# Necesita, en la misma carpeta que este script: BF_nuevo.ipynb y configs_tomasr/
#
# Deja todo en ~/buckets/b1/exp/BF_nuevo_semillas/:
#   BF_nuevo_s<semilla>/            salidas del notebook (resumen.csv, BO_log.txt, curva_ganancia.csv, ...)
#   BF_nuevo_s<semilla>/notebook_ejecutado.ipynb   el notebook con todas sus salidas
#   BF_nuevo_s<semilla>/consola.log                salida cruda del proceso (para ver errores)
#   resumen_6_semillas.csv          una fila por semilla, con su ganancia maxima del ensamble
# y ~/buckets/b1/exp/BF_nuevo_semillas_outputs.tar.gz: todo lo anterior comprimido, para descargar
#
# Si se corta: volver a lanzar el mismo comando. Saltea las semillas que ya tienen resumen.csv.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")"

SEMILLAS=(911341 727777 773777 775777 777737 787777)
DATASETS=~/buckets/b1/datasets
EXP=~/buckets/b1/exp/BF_nuevo_semillas
URL="https://storage.googleapis.com/open-courses/dmeyf2026-9c6f/competencia_02_crudo.csv.gz"

mkdir -p "$DATASETS" "$EXP"

# ---- dataset: el notebook busca competencia_02.csv o competencia_02_crudo.csv (sin comprimir) ----
if [ ! -f "$DATASETS/competencia_02.csv" ] && [ ! -f "$DATASETS/competencia_02_crudo.csv" ]; then
  if [ ! -f "$DATASETS/competencia_02_crudo.csv.gz" ]; then
    echo "$(date '+%F %T') Descargando dataset..."
    wget -q -O "$DATASETS/competencia_02_crudo.csv.gz" "$URL" || { echo "No pude descargar el dataset"; exit 1; }
  fi
  echo "$(date '+%F %T') Descomprimiendo dataset..."
  gunzip -k "$DATASETS/competencia_02_crudo.csv.gz" || { echo "No pude descomprimir el dataset"; exit 1; }
fi

# ---- corridas ----
for sem in "${SEMILLAS[@]}"; do
  cfg="$(realpath "configs_tomasr/baseline_s${sem}.yaml")"
  dir="$EXP/BF_nuevo_s${sem}"
  mkdir -p "$dir"

  if [ -f "$dir/resumen.csv" ]; then
    echo "$(date '+%F %T') Semilla $sem ya terminada, la salteo"
    continue
  fi

  echo "$(date '+%F %T') Semilla $sem: arranca"
  export CONFIG_PATH="$cfg"
  if command -v papermill >/dev/null 2>&1; then
    # papermill graba el notebook despues de cada celda: se puede abrir mientras corre
    papermill BF_nuevo.ipynb "$dir/notebook_ejecutado.ipynb" -k ir \
      --log-output --request-save-on-cell-execute > "$dir/consola.log" 2>&1
  else
    jupyter nbconvert --to notebook --execute BF_nuevo.ipynb \
      --ExecutePreprocessor.timeout=-1 --ExecutePreprocessor.kernel_name=ir \
      --output-dir "$dir" --output notebook_ejecutado > "$dir/consola.log" 2>&1
  fi

  if [ -f "$dir/resumen.csv" ]; then
    echo "$(date '+%F %T') Semilla $sem: OK"
  else
    echo "$(date '+%F %T') Semilla $sem: FALLO (ver $dir/consola.log)"
  fi
done

# ---- resumen de las 6 semillas: una fila por semilla ----
out="$EXP/resumen_6_semillas.csv"
rm -f "$out"
for sem in "${SEMILLAS[@]}"; do
  f="$EXP/BF_nuevo_s${sem}/resumen.csv"
  [ -f "$f" ] || continue
  [ -f "$out" ] || echo "semilla_primigenia,$(head -1 "$f")" > "$out"
  echo "${sem},$(sed -n 2p "$f")" >> "$out"
done
[ -f "$out" ] && { echo; cat "$out"; echo; }

# ---- todo comprimido para descargar (sin modelito.txt, el modelo temporal de la BO) ----
TAR="$(dirname "$EXP")/BF_nuevo_semillas_outputs.tar.gz"
tar -czf "$TAR" -C "$(dirname "$EXP")" --exclude="modelito.txt" "$(basename "$EXP")"
echo "$(date '+%F %T') Fin. Para descargar: $TAR"
