# Experimentos Colaborativos — DMEyF 2026

> **Tema #15:** Ponderación temporal del entrenamiento (*sample weighting / time decay*) frente al peso uniforme.  
> **Comisión:** Jueves — Maestría en Data Mining (UBA).  
> **Equipo — Grupo B (2B, postura antagónica):** Fray Campos - Verónica Ester Monzón  

---

## 1. Enlaces y Recursos Oficiales

* **PDF oficial de la cursada:** [DMEyF 2026 PDF](https://storage.googleapis.com/open-courses/dmeyf2026-9c6f/DMEyF_2026.pdf) — pp. 12 (rúbrica general) y pp. 45–52 (consignas de diseño experimental, preinscripción y exposiciones).
* **GitHub colaborativo:** [germandasr/DMEyF_Exp_Colaborativos](https://github.com/germandasr/DMEyF_Exp_Colaborativos) (baseline compartido en `BF_nuevo.ipynb` + `config_nuevo.yaml` y `BASELINE_FINAL.ipynb` quedo viejo).
* **Bitácora de la cátedra:** `experimentos_colaborativos_bitacora_2026.pptx`.
* **Nuestra presentación (Grupo B):** [experimentos_colaborativos_campos_monzon (Google Slides)](https://docs.google.com/presentation/d/1Ht9rjh2ypUyzs9tYzkwG9omHKbGZOG3W/edit?usp=sharing).

---

## 2. Cronograma e Hitos

| Fecha | Instancia | Formato / Requisitos |
| :--- | :--- | :--- |
| **Jue 29-oct-2026** | **Inscripción y selección de tema** | Registro de pareja y tema antagónico en la planilla compartida. |
| **Jue 05-nov-2026** | **Presentación Preliminar (Hito 1)** | Presencial (Cero+Infinito). **3 minutos por grupo**. Solo el diseño metodológico, en el Google Slides compartido: título, hipótesis, bibliografía, sesgos, diseño y limitaciones. Sin contar el baseline. Las slides con los cambios sugeridos en la preliminar ya están subidas. |
| **Jue 26-nov-2026** | **Presentación Definitiva (Hito 2)** | Exposición plenaria (10-12 min). Hallazgos consolidados, curvas de ganancia y código reproducible en repositorio público. |

---

## 3. Hipótesis Antagónica

* **Grupo A (pro-ponderación, contexto):** Nicolás Baranek · Rodrigo Palpa. Sostienen que ponderar los meses del entrenamiento según su recencia o su semejanza con el mes a predecir mejora la ganancia. Proponen cuatro esquemas: escalonado, lineal, exponencial y por semejanza entre meses. Corren su propio experimento; nuestro diseño no depende de sus pesos ni de sus resultados.
* **Hipótesis B:** ponderar los meses del entrenamiento no mejora la ganancia respecto de no ponderar. Unos pesos asignados a meses al azar (placebo) o al revés, con más peso a lo viejo (invertido), no superan al baseline con $w = 1$, y el orden temporal de los pesos no cambia el resultado.  Se evalúan dos esquemas: exponencial (principal) y lineal (extensión).

**Tipo de estudio:** ensayo cruzado (crossover), no ciego, controlado con placebo, de 3 brazos, con comparaciones pareadas por semilla primigenia.

**Objetivo principal**
Evaluar si asignar pesos exponenciales (vida media de 6 meses) a los meses del entrenamiento, sin orden temporal (placebo) o en orden inverso (invertido), cambia la ganancia máxima suavizada del ensamble en 202106 respecto de no ponderar (baseline), sobre 10 semillas primigenias.

**Objetivos secundarios**
1. Comparar el placebo con el invertido, para determinar si el orden temporal de los pesos cambia la ganancia.
2. Describir, en cada brazo, el tamaño efectivo de la muestra, la proporción ponderada de positivos y los hiperparámetros elegidos por la BO.
3. Analizar la variabilidad de la ganancia entre semillas primigenias en cada brazo, distinguiendo la ganancia del ensamble de la media por semilla.
4. Determinar si la ponderación temporal debe incorporarse al workflow de la Segunda Competencia.
5. Repetir las comparaciones con pesos lineales (extensión), como una segunda familia de comparaciones.

**Comparaciones** (unidad de análisis: semilla primigenia; outcome: ganancia máxima suavizada del ensamble en 202106; Wilcoxon pareado bilateral)

| | Comparación | Qué pregunta | B se sostiene si… |
| :--- | :--- | :--- | :--- |
| **C1** | Placebo vs. Baseline | ¿Tener pesos desiguales, sin orden temporal, cambia la ganancia? | El placebo no mejora al baseline. |
| **C2** | Invertido vs. Baseline | ¿Darle más peso a los meses viejos cambia la ganancia? | El invertido no mejora al baseline. |
| **C3** | Placebo vs. Invertido | ¿Importa el orden temporal de los pesos? | No se detecta diferencia. |

*Lecturas posibles de cada comparación:* **mejora** ($p$ ajustado $< 0{,}05$ y diferencias positivas), **empeora** ($p$ ajustado $< 0{,}05$ y diferencias negativas) o **sin diferencia detectada** ($p$ ajustado $\geq 0{,}05$; ajuste por multiplicidad en la sección 7). "Sin diferencia detectada" no significa "iguales": no encontrar diferencia no prueba que no exista.

*Cuándo se refuta B:* si el placebo o el invertido **mejoran** al baseline (ponderar sí ayuda), o si C3 detecta diferencia (el orden temporal importa). Si el invertido **empeora** al baseline, ponderar no mejora (a favor de B), pero sugiere que el orden temporal importa: se discute.

---

## 4. Fundamentos Teóricos y Bibliografía

1. **Koren, Y. (2009).** *Collaborative filtering with temporal dynamics.* Proceedings of the 15th ACM SIGKDD, 447–456. DOI: [10.1145/1557019.1557072](https://doi.org/10.1145/1557019.1557072). Versión de divulgación: Communications of the ACM, 53(4), 2010.  
   *Probó pesos con decaimiento exponencial en sistemas de recomendación (Netflix Prize): "prediction quality improves as we moderate that time decay, reaching best quality when there is no decay at all", aunque los usuarios sí cambian con los años. Explica que las preferencias viejas persisten y que bajarles el peso "loses too much signal along with the lost noise". Propone modelar la dinámica temporal dentro del modelo, algo análogo a nuestros lags y deltas (inferencia nuestra). Dominio distinto del churn.*
2. **Klinkenberg, R. (2004).** *Learning drifting concepts: Example selection vs. example weighting.* Intelligent Data Analysis, 8(3), 281–300. DOI: [10.3233/IDA-2004-8305](https://doi.org/10.3233/IDA-2004-8305).  
   *Con concept drift simulado sobre texto y SVM, la selección de ejemplos (ventana adaptativa o selección por lotes) funciona mejor que la ponderación gradual por antigüedad. El autor concluye que una representación continua de la importancia de cada ejemplo "no aporta información útil adicional". Límites: dominio de texto, drift simulado y otro algoritmo.*
3. **Kagerbauer, S. M., Ulm, B., Podtschaske, A. H., et al. (2024).** *Susceptibility of AutoML mortality prediction algorithms to model drift caused by the COVID pandemic.* BMC Medical Informatics and Decision Making, 24, 34. DOI: [10.1186/s12911-024-02428-z](https://doi.org/10.1186/s12911-024-02428-z).  
   *Modelos de mortalidad posoperatoria (entre ellos GBM y XGBoost) entrenados con 2014–2019 y evaluados en la primera ola de COVID. Probaron darle menos peso a los datos viejos y entrenar solo con los últimos 6 meses: "did not have an impact on the robustness of the models". Límites: su "peso" multiplicaba las variables, no las filas, y el COVID estaba en el testeo, no en el entrenamiento.*

### Fuentes complementarias (papers, blogs y documentación)

* **Shimodaira, H. (2000).** *Improving predictive inference under covariate shift by weighting the log-likelihood function.* Journal of Statistical Planning and Inference, 90(2), 227–244. DOI: [10.1016/S0378-3758(00)00115-4](https://doi.org/10.1016/S0378-3758(00)00115-4). *Ponderar mejora bajo covariate shift solo si el modelo está mal especificado; con un modelo bien especificado, la estimación sin pesos es asintóticamente óptima. Sus pesos son cocientes de densidades, no pesos por antigüedad: el traslado es inferencia nuestra.*
* **Gogolashvili, D., Zecchin, M., Kanagawa, M., & Kountouris, M. (2023).** *When is importance weighting correction needed for covariate shift adaptation?* arXiv:2303.04020. *La corrección por pesos puede no ser necesaria con modelos no paramétricos bien especificados (a favor de B), pero sí con modelos mal especificados (a favor de A).*
* **Byrd, J., & Lipton, Z. C. (2019).** *What is the effect of importance weighting in deep learning?* ICML, PMLR 97. *En redes sobreparametrizadas el efecto del peso se diluye con el entrenamiento. Evidencia indirecta para B, en deep learning y no en GBDT.*
* **Yao, H., Choi, C., Lee, Y., Koh, P. W., & Finn, C. (2022).** *Wild-Time: A benchmark of in-the-wild distribution shift over time.* NeurIPS Datasets and Benchmarks. arXiv:2211.14238. *Con 13 métodos, el desempeño cae en promedio un 20% fuera de distribución y los métodos existentes no logran cerrar esa brecha.*
* **Tsymbal, A. (2004).** [*The problem of concept drift: definitions and related work*](https://ar5iv.labs.arxiv.org/html/1010.4784). *La estrategia adecuada depende del tipo de drift: para drift súbito se prefieren las ventanas. No hay un ganador universal.*
* **Documentación de LightGBM — [Parameters](https://lightgbm.readthedocs.io/en/latest/Parameters.html)** e **[issue #5553](https://github.com/microsoft/LightGBM/issues/5553).** *`min_sum_hessian_in_leaf` es la suma mínima de hessianos por hoja y actúa como regularización. Según un colaborador de LightGBM, "the weights are used when computing the gradients and hessians": cambiar los pesos cambia la regularización efectiva. Por eso la BO se vuelve a correr en cada brazo y los pesos se normalizan a media 1.*
* **Kish (1965), vía [PracTools – Design effects](https://stat.ethz.ch/CRAN/web/packages/PracTools/vignettes/Design-effects.html).** *$deff = 1 + CV^2(w)$ y $ESS = n / deff = (\sum w)^2 / \sum w^2$: los pesos desiguales reducen el tamaño muestral efectivo.*
* **Demšar, J. (2006).** *Statistical comparisons of classifiers over multiple data sets.* Journal of Machine Learning Research, 7, 1–30. *Wilcoxon de rangos con signo para comparar dos clasificadores sobre unidades pareadas; acá, las semillas primigenias.*
* *A favor de A:*
  * **Liu, Z., Godahewa, R., Bandara, K., & Bergmeir, C. (2023).** [*Handling concept drift in global time series forecasting*](https://ar5iv.labs.arxiv.org/html/2304.01512). *Con LightGBM, el peso exponencial a lo reciente bajó el error entre 6 y 10% con drift súbito o incremental; con drift gradual la mejora fue menor al 1% y algunas variantes empeoraron. Solo datos simulados.*
  * **Jain, N., & Shenoy, P.** [*Instance-conditional timescales of decay for non-stationary learning*](https://arxiv.org/html/2212.05908v2) (arXiv:2212.05908) y [blog de Google Research (2024)](https://research.google/blog/learning-the-importance-of-training-data-under-concept-drift/). *Mejoras de hasta 15% con pesos **aprendidos** por instancia y antigüedad. Reportan superar a un decaimiento de escala única, como un decaimiento fijo.*
  * [Kaggle M5 — discusión sobre pesos temporales](https://www.kaggle.com/c/m5-forecasting-accuracy/discussion/144067). *Opinión de competidores; contenido no verificado.*

> **Nota:** no encontramos evidencia empírica directa sobre ponderación temporal en churn bancario con gradient boosting, ni antecedentes de un placebo con pesos asignados a meses al azar. Este experimento aporta esa evidencia.

---

## 5. Sesgos y Preconceptos de los Integrantes

* **Verónica Ester Monzón:** Mi intuición clínica es que el COVID fue un shock y que conviene restarle peso, en contra de lo que defendemos. Además, mi formación me hace sobrevalorar el placebo: tiendo a no creer un resultado si no se descartó el efecto placebo, aunque la diferencia sea grande.
* **Fray Campos:** El comportamiento humano presenta rezagos frente a shocks, similares a los efectos diferidos de la política monetaria. Mi sesgo apunta a que la ponderación de meses ante shocks puntuales no necesariamente mejora la predicción de comportamientos futuros.

---

## 6. Diseño Experimental (*Ceteris Paribus* Estricto)

**Se mantiene fijo, igual que el baseline:** data quality, clase ternaria de los notebooks de la cátedra, FE histórico (lags y delta lags de orden 1 y 2; 762 columnas), parámetros fijos y bordes de búsqueda de LightGBM, BO de **12 evaluaciones en total** (`mlr3mbo`, `init: 12` e `iteraciones: 0`: solo diseño inicial, sin iteraciones bayesianas, según la cátedra en el issue #1 del repo), `kmaldicion: 1` y `ksemillerio: 1`, métrica de la BO = AUC en validación, undersampling 0,1, training_pct 70, 10 semillas en el entrenamiento final (sorteadas como números primos a partir de la semilla primigenia) y meses de cada rol (tabla abajo). La comparación entre brazos se hace por ganancia en el testeo (BAJA+2 = +1.072.500; resto = −27.500).

**Código:** los tres brazos replican el baseline vigente del repo compartido (`BF_nuevo.ipynb` + `config_nuevo.yaml`, 17-nov-2026), con todos los meses. En esta carpeta, ese baseline está traducido a R en `Exp_15B_VM.R` (con `config_15B.yaml` y el lanzador `lanzar_15B.sh`). La única diferencia entre brazos es el peso de cada mes.

**Única intervención:** el vector `weight` de `lgb.Dataset`. Los pesos se aplican en el training de la BO y en el entrenamiento final. La validación de la BO y el testeo se evalúan sin pesos, para que todos los brazos se midan con la misma vara.

**Workflow completo por brazo:** siguiendo la bitácora de la cátedra, cada brazo corre el workflow entero —**incluida la BO**— en lugar de reusar los hiperparámetros del baseline. Los pesos cambian el gradiente y el hessiano de cada fila, así que el óptimo de hiperparámetros también puede cambiar.  Es el mismo criterio de la cátedra para `scale_pos_weight`: al cambiar un peso, "hay que darle oportunidad al resto de los hiperparámetros a que se acomoden".

**Semillas primigenias:** las mismas **10 semillas primigenias** en los tres brazos (5 de cada integrante: 333331, 444443, 555557, 666667 y 121313 de Verónica; 700001, 700027, 700057, 700081 y 700099 de Fray) (bitácora: "al menos 10 semillas; el mismo vector de semillas para el baseline y para el experimento"). La primigenia fija la partición 70/30 de la BO, el undersampling y el sorteo de las 10 semillas del entrenamiento final, así que, con la misma primigenia, los tres brazos ven exactamente las mismas filas. Las 10 semillas del final comparten el mismo dataset y solo cambian el `seed` de LightGBM (issue #7). Cada primigenia corre su workflow completo (BO + entrenamiento final de 10 semillas), y eso da un vector de 10 ganancias por brazo.

**Normalización:** después del undersampling, los pesos se reescalan a media 1 sobre las filas de entrenamiento, una vez por primigenia en cada uno de los dos lugares donde se aplican: el training de la BO (`dtrain`) y el dataset del entrenamiento final (`dtrain_final`, el mismo para las 10 semillas). Así, la masa total de hessianos es comparable con la de $w = 1$.

### Meses por rol

| Rol | Meses | Control |
| :--- | :--- | :--- |
| Entrenamiento y BO | 201901 a 202104 (28 meses) | La BO usa un 70/30 al azar dentro de estos meses, estratificado por clase pero no por mes, y valida sin pesos. `validate: [202104]` del config no se usa (issue #5). |
| Gap | 202105 | Replica la estructura de producción (202107 no tiene la clase completa). |
| Testeo | 202106 | Tiene clase conocida y queda fuera del entrenamiento y de la BO. |
| Producción (competencia 2) | 202108 | Se vuelve a correr el workflow ganador entero. |

*Lags:* los lags de orden 1 y 2 de 202106 usan atributos (no la clase) de 202105 y 202104. No introducen información de la clase del mes de testeo.

*Variables del mes:* `campos_buenos` incluye `foto_mes` y `numero_de_cliente`, así que el modelo "sabe" a qué mes pertenece cada fila y puede separarlos sin necesidad de pesos. En el testeo, 202106 queda fuera del rango de entrenamiento y cae en la misma rama que el mes más reciente.

### Brazos

| Brazo | Pesos | En el ensayo clínico | Qué aísla |
| :--- | :--- | :--- | :--- |
| **Baseline** | $w = 1$ (baseline del repo compartido) | Control sin tratamiento | Referencia. |
| **Placebo** | Pesos exponenciales (vida media de 6 meses) asignados a los 28 meses al azar; un reparto distinto por semilla primigenia (el mismo en la BO y en el final) | La pastilla, sin el principio activo | El efecto de tener pesos desiguales, sin orden temporal. |
| **Invertido** | Pesos exponenciales al revés: 1 para 201901 y cerca de 0,04 para 202104 | La droga "al revés" | El efecto de darle más peso a los meses viejos. |

*Construcción de los pesos:* cada fila recibe el peso de su mes; después se normaliza a media 1 sobre las filas de entrenamiento. El peso exponencial tiene una vida media de 6 meses, fijada a priori y antes de ver resultados: se divide por 2 cada 6 meses (un 11% por mes, constante), y el mes más pesado vale 1 y el más liviano cerca de 0,04. Se eligió un decaimiento intermedio, lo bastante marcado para no parecerse al baseline sin reducir la muestra efectiva a una fracción pequeña: el ESS de Kish medido quedó en 56-57% de las filas.

*Costo:* cada brazo son 10 workflows completos (uno por semilla primigenia). En total, 30 workflows.

*Corridas:* cada integrante corre el baseline con sus 5 primigenias y los resultados se juntan para completar las 10. La familia exponencial (placebo e invertido) es el experimento principal y la familia lineal (placebo e invertido) es la extensión, también con las 10 primigenias. Todas las corridas usan el mismo script (`Exp_15B_VM.R`, con el brazo como argumento) y el mismo entorno (versiones de R y de paquetes, mismo tipo de VM), porque la comparación pareada exige que la única diferencia entre brazos sea el vector de pesos.

*Cambio de jerarquía:* en el diseño presentado en el Hito 1, la familia lineal era la principal y la exponencial la extensión. El 26-nov-2026 se invirtió el orden (motivo: la familia exponencial se completó primero). El cambio se hizo después de ver los resultados de la familia exponencial. No modifica ningún p ajustado, porque cada familia se corrige con Holm por separado.

### Fuera del recorte 

**Extensión lineal:** dos brazos adicionales con la misma estructura que la familia exponencial: **lineal al azar** (placebo: pesos lineales de 1 a 28 asignados a los meses con la misma permutación que el placebo exponencial de cada primigenia) y **lineal invertido** (28 para 201901 y 1 para 202104). Se comparan contra el baseline y entre sí con Wilcoxon pareado, como una familia de comparaciones aparte. El exponencial "directo" (más peso a lo reciente) no se corre: es uno de los esquemas del Grupo A.

Quedan como Futuros:
* **Sin normalizar:** los pesos sin reescalar, para medir el efecto sobre la regularización.
* **Réplicas en otros meses de testeo:** 202105 y 202104, con los meses de entrenamiento desplazados (walk-forward).
* **Validación temporal de la BO:** validar en un mes posterior al training (por ejemplo, entrenar la BO con 201901–202103 y validar en 202104, el `validate` que ya trae el config) en lugar del 70/30 al azar que pide la slide del baseline (issue #5). Imita mejor la producción, pero valida en un solo mes, entrena la BO con más filas (más tiempo y RAM) y hace que la BO favorezca a lo reciente, lo que se mezcla con nuestra intervención. Requiere repetir los 30 workflows.

---

## 7. Protocolo de Validación y Métricas de Éxito

* **Métrica primaria:** ganancia máxima **suavizada** del **ensamble** de 10 semillas en 202106 (máximo de la media móvil centrada de 1001 envíos sobre la ganancia acumulada, la `ganancia_maxima` de `resumen.csv`) y cantidad de envíos en la que se alcanza. Hay un valor por semilla primigenia.
* **Ensamble vs. media (bitácora de la cátedra):** la ganancia del ensamble no es lo mismo que la media de las ganancias de cada semilla. Se decide por el ensamble; la media por semilla se reporta como descriptiva. En el baseline, la ganancia por semilla se calcula sobre el máximo **crudo**; la calculamos también suavizada (ventana de 1001) para que sea comparable con la del ensamble, y reportamos la cruda aparte.
* **Robustez:** ganancia suavizada en cortes fijos de envíos alrededor del máximo, para no depender de un único punto de la curva.
* **Referencia externa:** los ~496 M a 12.000 envíos informados en Zulip corresponden al máximo crudo del baseline anterior; no son comparables con la ganancia suavizada.
* **Comparación pareada:** para cada semilla primigenia $s$ y cada comparación entre dos brazos $X$ e $Y$, $\Delta_s = G_{X,s} - G_{Y,s}$. Sobre las 10 diferencias se usa la prueba de Wilcoxon de rangos con signo, exacta y bilateral (Demšar, 2006), para C1 (placebo vs. baseline), C2 (invertido vs. baseline) y C3 (placebo vs. invertido).
* **Multiplicidad:** las tres comparaciones se corrigen con Holm, con $\alpha = 0{,}05$ para la familia. Con 10 pares, el $p$ exacto bilateral más chico posible es $2/2^{10} \approx 0{,}002$, por debajo del umbral más exigente de Holm ($0{,}05/3 \approx 0{,}017$), así que la corrección no deja las pruebas sin potencia de antemano.
* **Lectura de resultados:** cada comparación se informa como mejora, empeora o sin diferencia detectada (sección 3), con la mediana de $\Delta_s$ y el $p$ ajustado.

* **Control de bordes de la BO:** en cada workflow se revisa si el mejor trial toca algún borde del rango de búsqueda. Si lo toca, se amplía ese rango, se vuelve a correr la BO y se documenta el cambio, como pide la bitácora de la cátedra. El rango ampliado se aplica a los tres brazos, para que sigan difiriendo solo en los pesos.

* **Diagnósticos:** en cada brazo se reportan el tamaño efectivo de la muestra (ESS de Kish: cuántas filas "valen" realmente una vez aplicados los pesos), la proporción ponderada de positivos (BAJA+1 y BAJA+2) en el training, los hiperparámetros elegidos por la BO y la importancia de variables (lags y deltas frente a variables del mes).

---

## 8. Limitaciones Reconocidas

1. **Sin walk-forward:** la conclusión descansa en un solo mes de testeo (202106). Repetir los 30 workflows en otros meses multiplica el costo, así que las réplicas quedan como Futuros.
2. **Pocas unidades pareadas:** con 10 semillas primigenias, el Wilcoxon solo detecta diferencias grandes y consistentes. Con pesos parecidos, "ni alcanzan 10 semillas" (Gustavo, Clase 14). El resultado más probable es "sin diferencia detectada", que no prueba que los brazos rindan igual.
3. **Multiplicidad:** son tres comparaciones por familia (la extensión suma una segunda familia de tres, que se corrige por separado). La corrección de Holm controla el error de cada familia, a costa de potencia.
4. **BO corta:** 12 evaluaciones sin iteraciones bayesianas se parecen más a una búsqueda al azar, así que parte de las diferencias entre brazos podría ser ruido de la búsqueda y no efecto de los pesos.
5. **La BO no optimiza para los meses recientes:** valida sobre un 30% al azar de todos los meses mezclados (201901–202104), así que los hiperparámetros se eligen para el promedio del período y no para lo más cercano al testeo (issue #5). Pasa igual en los tres brazos.  La validación temporal queda como Futuro (sección 6).
6. **Normalización y undersampling:** la normalización iguala la masa total de hessianos, pero no su distribución entre hojas. Además, los pesos se combinan con el undersampling 0,1, que ya reescala implícitamente la clase mayoritaria.
7. **Los pesos cambian también la proporción de positivos:** como la tasa de bajas varía entre meses, reponderar los meses cambia la prevalencia efectiva de la clase positiva en el training. Se reporta para cada brazo.
8. **Placebo aproximado:** como los meses tienen distinta cantidad de clientes, asignar los pesos a meses al azar no conserva exactamente el ESS. Con 10 primigenias, los repartos al azar tampoco cubren todas las combinaciones posibles.
9. **Dos esquemas de pesos y sin brazo de recencia:** se evalúan pesos exponenciales (principal) y lineales (extensión). Ninguna de las dos familias tiene un brazo "directo" (más peso a lo reciente): con nuestros datos no se puede afirmar si darle más peso a lo reciente ayuda, solo si ayudan los pesos sin orden o al revés. Los pesos aprendidos por instancia (Jain y Shenoy) quedan fuera del alcance.
9 bis. **Una sola tasa de decaimiento:** la familia exponencial usa una vida media de 6 meses, elegida a priori y sin ajustar. Otras tasas (más rápidas o más lentas) podrían dar resultados distintos, y no se exploran en este experimento.
10. **El mes como variable:** `foto_mes` y `numero_de_cliente` entran al modelo. El árbol puede separar por mes sin pesos, lo que podría diluir el efecto de la ponderación.
11. **Interacción con los lags sin testear:** la idea de que los lags y deltas vuelven redundantes a los pesos no se prueba directamente, porque requeriría modificar el FE y romper el *ceteris paribus*.
12. **Costo computacional:** 30 workflows completos con BO (50 con la extensión). En una VM de 16 vCPU y 128 GB, cada workflow tardó entre 4,5 y 5,5 horas, con un pico de memoria de unos 47 GiB, usando casi todos los núcleos disponibles. Según la cátedra, LightGBM no escala lineal con los núcleos, así que varias VM chicas rinden más que una grande.
13. **No ciego:** sabemos qué brazo corre cada workflow. Se mitiga fijando de antemano las comparaciones, la prueba y la corrección por multiplicidad.

---
