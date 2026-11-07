#!/bin/bash
# ============================================================
# Preflight check para Comp2: corre esto ANTES de lanzar lane_comp2.sh.
# Chequea en segundos todo lo que nos trabo hoy, uno por uno, para
# no descubrirlo a mitad de una corrida real de horas.
#
# Uso: bash preflight.sh
# ============================================================

cd "$(dirname "$0")"
FALLAS=0

chequear () {
  if [ $2 -eq 0 ]; then
    echo "OK   - $1"
  else
    echo "FALLA - $1"
    FALLAS=$((FALLAS + 1))
  fi
}

echo "=== Preflight Comp2 ==="

# 1) R instalado
command -v Rscript > /dev/null 2>&1
chequear "Rscript disponible" $?

# 2) paquetes de R instalados
Rscript -e '
pkgs <- c("data.table","R.utils","rlist","bbotk","mlr3","mlr3mbo","mlr3learners","DiceKriging","lightgbm","yaml","paradox")
faltan <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) { cat("Faltan:", paste(faltan, collapse=", "), "\n"); quit(status = 1) }
quit(status = 0)
' > /tmp/preflight_pkgs.txt 2>&1
chequear "paquetes de R completos" $?
grep -q "Faltan" /tmp/preflight_pkgs.txt && cat /tmp/preflight_pkgs.txt

# 3) dataset presente (csv o csv.gz, procesado o crudo)
if [ -f ../datasets/competencia_02.csv ] || [ -f ../datasets/competencia_02.csv.gz ] \
   || [ -f ../datasets/competencia_02_crudo.csv ] || [ -f ../datasets/competencia_02_crudo.csv.gz ]; then
  OK_DATASET=0
else
  OK_DATASET=1
fi
chequear "dataset presente en ../datasets" $OK_DATASET

# 4) carpeta exp existe (o se puede crear)
mkdir -p ../exp 2>/dev/null
chequear "carpeta ../exp existe/creable" $?

# 5) permiso de escritura real al bucket (lee BUCKET de lane_comp2.sh)
BUCKET=$(grep -oP '(?<=BUCKET=")[^"]+' lane_comp2.sh)
if [ -z "$BUCKET" ]; then
  chequear "bucket detectado en lane_comp2.sh" 1
else
  echo "preflight" > /tmp/preflight_test.txt
  gsutil cp /tmp/preflight_test.txt "$BUCKET/preflight_test.txt" > /tmp/preflight_gs.txt 2>&1
  chequear "escritura al bucket ($BUCKET)" $?
  gsutil rm "$BUCKET/preflight_test.txt" > /dev/null 2>&1
fi

# 6) memoria disponible (solo informativo, no bloquea)
echo "--- memoria disponible ---"
free -h | grep Mem

echo "========================="
if [ $FALLAS -eq 0 ]; then
  echo "TODO OK - listo para correr lane_comp2.sh"
else
  echo "$FALLAS problema(s) encontrados - resolver antes de lanzar la cadena real"
fi
