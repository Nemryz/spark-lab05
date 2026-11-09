# Análisis de videojuegos con Apache Spark

Trabajo realizado por Ignacio Ampuero, Engel Falcón, Benjamín González, Santiago Herrera, Matías Huerta, Jesús Poturo y Rodrigo Solar. Sección P01.

## Resumen

Este repositorio reúne el laboratorio 05 de Apache Spark. El equipo analizó un catálogo de 100.565 videojuegos con dos enfoques. Primero construyó un RDD con el nombre y los géneros de cada juego, lo dividió en dos grupos y aplicó cuatro transformaciones y cuatro acciones. Después cargó el mismo archivo como DataFrame, eliminó las columnas vacías, convirtió los tipos de datos y resumió la información con agregaciones.

Ambos caminos llegaron a las mismas cinco categorías principales. Action encabeza la lista con 21.452 juegos en el RDD y 21.440 en el DataFrame. La siguen Platformer, Adventure, Puzzle y Shooter. El DataFrame procesó 100.259 filas después de eliminar 306 duplicados y tardó alrededor de 30 segundos en una ejecución local. El RDD trabajó sobre 76.890 juegos con nombre y género, ejecutó varias acciones sin caché y tardó cerca de 114 segundos.

La comparación muestra que DataFrame simplifica la limpieza y las agregaciones porque aprovecha el esquema y el optimizador Catalyst. El RDD ofrece control sobre cada paso y permite observar el costo de las operaciones. La elección depende del problema y no de una preferencia personal.

| Indicador | RDD | DataFrame |
|---|---|---|
| Juegos considerados | 76.890 | 100.259 |
| Géneros distintos | 20 | 20 |
| Género principal | Action 21.452 | Action 21.440 |
| Tiempo observado | 114 s | 30 s |

## Comandos

Todos los comandos se ejecutan desde la raíz del repositorio en PowerShell 5.1 o superior. El lanzador carga el JDK y el Python del laboratorio, fija un gigabyte de memoria para el controlador y separa los resultados de los logs.

| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `.\install\install-spark.ps1` | Instala Spark, JDK, Python y winutils | Primera vez |
| `.\install\verify-install.ps1` | Ejecuta las doce comprobaciones | Después de instalar |
| `.\install\run.ps1 status` | Muestra rutas y versiones | Antes de ejecutar |
| `.\install\run.ps1 submit LaboratorioPyspark\DataFrame.py` | Ejecuta la demo de DataFrame | Análisis tabular |
| `.\install\run.ps1 submit LaboratorioPyspark\Spark_rdd.py` | Ejecuta la demo de RDD | Análisis de bajo nivel |
| `.\install\run.ps1 pyspark` | Abre la shell de PySpark | Exploración |
| `Get-ChildItem logs` | Lista los logs generados | Diagnóstico |
| `Get-Content logs\DataFrame\<archivo>.log` | Lee un log concreto | Diagnóstico |

### Descargar el repositorio

El repositorio se encuentra en github.com/Nemryz/spark-lab05. La rama de trabajo es videojuegos. Después de descargarlo, abrí una terminal en la carpeta raíz.

```powershell
cd spark-lab05
git checkout videojuegos
```

### Instalar el entorno

```powershell
.\install\install-spark.ps1
.\install\verify-install.ps1
.\install\run.ps1 status
```

La primera ejecución tarda entre 10 y 20 minutos. Las siguientes omiten los componentes que ya existen. La verificación termina con doce comprobaciones y el estado muestra las rutas de Java, Python, Spark y Hadoop.

El lanzador necesita `install\spark-env.ps1`, un archivo que genera el instalador y que no se versiona.

### Ejecutar las demos

```powershell
.\install\run.ps1 submit LaboratorioPyspark\DataFrame.py
.\install\run.ps1 submit LaboratorioPyspark\Spark_rdd.py
```

La demo de DataFrame tarda alrededor de 30 segundos y la de RDD cerca de 2 minutos. Los resultados aparecen en la consola y los logs de Spark quedan en `logs\DataFrame` y `logs\Spark_rdd`.

### Revisar los logs

```powershell
Get-ChildItem logs\DataFrame
Get-ChildItem logs\Spark_rdd
Get-Content logs\DataFrame\<archivo>.log
```

Cada ejecución genera dos archivos. El archivo `.log` guarda los mensajes de Spark y de la JVM. El archivo `.stdout.log` guarda la salida completa del script. La consola muestra solo las líneas de resultado después del filtrado.

### Otros comandos del lanzador

El lanzador también acepta `pyspark`, `python`, `jupyter`, `notebook` y `shell`. El comando `pyspark` abre una shell interactiva. El comando `python` ejecuta el intérprete del entorno virtual. Los comandos `jupyter` y `notebook` abren las interfaces de cuadernos. El comando `shell` inicia la shell de Scala.

## El enunciado

El taller evalúa cinco puntos y cada uno tiene un entregable asociado.

### Puntos que evalúa el taller

1. Un cuadro comparativo entre RDD, DataFrame y Dataset.
2. Un ejemplo con RDD que use cuatro transformaciones y cuatro acciones distintas de las vistas en clase.
3. Un ejemplo con DataFrame que muestre las funciones vistas en clase más cuatro funciones investigadas por el equipo.
4. La conformación de cuatro equipos con un mínimo de dos estudiantes, informada por correo antes de la medianoche del 28 de octubre.
5. Una exposición de diez minutos con una tolerancia de dos minutos.

### Organización de la entrega

| Parte | Archivo o evidencia | Estado |
|---|---|---|
| Cuadro comparativo | README.md | Terminado |
| Demo con RDD | LaboratorioPyspark/Spark_rdd.py | Terminado |
| Demo con DataFrame | LaboratorioPyspark/DataFrame.py | Terminado |
| Informe | Documento aparte | Pendiente |
| Presentación | Documento aparte | En preparación |
| Exposición | Diez minutos | Pendiente |

## El conjunto de datos

El archivo `LaboratorioPyspark/dataset_videojuegos.csv` pesa 75 MB y contiene 100.565 filas. Proviene del conjunto 100000 Video Game Dataset with Records publicado en Kaggle y conserva la estructura de campos de RAWG. Cada fila describe un videojuego y reúne datos de identificación, fechas, ratings, plataformas, desarrolladores, publicadores y clasificación ESRB.

El archivo alimenta dos rutas independientes.

```text
dataset_videojuegos.csv
        |
        +--> LaboratorioPyspark/Spark_rdd.py
        |
        +--> LaboratorioPyspark/DataFrame.py
```

### Origen y volumen

El archivo llegó como CSV con cabecera y 165 columnas. Muchas columnas aparecen vacías porque el encabezado original trae comas de más. Después de eliminar las 146 columnas `_cNN` quedan 19 columnas reales. El equipo considera 11 campos relevantes para el análisis.

El archivo completo pesa 75 MB. La demo con RDD carga en el driver solo el nombre y los géneros de 76.890 juegos, así que el consumo de memoria queda acotado. La demo con DataFrame conserva las 19 columnas y procesa las 100.259 filas que quedan después de la deduplicación.

### Campos principales

| Campo | Tipo | Uso |
|---|---|---|
| `id` | texto | Identificador del juego |
| `name` | texto | Nombre del juego |
| `metacritic` | entero | Nota de la crítica |
| `released` | texto | Fecha de lanzamiento |
| `rating` | decimal | Nota de los usuarios |
| `ratings_count` | entero | Cantidad de votos |
| `genres` | texto con `||` | Géneros del juego |
| `platforms` | texto con `||` | Plataformas disponibles |
| `developers` | texto | Desarrolladores |
| `publishers` | texto | Publicadores |
| `esrb_rating` | texto | Clasificación ESRB |

### Calidad de los datos

La limpieza enfrenta cuatro problemas. El encabezado trae comas de más y genera columnas vacías. El rating llega como texto. La mayoría de los juegos no tiene votos. Un género aparece corrupto. Cada problema tiene una solución documentada en las secciones siguientes.

`dropDuplicates()` elimina 306 filas repetidas y deja 100.259 juegos. La deduplicación se aplica sobre toda la fila y no sobre `id`, porque el objetivo era quitar registros repetidos del archivo.

`rating` llega como texto. La mayoría de los juegos no tiene votos y el valor queda en 0. Después de convertir la columna a double, `describe()` cuenta 100.221 valores no nulos, con media 0,096, desviación 0,549 y máximo 4,86. El equipo interpreta el 0 como ausencia de calificación y no como una nota baja.

`genres` usa `||` como separador. `flatMap` y `split` separan los valores. Un registro contiene el valor corrupto `"like reverb"` y aparece una sola vez. El equipo lo documenta y lo excluye del análisis.

El campo `about` incluye saltos de línea y comillas. Por eso la lectura usa `multiLine=True`, `quote` y `escape`.

El RDD conserva 76.890 juegos con nombre y género. El resto queda fuera porque no tiene nombre, no tiene género o ambos campos están vacíos.

## Entorno de ejecución

### Requisitos

El laboratorio funciona en Windows 10 u 11 con PowerShell 5.1 o superior. Necesita 3 GB libres como mínimo y 5 GB recomendados, además de conexión a internet durante la primera instalación. No hace falta ser administrador ni tener Java o Python instalados.

### Componentes instalados

| Componente | Versión | Función |
|---|---|---|
| Apache Spark | 3.3.4 con Hadoop 3 | Motor de procesamiento |
| Eclipse Temurin | 11.0.25+9 | JDK del laboratorio |
| winutils y hadoop.dll | 3.3.6 | Soporte de Hadoop en Windows |
| Python | 3.10.11 | Intérprete del laboratorio |
| Entorno virtual | 3.10 | Paquetes de Python |

El instalador elige una carpeta escribible en la unidad del sistema y usa `%LOCALAPPDATA%\spark-lab` como respaldo. Las rutas exactas aparecen al ejecutar `.\install\run.ps1 status`.

El archivo `install/requirements.txt` instala findspark, numpy, pandas, pyarrow, matplotlib, python-dotenv, jupyterlab y notebook. El archivo `LaboratorioPyspark/requirements.txt` solo incluye pandas, pyarrow y matplotlib para generar figuras. PySpark no se instala con pip porque viene dentro del paquete de Spark.

### El lanzador y los logs

El lanzador `install/run.ps1` carga `install/spark-env.ps1` en el proceso actual. De esta forma fija `SPARK_HOME`, `JAVA_HOME`, `HADOOP_HOME`, `SPARK_LAB_VENV` y `SPARK_LOCAL_IP` sin modificar la instalación global de la máquina.

El comando `submit` separa la salida estándar de la salida de error. Los resultados del script salen por consola después de un filtro que elimina las líneas de progreso de Spark. Los mensajes de Spark y de la JVM se guardan en `logs\<script>\<fecha>.log`. El archivo `.stdout.log` conserva la salida completa del script.

### Instalación y verificación

La instalación descarga Spark 3.3.4, el JDK 11 de Eclipse Temurin, Python 3.10.11 y los archivos de winutils. Después crea el entorno virtual e instala los paquetes de `install/requirements.txt`. La verificación ejecuta doce comprobaciones sobre el archivo de entorno, los binarios, el entorno virtual y un trabajo real de Spark.

En este equipo el instalador de Python reportó una versión previa y no creó el entorno. El equipo completó la instalación con el ZIP embebido de Python 3.10.11 y creó el entorno virtual con `virtualenv`. La verificación automática queda pendiente de repetir después de esa instalación manual.

## Demo con RDD

### Estrategia de partición

El script `LaboratorioPyspark/Spark_rdd.py` lee el archivo con el módulo `csv`, conserva los juegos que tienen nombre y géneros y reparte las filas en dos grupos. El grupo A recibe las posiciones pares y el grupo B recibe las impares. Cada grupo se convierte en un RDD con cuatro particiones. La ejecución usa `local[1]` para evitar los cuelgues del pipe de Windows.

La división en grupos no es una transformación de Spark. Es una preparación para comparar los conjuntos.

### Transformaciones

| Función | Tipo | Qué hace | Resultado |
|---|---|---|---|
| `flatMap` | Transformación | Separa los géneros de cada juego | 50.859 asignaciones en el grupo A |
| `union` | Transformación | Fusiona los géneros de A y B | 101.685 asignaciones |
| `intersection` | Transformación | Busca los géneros compartidos | 19 géneros |
| `subtract` | Transformación | Aísla los géneros exclusivos de A | 1 género |

### Acciones

| Función | Qué hace | Resultado |
|---|---|---|
| `collect` | Extrae los géneros distintos | 20 géneros |
| `reduce` | Suma las asignaciones | 101.685 |
| `countByValue` | Cuenta cada género | 20 conteos |
| `takeOrdered` | Ordena los cinco primeros | Action, Platformer, Adventure, Puzzle y Shooter |

### Resultados

El RDD reúne 76.890 juegos con nombre y género. El grupo A y el grupo B contienen 38.445 juegos cada uno. La unión produce 101.685 asignaciones de género. La intersección deja 19 géneros compartidos y la resta deja un solo género exclusivo del grupo A, el valor corrupto `"like reverb"`.

| Género | Juegos |
|---|---|
| Action | 21.452 |
| Platformer | 12.683 |
| Adventure | 12.286 |
| Puzzle | 10.412 |
| Shooter | 9.247 |

### Discusión

El script carga el CSV en el driver y luego distribuye la lista. Esta decisión simplifica la lectura y evita problemas de parsing, aunque no aprovecha la lectura distribuida de Spark. Para un dataset mucho más grande convendría usar `sc.textFile` y parsear en los executors.

El script ejecuta varias acciones sobre el mismo RDD sin `cache()`, así que Spark recalcula la línea de ascendencia en cada acción. `collect()` y `countByValue()` son seguros porque el cardinal es bajo. `takeOrdered()` se aplica sobre un RDD pequeño construido a partir del diccionario de conteos, porque `reduceByKey()` con `takeOrdered()` sobre el RDD grande cuelga el pipe en Windows.

`count()` y `take()` aparecen como apoyo para mostrar el avance y no cuentan como las cuatro acciones exigidas.

## Demo con DataFrame

### Limpieza y preparación

El script `LaboratorioPyspark/DataFrame.py` lee el CSV con `header`, `inferSchema`, `quote`, `escape` y `multiLine`. Elimina las columnas `_cNN`, convierte `rating` a double, `ratings_count` a int y `metacritic` a int, y aplica `dropDuplicates()`.

La versión 3.3.4 no ofrece `try_cast`, así que el script usa `cast` y deja `null` cuando el valor no es numérico. El DataFrame queda con 19 columnas y 100.259 filas.

### Funciones de clase

El script usa `show(5)` para mirar las primeras filas, `count()` para contar los juegos y `printSchema()` para revisar los tipos. También imprime la lista de columnas para comprobar que la limpieza dejó solo los campos útiles.

### Funciones investigadas

| Origen | Función | Qué hace |
|---|---|---|
| Investigada | `describe()` | Calcula estadísticas del rating |
| Investigada | `dropDuplicates()` | Elimina filas repetidas |
| Investigada | `withColumn()` | Agrega la categoría del juego |
| Investigada | `groupBy().agg()` | Resume por categoría |
| Apoyo | `filter()` | Filtra rating alto y votos |
| Apoyo | `split()` con `explode()` | Deja un género por fila |

### Resultados

| Categoría | Juegos | Rating promedio | Votos |
|---|---|---|---|
| Sin calificar | 97.101 | 0,00 | 8.394 |
| Bueno | 1.447 | 3,46 | 121.004 |
| Regular | 1.349 | 2,29 | 37.259 |
| Excelente | 362 | 4,19 | 91.103 |

El total de la tabla suma 100.259 juegos.

El filtro deja 63 juegos con rating mayor o igual a 4 y al menos 500 votos. Los tres primeros son Portal con 4,52 y 3.050 votos, Half-Life 2 con 4,50 y 2.516 votos, y Limbo con 4,16 y 2.239 votos.

| Género | Juegos | Rating promedio de los calificados |
|---|---|---|
| Action | 21.440 | 2,99 |
| Platformer | 12.674 | 3,37 |
| Adventure | 12.273 | 3,03 |
| Puzzle | 10.410 | 3,21 |
| Shooter | 9.242 | 3,41 |

### Discusión

`inferSchema` recorre el archivo más de una vez y un esquema explícito sería más eficiente. La comodidad de inferir los tipos pesa más en un laboratorio, aunque en producción conviene declarar el esquema.

`dropDuplicates()` sin subconjunto elimina filas completas y podría borrar juegos con metadatos distintos. Una versión futura podría deduplicar por `id` para conservar esos casos.

El rating 0 significa ausencia de votos y no una mala nota. Por eso el análisis por categoría separa los valores mayores que 0 y el promedio de los géneros se calcula solo con los juegos calificados.

Catalyst optimiza las agregaciones y explica parte de la diferencia con RDD. El DataFrame expresa la misma idea con menos código y deja que el motor decida el plan físico.

## RDD y DataFrame frente a frente

### Cuadro comparativo

| Criterio | RDD | DataFrame | Dataset |
|---|---|---|---|
| Definición | Colección distribuida de objetos | Tabla de filas y columnas | Colección distribuida tipada |
| Abstracción | Baja | Alta | Alta |
| Estructura | Objetos distribuidos | Esquema tabular | Datos tipados |
| Optimización | Manual | Catalyst | Catalyst |
| Rendimiento | Depende de la optimización manual | Generalmente eficiente | Generalmente eficiente |
| Lenguajes | Python, Scala y Java | Python, Scala y Java | Scala y Java |
| Uso principal | Lógica personalizada | Análisis y agregaciones | Seguridad de tipos |
| En este taller | `Spark_rdd.py` | `DataFrame.py` | No implementado en PySpark |
| Cuándo usar | Datos no tabulares o lógica a medida | Análisis tabular y SQL | Tipos en compilación |

### Comparación de resultados

| Indicador | RDD | DataFrame |
|---|---|---|
| Juegos considerados | 76.890 | 100.259 |
| Géneros distintos | 20 | 20 |
| Action | 21.452 | 21.440 |
| Platformer | 12.683 | 12.674 |
| Adventure | 12.286 | 12.273 |
| Puzzle | 10.412 | 10.410 |
| Shooter | 9.247 | 9.242 |

Las diferencias aparecen porque la base no es la misma. El RDD conserva 76.890 juegos con nombre y género. El DataFrame parte de 100.259 filas deduplicadas y descarta los géneros nulos. La coincidencia en el orden y en la cercanía de los conteos valida ambos resultados.

### Tiempos observados

| Demo | Tiempo observado | Qué incluye |
|---|---|---|
| DataFrame | 30 s | Arranque de Spark y seis bloques de análisis |
| RDD | 114 s | Arranque de Spark y varias acciones sin caché |

La medición corresponde a una sola ejecución por demo en un equipo Windows con 16 GB y `local[1]`. Incluye el arranque de la JVM y no constituye un benchmark formal. Para comparar con rigor conviene repetir cada demo cinco veces y usar la mediana.

### Cuándo conviene cada enfoque

RDD conviene cuando la lógica necesita control sobre cada paso, cuando los datos no son tabulares o cuando se requiere una operación que no existe en la API de DataFrame. DataFrame conviene cuando el análisis es tabular, cuando se usan agregaciones o SQL y cuando se busca que Catalyst optimice el plan. Dataset aporta tipos en tiempo de compilación y por eso se usa desde Scala o Java. En PySpark, DataFrame es la representación de `Dataset[Row]` y no existe un Dataset tipado equivalente.

## Problemas encontrados y soluciones

| Problema | Causa | Solución |
|---|---|---|
| `Connection reset by peer` | PySpark 4.2.0 con JDK 17 | Instalar Spark 3.3.4 con JDK 11 |
| `Python worker exited unexpectedly` | `take`, `collect` y `reduce` sobre RDD grandes | Evitar esas llamadas y usar `distinct().take()` o `takeOrdered()` |
| `reduceByKey` con `takeOrdered` se cuelga | El shuffle satura el pipe de Windows | Calcular `countByValue` y ordenar un RDD pequeño |
| 146 columnas vacías | El encabezado del CSV trae comas de más | Eliminar las columnas `_cNN` |
| `rating` como texto y mayoría en 0 | El origen del dataset | Convertir con `cast` y analizar solo valores mayores que 0 |
| Género `"like reverb"` | Registro corrupto | Documentarlo y excluirlo del análisis |
| El instalador de Python 3.10 falla | El registro de Windows informa una versión previa | Usar el ZIP embebido y crear el entorno con `virtualenv` |

## Decisiones de diseño

| Decisión | Motivo | Consecuencia |
|---|---|---|
| Leer el CSV local | Evita depender de una API | El repositorio incluye un archivo de 75 MB |
| Ejecutar en `local[1]` | Evita los cuelgues del pipe en Windows | Menos paralelismo |
| Usar `cast` | La versión 3.3.4 no tiene `try_cast` | Los valores inválidos quedan `null` |
| Calcular con `countByValue` | Evita el cuelgue de `reduceByKey` con `takeOrdered` | El conteo viaja al driver |
| Deduplicar toda la fila | Elimina registros repetidos | Puede borrar juegos con metadatos distintos |
| Analizar ratings mayores que 0 | El 0 significa ausencia de votos | No se castiga a los juegos sin calificar |

## Estado del proyecto

| Parte | Estado | Evidencia |
|---|---|---|
| Entorno | Terminado | `.\install\run.ps1 status` muestra Java 11.0.25, Python 3.10.11, Spark 3.3.4 y Hadoop 3.3.6 |
| Demo con RDD | Terminado | Ejecución sin errores, cuatro transformaciones y cuatro acciones |
| Demo con DataFrame | Terminado | Ejecución sin errores, tres funciones de clase y cuatro investigadas |
| README | Terminado | Este documento |
| Cuadro comparativo | Terminado | Sección RDD y DataFrame frente a frente |
| Resultados | Terminado | Tablas de resultados de ambas demos |
| Informe | Pendiente | Se entregará aparte |
| Presentación | En preparación | Se entregará aparte |
| Benchmark formal | Pendiente | La medición actual es una observación |
| Exposición | Pendiente | Diez minutos con todos los integrantes |

## Estructura del repositorio

```text
Spark/
├─ install/
│  ├─ dependencies.json
│  ├─ install-spark.ps1
│  ├─ lib/Installer.ps1
│  ├─ requirements.txt
│  ├─ requirements-dev.txt
│  ├─ run.ps1
│  ├─ uninstall-spark.ps1
│  └─ verify-install.ps1
├─ LaboratorioPyspark/
│  ├─ DataFrame.py
│  ├─ Spark_rdd.py
│  ├─ dataset_videojuegos.csv
│  └─ requirements.txt
├─ logs/                  (se genera al ejecutar y no se versiona)
├─ .gitignore
└─ README.md
```

El entorno virtual `.venv`, las herramientas `.tools`, la caché `cache` y el archivo `install/spark-env.ps1` se generan durante la instalación y quedan fuera del control de versiones.

## Preguntas frecuentes

| Pregunta | Respuesta |
|---|---|
| ¿Por qué se usa `local[1]`? | Con más hilos aparecieron cuelgues del pipe en Windows durante las operaciones con shuffle. Un solo hilo prioriza la estabilidad. |
| ¿Dónde quedan los logs? | En `logs\DataFrame` y `logs\Spark_rdd`. Cada ejecución crea un archivo `.log` y un archivo `.stdout.log`. |
| ¿Por qué no se instala PySpark con pip? | Spark 3.3.4 incluye PySpark y el lanzador lo agrega al `PYTHONPATH`. |
| ¿Por qué RDD y DataFrame dan conteos distintos? | El RDD conserva 76.890 juegos con nombre y género. El DataFrame parte de 100.259 filas deduplicadas y descarta géneros nulos. |
| ¿Cómo se ejecutan las demos desde otra carpeta? | Los scripts calculan la ruta del CSV desde su propia ubicación. El lanzador se encarga de las rutas del entorno. |
| ¿Cómo se limpian los logs? | Podés borrar la carpeta `logs` cuando ya no la necesites. |
| ¿Por qué no se usa Dataset? | PySpark no expone un Dataset tipado. El DataFrame de PySpark es `Dataset[Row]` y la versión tipada requiere Scala o Java. |

## Limitaciones y trabajo futuro

La demo con RDD carga el CSV en el driver. Para un dataset mucho más grande conviene usar `sc.textFile` y parsear en los executors.

El benchmark es una observación de una sola ejecución. Falta repetir cada demo varias veces y calcular la mediana para reducir el efecto del arranque de la JVM.

El equipo no probó un clúster real. Todo el trabajo corre en modo local sobre un equipo Windows.

PySpark no expone Dataset tipado. La comparación con Dataset es conceptual y la implementación tipada requeriría Scala o Java.

La calidad del dataset obliga a documentar el rating 0 y el género corrupto. Una versión futura podría agregar reglas de validación y un informe de calidad.

El informe y la presentación se encuentran en preparación. La exposición debe durar diez minutos y todos los integrantes deben participar.

## Referencias

- Apache Spark 3.3.4. Documentación oficial. spark.apache.org/docs/3.3.4
- PySpark API Reference. spark.apache.org/docs/3.3.4/api/python
- Databricks. Getting Started with Apache Spark. databricks.com/spark/getting-started-with-apache-spark
- IBM. What is Apache Spark? ibm.com/topics/apache-spark
- Kaggle. 100000 Video Game Dataset with Records. kaggle.com/datasets/onlypythondatasheet/100000-video-game-dataset-with-records
- RAWG. Video Game Database. rawg.io
