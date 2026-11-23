# ---- celda 1 ----
# instala solo lo que falta (la primera vez puede tardar)
paquetes <- c("data.table", "R.utils", "rlist", "rlang", "unix", "primes", "bbotk", "mlr3", "mlr3mbo", "mlr3learners", "DiceKriging", "lightgbm")
if (Sys.info()[["sysname"]] != "Linux") paquetes <- setdiff(paquetes, "unix")  # unix (limite de RAM) solo se usa en Linux
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)

# ---- celda 2 ----
# limpio la memoria
rm(list = ls(all.names = TRUE)) # remove all objects
gc(full = TRUE, verbose = FALSE) # garbage collection

library(data.table)
library(R.utils)
library(rlist)
library(rlang)
# el limite de RAM (solo Linux) usa unix::rlimit_as(), sin library()
library(primes)
library(bbotk)
library(mlr3)
library(mlr3mbo)
library(mlr3learners)
# library(paradox)
library(DiceKriging)
library(lightgbm)

RNGkind("L'Ecuyer-CMRG") # generador de la plantilla, fijo para todo el script
options(scipen = 999)

# ---- celda 3 ----
if( !exists("envg") ) envg <- env()  # global environment 
envg$interrupcion <- FALSE

# ---- celda 4 ----
# Inteligencia atrapar  Aborts

options(
interrupt = function() {
  cat( "interrupcion")
  envg$interrupcion <- TRUE
  cat( "\n",
   file = "z-Rinterrupt.txt",
   append = TRUE
  )
},

error = function() {
  traceback(20)
  options(error = NULL)

  cat( "\n",
   file = "z-Roptionerror.txt",
   append = TRUE
  )
  
  if( envg$interrupcion == FALSE )
  {
    t <- format(Sys.time(), "%Y%m%d %H%M%S")
    cat( t, "\n",
      file = "z-Rabort.txt",
      append = TRUE
    )

    arch <- "z-Rcanresume.txt"
    if( file.exists( arch ) )  file.remove( arch )
  }

  #stop("exiting after script error")
}
)

# ---- celda 5 ----
notificar <- function( mensaje ) {
  system( paste0( "curl -d ", '"', mensaje, '"', " ",  PARAM$notify ), intern=TRUE )
}

# ---- celda 6 ----
# Limitar la memoria RAM
# para detectar con claridad cuando se cae el programa por RAM insuficiwente

action_abortar <- function( mensaje ){

  t0 <- format(Sys.time(), "%Y%m%d %H%M%S")
  cat( t0, "\n",
       file = "z-Rabort.txt",
       append = TRUE
  )

  arch <- "z-Rcanresume.txt"
  if( file.exists( arch ) )  file.remove( arch )

  stop( paste0("Abortando, " , mensaje ) )
}

action_limitar_memoria <- function( GB_min = 4 ) {

  MemTotal <- as.numeric(system("awk '/MemTotal/ {print $2}' /proc/meminfo", intern=TRUE))
  MemTotal <- as.integer( MemTotal/ 1024 - GB_min*1024 )
  if( MemTotal < 0 )  action_abortar( " No hay suficiente RAM para trabajar (min 4GB ) " )
  unix::rlimit_as(MemTotal * 1024^2)  # limite de memoria virtual en bytes; MemTotal esta en MiB
}

if (Sys.info()[["sysname"]] == "Linux") action_limitar_memoria( 4 )  # 4 GB para el OS; requiere /proc/meminfo

# ---- celda 7 ----
t_inicio_total <- Sys.time()
tiempos <- list()
marcar_tiempo <- function(etapa, t_desde) {
  dt <- as.numeric(difftime(Sys.time(), t_desde, units = "mins"))
  tiempos[[etapa]] <<- dt
  cat(sprintf("[tiempo] %s: %.1f min\n", etapa, dt))
  invisible(Sys.time())
}


# ---- celda 8 ----
bitacora <- function( st, arch= "bitacora.txt", verbose= TRUE ) {
  t0 <- Sys.time()
  MemLibre <- as.numeric(system("awk '/MemFree/ {print $2}' /proc/meminfo", intern=TRUE)) / (1024*1024)
  
  if (!file.exists(arch))  {
    # Escribo los titulos
    linea <- "fecha\tmemLibre\tmensaje\n"
    cat(linea, file= arch)
  }

  # escribo el registro
  linea <- paste0(
    format(t0, "%Y%m%d.%H%M%S"), "\t",     # la fecha y hora
    round(MemLibre,1), "\t",
    st, "\n")

  cat(linea, file= arch, append= TRUE)  # grabo al archivo

  if (verbose) cat(linea)   # imprimo por pantalla
}

# ---- celda 9 ----
# Leer el archivo de configuración.
config <- yaml::read_yaml("config_15B.yaml",  eval.expr = TRUE)


# ---- argumentos de linea de comandos: brazo y semilla primigenia ----
# uso: Rscript Exp_15B_VM.R <brazo> <semilla_primigenia>
# sin argumentos se usan los valores del config (brazo baseline)
brazos_validos <- c("baseline", "lineal_azar", "lineal_invertido", "exp_azar", "exp_invertido")
args <- commandArgs(trailingOnly = TRUE)
brazo <- if (length(args) >= 1) args[1] else "baseline"
if (!brazo %in% brazos_validos) stop("Brazo desconocido: ", brazo)
if (brazo != "baseline") stop("El brazo ", brazo, " todavia no esta implementado")
if (length(args) >= 2) {
  config$training$semilla_primigenia <- as.integer(args[2])
  config$bayesian$exp_name <- paste0("15B_", brazo, "_", args[2])
}
config$brazo <- brazo


# ---- celda 10 ----
PARAM <- list()
#directorios
# PARAM$data_dir <- config$directorios$datasets
# PARAM$exp_dir  <- config$directorios$exp

# LEEMOS DIRECCIONES RELATIVAS Y HACEMOS ABOLUTAS PARA EVITAR PROBLEMAS CON LOS "setwd()" en adelante.
PARAM$data_dir <- normalizePath(
  config$directorios$datasets, mustWork = TRUE
)
PARAM$exp_dir <- normalizePath(
  config$directorios$exp, mustWork = TRUE
)

# training y future
PARAM$semillas <- config$training$semillas
PARAM$semilla_primigenia <- config$training$semilla_primigenia
PARAM$training_pct <- config$training$training_pct
PARAM$train <- config$training$train
PARAM$validate <- config$training$validate
PARAM$train_final <- config$training$train_final
PARAM$future <-  config$training$future
PARAM$cortes <- config$training$cortes 
PARAM$trainingstrategy$undersampling <- config$training$undersampling

# diapositiva: ksemillerio 1, repe 1, iteraciones 10
PARAM$hyperparametertuning$kmaldicion <- config$bayesian$kmaldicion      # se va a quedar con el menor
PARAM$hyperparametertuning$ksemillerio <- config$bayesian$ksemillerio    # con 1 y 1 hay una sola particion y una sola semilla en la busqueda
PARAM$hyperparametertuning$repe <- config$bayesian$repe
PARAM$hyperparametertuning$iteraciones <-config$bayesian$iteraciones      # iteraciones bayesianas
PARAM$hyperparametertuning$init <- config$bayesian$init                   # diseno inicial de mlr3mbo (4 x 3 hiperparametros), no cuenta como iteracion

PARAM$notify <- config$notify

# ---- celda 11 ----
PARAM

# ---- celda 12 ----
# chequeamos q existan directorios
if (!dir.exists(PARAM$data_dir)) {
  stop("No existe el directorio de datasets: ", PARAM$data_dir)
}

if (!dir.exists(PARAM$exp_dir)) {
  stop("No existe el directorio de experimentos: ", PARAM$exp_dir)
}

# ---- celda 13 ----
PARAM$experimento <-config$bayesian$exp_name

# ---- celda 14 ----
# diapositiva: produccion con 10 semillas
PARAM$semillas_finales_n <- config$training$semillas_finales  

# ---- celda 15 ----
# Parametros LightGBM

# parametros fijos del LightGBM que se pisaran con la parte variable de la BO
PARAM$lgbm$param_fijos <- config$lgbm$fijos

# ---- celda 16 ----
# # Aqui se cargan los bordes de los hiperparametros de la BO

# # SEGUN BASELINE
# PARAM$hypeparametertuning$hs <- ps(
#   num_iterations = p_int(lower = 64L, upper = 4096L),
#   num_leaves = p_int(lower = 16L, upper = 2048L),
#   min_sum_hessian_in_leaf = p_dbl(lower = 1e-06, upper = 0.1)
# )
# PARAM$hypeparametertuning$hs

# ---- celda 17 ----
# Aqui se cargan los bordes de los hiperparametros de la BO

# Construir el espacio usando todas las entradas de bayesian$hs.
PARAM$hypeparametertuning$hs <- do.call(
  paradox::ps,
  config$lgbm$hs
)
# PARAM$hypeparametertuning$hs2 

# ---- celda 18 ----
# particionar agrega una columna llamada fold a un dataset
#   que consiste en una particion estratificada segun agrupa
# particionar( data=dataset, division=c(70,30),
#  agrupa=clase_ternaria, seed=semilla)   crea una particion 70, 30

particionar <- function(data, division, agrupa = "", campo = "fold", start = 1, seed = NA) {
  if (!is.na(seed)) set.seed(seed, "L'Ecuyer-CMRG")

  bloque <- unlist(mapply(
    function(x, y) {rep(y, x)}, division, seq(from = start, length.out = length(division))))

  data[, (campo) := sample(rep(bloque, ceiling(.N / length(bloque))))[1:.N], by = agrupa]
}

# ---- celda 19 ----
# logueo al archivo BO_log.txt
loguear <- function(preg, arch = NA, verbose = TRUE)
{
  t0 <- Sys.time()
  reg <- copy(preg)
  if ("feature_contri" %in% names(reg)) {
    reg$feature_contri <- reg$feature_contri[1]
  }
  archivo <- arch
  if (is.na(arch)) archivo <- paste0(folder, substitute(reg), ext)


  if (!file.exists(archivo))
  {
    # Escribo los titulos
    linea <- paste0("fecha\t",
                    paste(list.names(reg), collapse = "\t"), "\n")

    cat(linea, file = archivo)
  }

  # escribo el registro
  linea <- paste0(format(t0, "%Y%m%d.%H%M%S"), "\t",     # la fecha y hora
                  gsub(", ", "\t", toString(reg)), "\n")

  cat(linea, file = archivo, append = TRUE)  # grabo al archivo

  if (verbose) cat(linea)   # imprimo por pantalla
}

# ---- celda 20 ----
# PARAM$data_dir <- "~/buckets/b1/datasets"  # gustavo
archivo_crudo    <- file.path(PARAM$data_dir, "competencia_02_crudo.csv")
archivo_ternaria <- file.path(PARAM$data_dir, "competencia_02.csv")

if (!file.exists(archivo_ternaria)) {
  if (!file.exists(archivo_crudo)) stop("No encuentro ni competencia_02.csv ni competencia_02_crudo.csv en ", PARAM$data_dir)

  dataset <- fread(archivo_crudo)

  # calculo el periodo0 consecutivo
  dsimple <- dataset[, list(
    "pos" = .I,
    numero_de_cliente,
    periodo0 = as.integer(foto_mes / 100) * 12 + foto_mes %% 100)]

  # ordeno
  setorder(dsimple, numero_de_cliente, periodo0)

  # calculo topes
  periodo_ultimo <- dsimple[, max(periodo0)]
  periodo_anteultimo <- periodo_ultimo - 1

  # calculo los leads de orden 1 y 2
  dsimple[, c("periodo1", "periodo2") :=
    shift(periodo0, n = 1:2, fill = NA, type = "lead"), numero_de_cliente]

  # assign most common class values = "CONTINUA"
  dsimple[periodo0 < periodo_anteultimo, clase_ternaria := "CONTINUA"]

  # calculo BAJA+1
  dsimple[periodo0 < periodo_ultimo &
    (is.na(periodo1) | periodo0 + 1 < periodo1),
    clase_ternaria := "BAJA+1"]

  # calculo BAJA+2
  dsimple[periodo0 < periodo_anteultimo & (periodo0 + 1 == periodo1)
    & (is.na(periodo2) | periodo0 + 2 < periodo2),
    clase_ternaria := "BAJA+2"]

  # pego el resultado en el dataset original y grabo
  setorder(dsimple, pos)
  dataset[, clase_ternaria := dsimple$clase_ternaria]
  fwrite(dataset, file = archivo_ternaria, sep = ",")
  rm(dataset, dsimple); gc()
}
cat("Uso:", archivo_ternaria, "\n")


# ---- celda 21 ----
# dataset <- fread(archivo_ternaria, stringsAsFactors = TRUE)
# sort(unique(dataset$foto_mes))

# ---- celda 22 ----
# carpeta de trabajo
dir.create(file.path(PARAM$exp_dir, PARAM$experimento), showWarnings = FALSE, recursive = TRUE)
setwd(file.path(PARAM$exp_dir, PARAM$experimento))

# lectura del dataset (solo hasta el mes del future: no hace falta mas)
dataset <- fread(archivo_ternaria, stringsAsFactors = TRUE)
dataset <- dataset[foto_mes <= max(PARAM$future)]
stopifnot("clase_ternaria" %in% colnames(dataset))
setorder(dataset, numero_de_cliente, foto_mes)
cat("Meses:", paste(sort(unique(dataset$foto_mes)), collapse = ", "), "|", nrow(dataset), "filas x", ncol(dataset), "columnas\n")
bitacora("Dataset lectura")

# ---- celda 23 ----
# campos_excluidos <- c("numero_de_cliente", "foto_mes", "clase_ternaria")
campos_excluidos <- config$training$campos_excluidos
campos_dq <- setdiff(colnames(dataset), campos_excluidos)
campos_dq <- campos_dq[sapply(dataset[, ..campos_dq], is.numeric)]

correcciones <- list()
for (mes in sort(unique(dataset$foto_mes))) {
  filas <- which(dataset$foto_mes == mes)
  for (campo in campos_dq) {
    x <- dataset[[campo]][filas]
    if (!anyNA(x) && all(x == 0)) {
      set(dataset, i = filas, j = campo, value = NA)
      correcciones[[length(correcciones) + 1]] <- data.table(foto_mes = mes, variable = campo, filas = length(filas))
    }
  }
}
correcciones <- rbindlist(correcciones)
cat("Variables pasadas a NA por mes:", nrow(correcciones), "\n")
if (nrow(correcciones) > 0) {
  print(correcciones)
  fwrite(correcciones, "data_quality_correcciones.csv")
}

bitacora("Data Quality")

# ---- celda 24 ----
getwd()

# ---- celda 25 ----
bitacora("Feature Engineering Historico START")
campos_lag <- setdiff(colnames(dataset), campos_excluidos)
campos_lag <- campos_lag[sapply(dataset[, ..campos_lag], is.numeric)]
cat("Lags y deltas para", length(campos_lag), "variables\n")

t0 <- Sys.time()
dataset[, (paste0(campos_lag, "_lag1")) := shift(.SD, n = 1, fill = NA, type = "lag"), by = numero_de_cliente, .SDcols = campos_lag]
dataset[, (paste0(campos_lag, "_lag2")) := shift(.SD, n = 2, fill = NA, type = "lag"), by = numero_de_cliente, .SDcols = campos_lag]
for (campo in campos_lag) {
  dataset[, paste0(campo, "_delta1") := get(campo) - get(paste0(campo, "_lag1"))]
  dataset[, paste0(campo, "_delta2") := get(campo) - get(paste0(campo, "_lag2"))]
}
cat("Listo en", round(as.numeric(Sys.time() - t0, units = "secs"), 1), "seg |", ncol(dataset), "columnas\n")

bitacora("Feature Engineering Historico END")

# ---- celda 26 ----
# clase01: BAJA+1 y BAJA+2 son 1, CONTINUA es 0
dataset[, clase01 := ifelse(clase_ternaria %in% c("BAJA+2", "BAJA+1"), 1L, 0L)]

# stopifnot(identical(sort(PARAM$train), sort(PARAM$train_final)))
dataset_train <- dataset[foto_mes %in% PARAM$train]
dfuture <- dataset[foto_mes %in% PARAM$future]   # datos del futuro, para aplicar el modelo
rm(dataset); gc(full = TRUE, verbose = FALSE)

dataset_train[, .N, list(foto_mes, clase_ternaria)]

# ---- celda 27 ----
particionar(dataset_train,
  division = c(PARAM$training_pct, 100L - PARAM$training_pct),
  agrupa = "clase_ternaria",
  seed = PARAM$semilla_primigenia # aqui se usa SU semilla
)

# ---- celda 28 ----
# defino los datos que forma parte del training
# aqui se hace el undersampling de los CONTINUA
# notar que para esto utilizo la SEGUNDA semilla

set.seed(PARAM$semilla_primigenia, kind = "L'Ecuyer-CMRG")
dataset_train[, azar := runif(nrow(dataset_train))]
dataset_train[, training := 0L]

dataset_train[
  foto_mes %in% PARAM$train & fold == 1 &
    (azar <= PARAM$trainingstrategy$undersampling | clase_ternaria %in% c("BAJA+1", "BAJA+2")),
  training := 1L
]

# ---- celda 29 ----
# los campos que se van a utilizar

campos_buenos <- setdiff(
  colnames(dataset_train),
  c("clase_ternaria", "clase01", "fold", "azar", "training")
)
cat("Columnas para entrenar:", length(campos_buenos), "(la diapositiva dice 762)\n")

# ---- celda 30 ----
validate_matrix <- data.matrix(dataset_train[fold == 2L, campos_buenos, with = FALSE])

# ---- celda 31 ----
bitacora("Training meses")

# ---- celda 32 ----
# Cada corrida de la BO arranca con un log limpio:
# si ya existe BO_log.txt, se archiva con fecha y hora en el nombre
giter <- 0

if (file.exists("BO_log.txt")) {
  archivo_viejo <- paste0("BO_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt")
  file.rename("BO_log.txt", archivo_viejo)
  cat("BO_log.txt anterior archivado como", archivo_viejo, "\n")
}

# ---- celda 33 ----
# genero numeros primos
primos <- generate_primes(min = 100000, max = 1000000)

set.seed(PARAM$semilla_primigenia, kind= "L'Ecuyer-CMRG")  # inicializo con mi primer semilla

# me quedo con por ejemplo 50 primos al azar
sem_qty <- PARAM$hyperparametertuning$kmaldicion * PARAM$hyperparametertuning$ksemillerio
PARAM$semillas_BO <- sample(primos, sem_qty)
PARAM$semillas_BO
bitacora("Bayesian Optimization semillas")

# ---- celda 34 ----
# En el argumento x llegan los parametros de la bayesiana

Estimar_lightgbm_one <- function(xs, subiter, semillas_local) {

  # x pisa (o agrega) a param_fijos
  param_completo <- modifyList(PARAM$lgbm$param_fijos, xs)
  xx <- copy(param_completo)

  tb_pred <- copy( dvalidate[, list( "clase01"= as.numeric(clase01) )])
  tb_pred[, prob:= 0.0 ]
  
  kpi <- list()
  kpi$arb_real <- c()
  kpi$hojas_total <- c()
  kpi$vhojas <- list()

  for( isem in seq_along(semillas_local)) {
    
    sem <- semillas_local[isem]
    param_completo$seed <- sem
    # entreno LightGBM
    modelo <- lgb.train(
      data= dtrain,
      param= param_completo,
      serializable= FALSE   # evita armar el modelo como un string unico (limite 2^31-1 bytes de R)
    )

    # Topologia del arbol
    lgb.save( modelo, file= "modelito.txt")
    kpi$res <- system( paste0( "grep leaf_value ", "modelito.txt",  " | wc" ), intern=TRUE )
    kpi$res1 <- strsplit( trimws(gsub("\\s+", " ", kpi$res)), " " )
    kpi$arb_real <- c( kpi$arb_real, as.integer( kpi$res1[[1]][1] ) )
    kpi$hojas_total <- c( kpi$hojas_total, as.integer( kpi$res1[[1]][2] ) )
    kpi$res2 <- system( "grep leaf_value modelito.txt | awk '{print NF}' " , intern=TRUE )
    kpi$vhojas[[isem]] <- unlist( as.integer( strsplit( trimws(gsub("\\s+", " ", kpi$res2)), " " ) ))

    # aplico a los datos de validacion
    prediccion <- predict(
      object= modelo,
      newdata= validate_matrix,
      num_iteration= param_completo$num_iterations
    )

    tb_pred[, prob:= prob + prediccion ]  # acumulo semillerio
  }

  # Calculo de AUC del semillerio
  setorder( tb_pred, -prob)
  tb_pred[, pos_acum := cumsum(clase01)]
  area <- tb_pred[ clase01==0, sum(pos_acum)]
  AUC <- (area / tb_pred[ clase01==0, .N ] ) / tb_pred[ clase01==0, max(pos_acum) ] 


  # obtengo la metrica (AUC en validacion)
  xx$columnas <- ncol(dtrain)
  xx$registros <- nrow(dtrain)
  xx$validate <- nrow(validate_matrix)

  xx$ksemillerio <- length( semillas_local )
  xx$arbolitos <- mean(kpi$arb_real)
  xx$hojas_min <-  mean(unlist(lapply(kpi$vhojas,min)))
  xx$hojas_mean <- mean(unlist(lapply(kpi$vhojas,mean)))
  xx$hojas_max <- mean(unlist(lapply(kpi$vhojas,max)))
  xx$hojas_total <- sum(kpi$hojas_total)

  xx$subiter <- subiter
  xx$iter <- giter
  xx$metrica <- AUC

  return(xx)
}

# ---- celda 35 ----
Estimar_lightgbm <- function(xs) {

  flush.console()
  giter <<- giter + 1

  semillas_local <- PARAM$semillas_BO[ seq(PARAM$hyperparametertuning$ksemillerio) ]
  res1 <- Estimar_lightgbm_one( xs, 1, semillas_local)

  cat( res1$metrica, "\t" )
  if( res1$metrica > GLOBAL_metrica_mayor & 
      PARAM$hyperparametertuning$kmaldicion > 1 ) {
      
    menor <- res1$metrica
    for( i in 2:PARAM$hyperparametertuning$kmaldicion ) {
      
      desde <- PARAM$hyperparametertuning$ksemillerio * (i-1) + 1
      hasta <- desde + PARAM$hyperparametertuning$ksemillerio  - 1
      semillas_local <- PARAM$semillas_BO[ desde:hasta ]
      
      res <- Estimar_lightgbm_one( xs, i, semillas_local)
      cat( res$metrica, "\t" )
      if( res$metrica < menor ) {
          menor <- res$metrica
          res1 <- copy( res )
      }
    }
  }
  cat( "\n" )

  if( res1$metrica  > GLOBAL_metrica_mayor )  GLOBAL_metrica_mayor <<-  res1$metrica

  loguear(res1, "BO_log.txt")
  bitacora(paste0("Bayesian Optimization  iter= ", res1$iter ) )
  set.seed(PARAM$semilla_primigenia, kind= "L'Ecuyer-CMRG")  # le reordeno a mlr3MBO
  return( list( metrica = res1$metrica) )
}

# ---- celda 36 ----
# dejo los datos de training en el formato que necesita LightGBM

dtrain <- lgb.Dataset(
  data = data.matrix(dataset_train[training == 1L, campos_buenos, with = FALSE]),
  label = dataset_train[training == 1L, clase01],
  free_raw_data = FALSE
)

nrow(dtrain)
ncol(dtrain)
gc(full= TRUE, verbose= FALSE)
bitacora("dtrain creado")

# ---- celda 37 ----
dvalidate <- dataset_train[fold == 2L]
validate_matrix <- data.matrix(dataset_train[fold == 2L, campos_buenos, with = FALSE])
gc(full= TRUE, verbose= FALSE)
bitacora("validate_matrix creada")

# ---- celda 38 ----
t0_bo <- Sys.time()

# Aqui comienza la configuracion de la Bayesian Optimization

# en este archivo quedan la evolucion binaria de la BO
kbayesiana <- "bayesiana.RDATA"

funcion_optimizar <- Estimar_lightgbm # la funcion que voy a maximizar

objective <- ObjectiveRFun$new(
  fun = funcion_optimizar,
  domain = PARAM$hypeparametertuning$hs,
  codomain = ps(metrica = p_dbl(tags = "maximize")),
  id = "BO_lightgbm"
)


# diseno inicial (12) + iteraciones bayesianas (10) = 22 evaluaciones
instance <- OptimInstanceBatchSingleCrit$new(
  objective = objective,
  terminator = trm("evals", n_evals = PARAM$hyperparametertuning$init + PARAM$hyperparametertuning$iteraciones)
)


surrogate <- srlrn(lrn("regr.km",
  optim.method = "BFGS",
  nugget.estim = TRUE,
  control = list(trace = FALSE)))

acq_function <- acqf("ei")                 # expected improvement

acq_optimizer <- acqo(
  optimizer = opt("random_search", batch_size = 1000),
  terminator = trm("evals", n_evals = 1000)
)

optimizer <- opt("mbo",
  loop_function = bayesopt_ego,
  surrogate = surrogate,
  acq_function = acq_function,
  acq_optimizer = acq_optimizer
)

bitacora("Bayesian Optimization configured")

# ---- celda 39 ----
bitacora("Bayesian Optimization START")
GLOBAL_metrica_mayor <- -Inf
bayesiana_salida <- optimizer$optimize(instance)
bitacora("Bayesian Optimization END")

# ---- celda 40 ----
# control: deben ser init + iteraciones evaluaciones (22)
cat("Evaluaciones de la BO:", nrow(instance$archive$data),
    "| esperadas:", PARAM$hyperparametertuning$init + PARAM$hyperparametertuning$iteraciones, "\n")

marcar_tiempo("bayesiana", t0_bo)


# ---- celda 41 ----
# cargo los mejores hiperparametros, que son los de mayor metrica
tb_bayesiana <- fread("BO_log.txt")
# control: el log tiene que tener solo las evaluaciones de esta corrida (init + iteraciones)
stopifnot(nrow(tb_bayesiana) == PARAM$hyperparametertuning$init + PARAM$hyperparametertuning$iteraciones)
setorder(tb_bayesiana, -metrica)
PARAM$out$lgbm$mejores_hiperparametros <- as.list(tb_bayesiana[1])

param_final <- modifyList(PARAM$lgbm$param_fijos,
  PARAM$out$lgbm$mejores_hiperparametros)

# libero la memoria de la BO
rm(dtrain, dvalidate,validate_matrix); gc(full = TRUE, verbose = FALSE)

print(tb_bayesiana[1, list(num_iterations, num_leaves, min_sum_hessian_in_leaf, auc_validacion = metrica)])
bitacora("Final Training housekeeping")

# ---- celda 42 ----
# genero numeros primos
primos <- generate_primes(min = 100000, max = 1000000)

set.seed(PARAM$semilla_primigenia, kind= "L'Ecuyer-CMRG")  # inicializo con mi primer semilla

# me quedo con por ejemplo 50 primos al azar
PARAM$semillas_final <- sample(primos, PARAM$semillas_finales_n)
PARAM$semillas_final
bitacora("Final Training semillas")

# ---- celda 43 ----
bitacora("Final Training START")
X_future <- data.matrix(dfuture[, campos_buenos, with = FALSE])
prob_semillas <- matrix(NA_real_, nrow = nrow(X_future), ncol = length(PARAM$semillas_final))

t0_prod <- Sys.time()
#lista_importancia <- list()
tiempos_semillas <- list()

set.seed(PARAM$semilla_primigenia, kind= "L'Ecuyer-CMRG")  # inicializo con mi primer semilla
dataset_train[, azar := runif(.N)]
dataset_train_sample <- dataset_train[
  azar <= PARAM$trainingstrategy$undersampling | clase_ternaria %in% c("BAJA+1", "BAJA+2")
]

dtrain_final <- lgb.Dataset(
  data= data.matrix(dataset_train_sample[, campos_buenos, with = FALSE]),
  label= dataset_train_sample[, clase01]
)


for (j in seq_along(PARAM$semillas_final)) {
  sem <- PARAM$semillas_final[j]
  t1 <- Sys.time()

  param_semilla <- param_final
  param_semilla$seed <- sem

  modelo_final <- lgb.train(
    data= dtrain_final,
    param= param_semilla,
    serializable= FALSE   # evita armar el modelo como un string unico (limite 2^31-1 bytes de R)
  )

  #imp <- lgb.importance(modelo_final)
  #imp[, semilla := sem]
  #lista_importancia[[j]] <- imp


  # aplico el modelo a los datos del futuro
  prob_semillas[, j] <- predict(modelo_final, X_future)
  rm(modelo_final); gc(verbose = FALSE)
  dt_semilla <- round(as.numeric(Sys.time() - t1, units = "mins"), 2)
  tiempos_semillas[[j]] <- data.table(semilla = sem, minutos = dt_semilla)
  cat("Semilla", sem, "lista en", dt_semilla, "min\n")
  bitacora(paste0("Final Training  iter= ", j ) )
}

prob_final <- rowMeans(prob_semillas)
saveRDS(prob_semillas, "prob_202106_por_semilla.rds")

#tb_importancia <- rbindlist(lista_importancia)
#tb_importancia_prom <- tb_importancia[, list(
  #Gain_prom = mean(Gain), Gain_sd = sd(Gain),
  #Cover_prom = mean(Cover), Frequency_prom = mean(Frequency)
#), by = Feature]

#setorder(tb_importancia_prom, -Gain_prom)
#fwrite(tb_importancia, "feature_importance_por_semilla.csv")
#fwrite(tb_importancia_prom, "feature_importance_promedio.csv")
fwrite(rbindlist(tiempos_semillas), "tiempos_por_semilla.csv")
marcar_tiempo("produccion_semillerio", t0_prod)
bitacora("Final Training END")

# ---- celda 44 ----
auc_rank <- function(y, p) {
  r <- frank(p, ties.method = "average")
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# ganancia de cada cliente del future (en el orden de dfuture)
gan_cliente <- ifelse(dfuture$clase_ternaria == "BAJA+2", 1072500, -27500)

# ganancia maxima de cada semilla, para ver la variabilidad
gan_max_semilla <- sapply(seq_along(PARAM$semillas_final), function(j) max(cumsum(gan_cliente[order(-prob_semillas[, j])])))

# calculo la ganancia en los datos del futuro para todos los cortes (ensamble de las semillas)
tb_prediccion <- dfuture[, list(numero_de_cliente, foto_mes, clase_ternaria)]
tb_prediccion[, prob := prob_final]
tb_prediccion[, gan := ifelse(clase_ternaria == "BAJA+2", 1072500, -27500)]
auc_test <- auc_rank(dfuture$clase01, prob_final)

setorder(tb_prediccion, -prob)
tb_prediccion[, ganancia_acumulada := cumsum(gan)]
tb_prediccion[, gan_suave := frollmean(ganancia_acumulada, n=1001, align="center", na.rm=TRUE)]
tb_prediccion[, pos := sequence(.N)]

# ganancia_max <- tb_prediccion[, max(ganancia_acumulada)]
ganancia_max <- tb_prediccion[, max(gan_suave, na.rm=TRUE)]
envios_max <- tb_prediccion[which.max(gan_suave), pos]

cat("\n================ BASELINE: train 202103+202104, test 202106 ================\n")
cat("Columnas para entrenar:        ", length(campos_buenos), "\n")
cat("AUC en validacion (BO):        ", round(tb_bayesiana[1, metrica], 5), "\n")
cat("AUC en 202106 (ensamble):      ", round(auc_test, 5), "(target BAJA+1 y BAJA+2)\n")
cat("Mejores hiperparametros:        num_iterations =", tb_bayesiana[1, num_iterations],
    "| num_leaves =", tb_bayesiana[1, num_leaves],
    "| min_sum_hessian_in_leaf =", signif(tb_bayesiana[1, min_sum_hessian_in_leaf], 4), "\n")
cat("GANANCIA MAXIMA SUAVE (ensamble):    ", format(ganancia_max, big.mark = ".", scientific = FALSE), "\n")
cat("CANTIDAD DE ENVIOS (maximo):   ", envios_max, "\n")
cat("Ganancia maxima por semilla:    media", format(round(mean(gan_max_semilla)), big.mark = ".", scientific = FALSE),
    "| desvio", format(round(sd(gan_max_semilla)), big.mark = ".", scientific = FALSE), "\n")

notificar( ganancia_max ) # instalar app  nty en el movil, suscribirse al canal  germancito
bitacora("Final Training Resultados Reportar")

# ---- celda 45 ----
# ganancia en los cortes de la plantilla y en el maximo
envios <- sort(unique(c(PARAM$cortes, envios_max)))
tabla_gan <- data.table(
  envios = envios,
  ganancia = sapply(envios, function(e) tb_prediccion[1:e, sum(gan)])
)
tabla_gan[, ganancia_M := ganancia / 1e6]
tabla_gan[, es_el_maximo := envios == envios_max]
print(tabla_gan)

fwrite(tabla_gan, "ganancia_por_envios.csv")
fwrite(tb_prediccion[, list(pos, prob, gan, ganancia_acumulada)], "curva_ganancia.csv")
fwrite(data.table(
  columnas = length(campos_buenos), auc_validacion_BO = tb_bayesiana[1, metrica], auc_202106 = auc_test,
  num_iterations = tb_bayesiana[1, num_iterations], num_leaves = tb_bayesiana[1, num_leaves],
  min_sum_hessian_in_leaf = tb_bayesiana[1, min_sum_hessian_in_leaf],
  ganancia_maxima = ganancia_max, envios_en_el_maximo = envios_max), "resumen.csv")
cat("\nArchivos guardados en", getwd(), "\n")

marcar_tiempo("TOTAL", t_inicio_total)
tiempos_tb <- data.table(etapa = names(tiempos), minutos = round(unlist(tiempos), 2))
fwrite(tiempos_tb, "tiempos_ejecucion.csv")
print(tiempos_tb)
bitacora("Final Training Resultados Cortes")

# ---- celda 46 ----
plot(tb_prediccion$pos, tb_prediccion$ganancia_acumulada / 1e6, type = "l", lwd = 2, col = "#0F7B6C",
     xlab = "Cantidad de envios", ylab = "Ganancia (millones)", main = "Baseline: curva de ganancia en 202106")
abline(v = envios_max, lty = 2, col = "#D9822B")
legend("bottomright", legend = paste0("maximo: ", round(ganancia_max / 1e6, 1), " M con ", envios_max, " envios"), bty = "n")

# ---- celda 47 ----
# Tabla de referencia: ganancia en cortes FIJOS (ensamble y por semilla) en 202106
cortes_ref <- sort(unique(c(PARAM$cortes, 10600, 12000)))

# ganancia acumulada de cada semilla (filas = ranking, columnas = semillas)
gan_acum_semilla <- sapply(seq_along(PARAM$semillas_final), function(j) {
  cumsum(gan_cliente[order(-prob_semillas[, j])])
})

tabla_ref <- data.table(
  envios            = cortes_ref,
  ensamble_M        = tb_prediccion$ganancia_acumulada[cortes_ref] / 1e6,
  semilla_media_M   = sapply(cortes_ref, function(e) mean(gan_acum_semilla[e, ])) / 1e6,
  semilla_sd_M      = sapply(cortes_ref, function(e) sd(gan_acum_semilla[e, ])) / 1e6,
  semilla_min_M     = sapply(cortes_ref, function(e) min(gan_acum_semilla[e, ])) / 1e6,
  semilla_max_M     = sapply(cortes_ref, function(e) max(gan_acum_semilla[e, ])) / 1e6
)

# rango de envios donde el ensamble queda a menos de 1 desvio por semilla del maximo
sd_ref <- mean(tabla_ref$semilla_sd_M)
max_ens <- max(tb_prediccion$ganancia_acumulada) / 1e6
cat("Maximo del ensamble:", round(max_ens, 2), "M | desvio medio por semilla:", round(sd_ref, 2), "M\n")
cat("Cortes a menos de 1 desvio del maximo:",
    paste(tabla_ref[ensamble_M >= max_ens - sd_ref, envios], collapse = ", "), "\n\n")

print(tabla_ref[, lapply(.SD, round, 2), .SDcols = names(tabla_ref)])
fwrite(tabla_ref, "tabla_referencia_cortes_fijos.csv")

# ---- celda 48 ----
bitacora("Fin")

# ---- celda 49 ----
