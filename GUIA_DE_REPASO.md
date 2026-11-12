# Guía de repaso del laboratorio 05 de Apache Spark

Esta guía reúne el funcionamiento completo del repositorio `github.com/Nemryz/spark-lab05`, rama `videojuegos`, y las quince diapositivas de la presentación, con la explicación de cada una y las correcciones que necesita. Sirve para estudiar antes de la exposición, para responder preguntas del evaluador y para comprobar que las cifras de las diapositivas coinciden con la salida real de los scripts.

## Cómo está organizada

La primera parte describe el repositorio y el entorno. La segunda explica el conjunto de datos. La tercera y la cuarta recorren los dos scripts línea por línea. La quinta compara los modelos. La sexta recorre las quince diapositivas y señala las correcciones. Al final quedan las preguntas de repaso, el guion de diez minutos y la lista de verificación.

## Ficha del repositorio

| Dato | Valor |
|---|---|
| Rama de trabajo | videojuegos |
| Repositorio remoto | github.com/Nemryz/spark-lab05 |
| Motor | Apache Spark 3.3.4 con Hadoop 3 |
| JDK | Eclipse Temurin 11.0.25+9 |
| Python | 3.10.11 |
| winutils y hadoop.dll | 3.3.6 |
| Shell | PowerShell 5.1 o superior |
| Memoria del driver | 1 GB |
| Modo de ejecución | `local[1]` en el RDD y `local[*]` por defecto en el DataFrame |

### Estructura de carpetas

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
├─ logs/
├─ analisisVideojuegosRDDvsDataFrames.pptx
├─ .gitignore
└─ README.md
```

### Qué se versiona y qué se genera

El repositorio guarda los ocho archivos del instalador, los dos scripts, el CSV y la presentación. Quedan fuera del control de versiones el entorno virtual `.venv`, las herramientas `.tools`, la caché `cache`, los logs y el archivo `install/spark-env.ps1`, porque todos se reconstruyen con el instalador. Los binarios de Spark, JDK, Python y winutils tampoco se versionan, porque `install/dependencies.json` fija las URL y las sumas de verificación para descargarlos.

## Cómo funciona el entorno

### El instalador

`install/install-spark.ps1` es idempotente. Detecta qué componentes ya existen, descarga solo los que faltan y verifica cada suma antes de extraer. El recorrido es secuencial. Primero hace la comprobación previa y decide si escribe en la unidad del sistema o si cae en `%LOCALAPPDATA%\spark-lab`. Después resuelve las rutas, instala el JDK 11, extrae Spark 3.3.4, copia winutils desde el commit fijado, prepara Python 3.10.11, crea el entorno virtual, instala los paquetes de `install/requirements.txt`, configura el proceso, escribe `install/spark-env.ps1` y guarda el estado de la instalación. Al final comprueba que `spark-submit` arranque con el JDK del laboratorio.

El instalador no modifica la instalación global de Java ni la de Python. Todo vive en las carpetas del laboratorio y el lanzador carga esas rutas en el proceso actual.

### La verificación

`install/verify-install.ps1` ejecuta doce comprobaciones. Revisa el archivo de entorno, el estado de la instalación, Java 11, los archivos de Spark, la versión de Spark, los archivos de winutils, la ejecución de winutils, Python 3.10, los paquetes de Python, un trabajo real de Spark, la interfaz web y la preparación de Windows.

Una de las pruebas busca `tests\smoke_test.py` y esa carpeta no existe en esta rama, así que las comprobaciones `smoke-test` y `spark-ui` fallan. La verificación se puede ejecutar con `-SkipSmoke` para omitirlas, aunque entonces quedan dos avisos. Para una revisión rápida conviene ejecutar `.\install\run.ps1 status` y las dos demos.

### El lanzador

`install/run.ps1` carga `install/spark-env.ps1` y fija `SPARK_HOME`, `JAVA_HOME`, `HADOOP_HOME`, `SPARK_LAB_VENV` y `SPARK_LOCAL_IP`. Después interpreta el primer argumento como comando.

| Comando | Qué hace |
|---|---|
| `status` | Muestra las rutas y las versiones de Java, Python, Spark y Hadoop |
| `submit` | Ejecuta `spark-submit` con 1 GB de memoria para el driver |
| `pyspark` | Abre la consola interactiva de PySpark |
| `python` | Ejecuta el intérprete del entorno virtual |
| `jupyter` | Abre JupyterLab |
| `notebook` | Abre la interfaz clásica de Jupyter |
| `shell` | Abre la consola de Scala que incluye Spark |

El comando `submit` merece atención. Separa la salida estándar de la salida de error, guarda los mensajes de Spark y de la JVM en `logs\<script>\<fecha>.log`, guarda la salida completa del script en el archivo `.stdout.log` y muestra por consola solo las líneas de resultado después de filtrar el ruido de Spark. El nombre del script sale del último argumento.

Los comandos `jupyter` y `notebook` son opcionales y no hacen falta para las demos. En este equipo el entorno virtual no incluye esos ejecutables, así que las dos demos se ejecutan con `submit`.

## El conjunto de datos

El archivo `LaboratorioPyspark/dataset_videojuegos.csv` proviene de Kaggle, conjunto 100000 Video Game Dataset with Records, y conserva la estructura de campos de RAWG. Pesa 75 MB y contiene 100.565 filas.

| Indicador | Valor |
|---|---|
| Filas | 100.565 |
| Columnas de encabezado | 165 |
| Columnas vacías `_cNN` | 146 |
| Columnas reales | 19 |
| Campos relevantes | 11 |
| Peso | 75 MB |
| Filas duplicadas | 306 |
| Filas después de deduplicar | 100.259 |

### Campos principales

| Campo | Tipo | Uso |
|---|---|---|
| `id` | texto | Identificador del juego |
| `name` | texto | Nombre del juego |
| `metacritic` | entero | Nota de la crítica |
| `released` | texto | Fecha de lanzamiento |
| `rating` | decimal | Nota de los usuarios |
| `ratings_count` | entero | Cantidad de votos |
| `genres` | texto con `\|\|` | Géneros del juego |
| `platforms` | texto con `\|\|` | Plataformas disponibles |
| `developers` | texto | Desarrolladores |
| `publishers` | texto | Publicadores |
| `esrb_rating` | texto | Clasificación ESRB |

### Problemas de calidad

El encabezado trae comas de más y por eso aparecen 146 columnas `_cNN` sin datos. La limpieza las elimina y deja 19 columnas reales.

El campo `rating` llega como texto. La mayoría de los juegos no tiene votos y el valor queda en 0. Después de convertirlo a double, `describe()` cuenta 100.221 valores no nulos, con media 0,096, desviación estándar 0,549, mínimo 0 y máximo 4,86. El equipo interpreta el 0 como ausencia de calificación y no como una nota baja.

El campo `genres` usa `||` como separador. Un registro contiene el valor corrupto `"like reverb"` y aparece una sola vez. El RDD lo detecta con `subtract()` y el README lo documenta como limitación.

El campo `about` incluye saltos de línea y comillas, así que la lectura del DataFrame usa `multiLine`, `quote` y `escape` para no romper las filas.

`dropDuplicates()` elimina 306 filas repetidas y deja 100.259 juegos. La deduplicación se aplica sobre la fila completa y no sobre `id`.

## Demo con RDD

### Preparación

`Spark_rdd.py` fija `PYSPARK_PYTHON` y `PYSPARK_DRIVER_PYTHON` al intérprete actual, levanta un `SparkContext` en `local[1]` y lee el CSV con el módulo `csv` y la codificación `utf-8-sig`. Conserva solo los juegos que tienen nombre y géneros. Esa lista queda en el driver y se reparte en dos grupos.

```text
datos_a = datos[::2]
datos_b = datos[1::2]
rdd_a = sc.parallelize(datos_a, 4)
rdd_b = sc.parallelize(datos_b, 4)
```

El grupo A recibe las posiciones pares y el grupo B las impares. Cada RDD usa cuatro particiones. La división no es una transformación de Spark, es una preparación para comparar los conjuntos. El resultado son 76.890 juegos con nombre y género, 38.445 en cada grupo.

### Las cuatro transformaciones

`flatMap` recorre cada tupla, separa los géneros con `split("||")`, limpia los espacios y descarta los valores vacíos o de 50 caracteres o más. El filtro de longitud existe porque los géneros muy largos alimentan el cuelgue del pipe en Windows. El grupo A produce 50.859 asignaciones.

`union` fusiona los géneros del grupo A y del grupo B en un solo RDD. El resultado son 101.685 asignaciones.

`intersection` conserva los géneros que aparecen en ambos grupos. El resultado son 19 géneros compartidos.

`subtract` devuelve los géneros del grupo A que no aparecen en el grupo B. El resultado es un solo género, el valor corrupto `"like reverb"`.

| Función | Tipo | Qué hace | Resultado |
|---|---|---|---|
| `flatMap` | Transformación | Separa los géneros de cada juego | 50.859 asignaciones en A |
| `union` | Transformación | Fusiona los géneros de A y B | 101.685 asignaciones |
| `intersection` | Transformación | Busca los géneros compartidos | 19 géneros |
| `subtract` | Transformación | Aísla los géneros exclusivos de A | 1 género |

### Las cuatro acciones

`collect` extrae a memoria los géneros distintos del RDD unido. El resultado son 20 géneros, contando `"like reverb"`.

`reduce` transforma cada género en un 1 y suma todos los valores. El resultado son 101.685 asignaciones.

`countByValue` cuenta la frecuencia exacta de cada género y devuelve un diccionario con 20 entradas.

`takeOrdered` extrae los cinco géneros con mayor frecuencia. Para evitar el cuelgue de `reduceByKey` con `takeOrdered` sobre el RDD grande, el script convierte el diccionario de conteos en un RDD pequeño y ordena ese RDD con una clave negativa.

| Función | Qué hace | Resultado |
|---|---|---|
| `collect` | Extrae los géneros distintos | 20 géneros |
| `reduce` | Suma las asignaciones | 101.685 |
| `countByValue` | Cuenta cada género | 20 conteos |
| `takeOrdered` | Ordena los cinco primeros | Action, Platformer, Adventure, Puzzle y Shooter |

### Resultados

| Género | Juegos |
|---|---|
| Action | 21.452 |
| Platformer | 12.683 |
| Adventure | 12.286 |
| Puzzle | 10.412 |
| Shooter | 9.247 |

El RDD reúne 76.890 juegos con nombre y género. El grupo A y el grupo B contienen 38.445 juegos cada uno. La unión produce 101.685 asignaciones. La intersección deja 19 géneros compartidos y la resta deja un género exclusivo de A, el valor corrupto `"like reverb"`. El top cinco coincide con el de DataFrame, aunque los conteos difieren un poco porque la base no es la misma.

### Decisiones de implementación

La ejecución en `local[1]` evita los cuelgues del pipe de Windows que aparecieron con más hilos y con operaciones de shuffle. El costo es menos paralelismo.

El script lee el CSV en el driver y luego distribuye la lista. La decisión simplifica el parsing y no aprovecha la lectura distribuida de Spark. Para un archivo mucho más grande convendría `sc.textFile` y parsear en los executors.

Las acciones se ejecutan sin `cache()`, así que Spark recalcula la línea de ascendencia en cada acción. `collect()` y `countByValue()` son seguros porque el cardinal es bajo. `takeOrdered()` se aplica sobre un RDD pequeño por la razón ya explicada.

`count()` y `take()` aparecen como apoyo para mostrar el avance y no cuentan como las cuatro acciones exigidas.

## Demo con DataFrame

### Lectura y limpieza

`DataFrame.py` crea una `SparkSession` con el nombre `Lab05_DataFrame`, resuelve la ruta del CSV desde la carpeta del script y lo lee con `header`, `inferSchema`, `quote`, `escape` y `multiLine`. Después elimina las columnas cuyo nombre empieza con `_c`, convierte `rating` a double, `ratings_count` a int y `metacritic` a int, y aplica `dropDuplicates()`.

La versión 3.3.4 no ofrece `try_cast`, así que el script usa `cast`. Un valor no numérico queda en `null` y la ejecución continúa. El DataFrame limpio conserva las 19 columnas reales y 100.259 filas. La columna `categoria` se agrega después y deja 20 columnas en el análisis.

### Funciones de clase

El script usa `show(5)` para mirar las primeras filas, `count()` para contar los juegos, `columns` para listar los campos y `printSchema()` para revisar los tipos. Esas cuatro llamadas cubren las funciones vistas en clase.

### Funciones investigadas

| Origen | Función | Qué hace |
|---|---|---|
| Investigada | `describe()` | Calcula las estadísticas del rating |
| Investigada | `dropDuplicates()` | Elimina las filas repetidas |
| Investigada | `withColumn()` | Agrega la categoría del juego |
| Investigada | `groupBy().agg()` | Resume por categoría |
| Apoyo | `filter()` | Filtra por rating y votos |
| Apoyo | `split()` con `explode()` | Deja un género por fila |
| Apoyo | `orderBy()` | Ordena los resultados |

`withColumn` crea la columna `categoria` con cuatro reglas. Un rating nulo queda como Sin calificar. Un rating mayor o igual a 4 queda como Excelente. Un rating mayor o igual a 3 queda como Bueno. Un rating mayor que 0 queda como Regular. Cualquier otro caso queda como Sin calificar, así que el 0 también cae en esa categoría.

`groupBy().agg()` cuenta los juegos, promedia el rating y suma los votos. Después `orderBy` deja primero la categoría con más juegos.

`filter` conserva los juegos con rating mayor o igual a 4 y al menos 500 votos, y los ordena por cantidad de votos.

`split()` con `explode()` separa los géneros y calcula el total por género. El promedio se calcula solo con los juegos calificados, porque casi todos valen 0 y bajarían la media.

### Resultados del rating

| Estadístico | Valor |
|---|---|
| Valores no nulos | 100.221 |
| Media | 0,096 |
| Desviación estándar | 0,549 |
| Mínimo | 0 |
| Máximo | 4,86 |

### Resultados por categoría

| Categoría | Juegos | Rating promedio | Votos |
|---|---|---|---|
| Sin calificar | 97.101 | 0,00 | 8.394 |
| Bueno | 1.447 | 3,46 | 121.004 |
| Regular | 1.349 | 2,29 | 37.259 |
| Excelente | 362 | 4,19 | 91.103 |

El total de la tabla suma 100.259 juegos.

### Resultados del filtro

El filtro deja 63 juegos con rating mayor o igual a 4 y al menos 500 votos. Los tres primeros son Portal con 4,52 y 3.050 votos, Half-Life 2 con 4,50 y 2.516 votos y Limbo con 4,16 y 2.239 votos. El orden se debe a `orderBy` sobre `ratings_count` y no al rating.

### Resultados por género

| Género | Juegos | Rating promedio de los calificados |
|---|---|---|
| Action | 21.440 | 2,99 |
| Platformer | 12.674 | 3,37 |
| Adventure | 12.273 | 3,03 |
| Puzzle | 10.410 | 3,21 |
| Shooter | 9.242 | 3,41 |

### Decisiones de implementación

`inferSchema` recorre el archivo más de una vez y un esquema explícito sería más eficiente. La comodidad de inferir los tipos pesa más en un laboratorio, aunque en producción conviene declarar el esquema.

`dropDuplicates()` sin subconjunto elimina filas completas y podría borrar juegos con metadatos distintos. Una versión futura podría deduplicar por `id` para conservar esos casos.

El rating 0 significa ausencia de votos y no una mala nota. Por eso el análisis por categoría separa los valores mayores que 0 y el promedio de los géneros se calcula solo con los juegos calificados.

Catalyst optimiza las agregaciones y explica parte de la diferencia con RDD. El DataFrame expresa la misma idea con menos código y deja que el motor decida el plan físico.

## RDD y DataFrame frente a frente

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

| Indicador | RDD | DataFrame |
|---|---|---|
| Juegos considerados | 76.890 | 100.259 |
| Géneros distintos | 20 | 20 en los datos, aunque el script solo muestra los diez primeros |
| Action | 21.452 | 21.440 |
| Platformer | 12.683 | 12.674 |
| Adventure | 12.286 | 12.273 |
| Puzzle | 10.412 | 10.410 |
| Shooter | 9.247 | 9.242 |

Las diferencias aparecen porque la base no es la misma. El RDD conserva 76.890 juegos con nombre y género. El DataFrame parte de 100.259 filas deduplicadas y descarta los géneros nulos. La coincidencia en el orden y en la cercanía de los conteos valida ambos resultados.

Los tiempos observados son de alrededor de 30 segundos para DataFrame y 114 segundos para RDD. La medición corresponde a una sola ejecución por demo en un equipo Windows con 16 GB, con el RDD en `local[1]` y el DataFrame en el modo local por defecto. Incluye el arranque de la JVM y no constituye un benchmark formal. Para comparar con rigor conviene repetir cada demo cinco veces y usar la mediana.

## Recorrido completo de las diapositivas

Esta sección explica las quince páginas de la presentación en orden. Para cada una indica qué muestra, cómo se conecta con el repositorio y qué conviene corregir antes de la exposición. Las cifras provienen de la ejecución real de `Spark_rdd.py` y `DataFrame.py`.

| Página | Tema | Idea central |
|---|---|---|
| 1 | Portada | Título, equipo y sección |
| 2 | Introducción | Qué es Spark y qué se busca con el taller |
| 3 | Entorno | Instalación aislada y dependencias |
| 4 | Dataset | Ficha del archivo y problemas de calidad |
| 5 | Cuadro comparativo | RDD, DataFrame y Dataset |
| 6 | Transformaciones RDD | flatMap, union, intersection y subtract |
| 7 | Acciones RDD | collect, reduce, countByValue y takeOrdered |
| 8 | Cierre RDD | Resultados y salto al DataFrame |
| 9 | Limpieza DataFrame | drop, cast, dropDuplicates y withColumn |
| 10 | Agregaciones | groupBy, agg y categorías |
| 11 | Filtro | Juegos mejor valorados |
| 12 | Géneros | split, explode y promedio |
| 13 | Conclusiones | Qué aporta cada modelo |
| 14 | Bibliografía | Fuentes consultadas |
| 15 | Cierre | Portada final y equipo |

### Página 1. Portada

La primera diapositiva presenta el título Análisis de Videojuegos con Apache Spark, RDD vs DataFrames, los siete integrantes del equipo, la sección P01 y el logo de la Universidad Autónoma de Chile. No tiene contenido técnico. Su función es identificar el trabajo y dejar claro que la comparación entre RDD y DataFrame es el eje de la exposición.

Conviene revisar la ortografía de los nombres en el archivo final. La transcripción del PDF local trae Rodigro en lugar de Rodrigo y la página 15 repite el equipo en otro orden. El nombre correcto es Rodrigo Solar. También conviene que el título coincida con el del informe y con el encabezado del README.

### Página 2. Introducción

La diapositiva define Apache Spark como un motor de procesamiento distribuido de datos. Explica que permite analizar información mediante RDD y DataFrame, que se aplica a un conjunto de datos de videojuegos y que el objetivo es explorar, transformar y resumir los datos con distintas funciones de Spark.

La definición es correcta y conviene ampliarla en la exposición. Spark reparte el trabajo en particiones, un driver coordina la ejecución y los executors procesan las tareas. El RDD es la abstracción de bajo nivel, basada en objetos distribuidos. El DataFrame es la abstracción tabular, con columnas, tipos y un optimizador llamado Catalyst. El taller usa las dos sobre el mismo archivo para comparar el esfuerzo de programación y el resultado.

El objetivo de la diapositiva se cumple en el repositorio. `Spark_rdd.py` explora el archivo, separa los géneros y resume las frecuencias. `DataFrame.py` limpia, agrega y filtra la misma información con una API declarativa.

### Página 3. Entorno

La diapositiva describe un entorno virtual aislado, las dependencias de `requirements.txt` y los requisitos base. La imagen muestra una carpeta llamada `prueba` con `requirements.txt`, `Spark_rdd.py`, `DataFrame.py` y el dataset. Esa carpeta no coincide con el repositorio, donde los archivos viven en `LaboratorioPyspark`.

Hay tres afirmaciones que deben corregirse. La primera es que `pyspark` se instala con `pip`. En este repositorio no se instala, porque viene dentro del tarball de Apache Spark 3.3.4 y el lanzador lo pone en `PYTHONPATH`. La segunda es `kagglehub`. El repositorio no lo usa, porque el CSV está versionado y los dos scripts lo leen desde la carpeta del script. La tercera son los requisitos base. La diapositiva dice Python 3.1+ y Java 17 o 21, mientras el entorno real fija Python 3.10.11, JDK 11 y Spark 3.3.4.

La combinación de Spark 3.3.4 con JDK 11 es la que funciona en este equipo. Con JDK 17 apareció el error `Connection reset by peer`. El instalador crea `.venv`, descarga Spark, el JDK, Python y winutils en `.tools`, y escribe `install/spark-env.ps1` para que el lanzador use esas rutas sin tocar las instalaciones globales. La sección de entorno de esta guía amplía cada paso.

### Página 4. El Dataset

La diapositiva presenta la ficha del archivo. La fuente es Kaggle, conjunto 100000 Video Game Dataset with Records, con campos de RAWG. El formato es CSV de 75 MB. El encabezado trae 165 columnas y 146 son columnas vacías. Después de la limpieza quedan 19 columnas reales y 11 relevantes. Los campos `genres` y `platforms` usan `||` como separador. El rating llega como texto y la mayoría vale 0.

El repositorio confirma casi todo. El archivo real está en `LaboratorioPyspark/dataset_videojuegos.csv`, pesa 75 MB y tiene 100.565 filas. El encabezado trae 165 columnas y 146 son `_cNN`, exactamente por las comas de más. Quedan 19 columnas reales y el equipo trabaja con 11. Los separadores `||` y el rating en texto también coinciden con `DataFrame.py` y con `Spark_rdd.py`.

La diapositiva dice 105.565 filas y el valor correcto es 100.565. La cifra correcta aparece en el archivo, en el README y en la salida de los dos scripts. También conviene agregar las 306 filas duplicadas y las 100.259 filas que quedan después de la limpieza, porque ese dato conecta la página 4 con la página 9.

El resumen descriptivo del rating ayuda a explicar la calidad. `describe()` cuenta 100.221 valores no nulos, con media 0,096, desviación estándar 0,549, mínimo 0 y máximo 4,86. Esa distribución explica por qué el análisis separa los valores mayores que 0 y por qué la categoría Sin calificar concentra 97.101 juegos.

### Página 5. Cuadro comparativo

La diapositiva compara RDD, DataFrame y Dataset en ocho filas. La definición, la abstracción, la estructura, la optimización, el rendimiento, los lenguajes, el uso principal y el criterio para elegir. Es un buen resumen conceptual y coincide con lo que muestra el repositorio.

El RDD es una colección distribuida de objetos. Su abstracción es baja, la estructura son objetos distribuidos y la optimización queda en manos de quien programa. El DataFrame organiza los datos en filas y columnas con un esquema. Su abstracción es alta y Catalyst optimiza las consultas. El Dataset es una colección tipada que combina la API de DataFrame con tipos verificados en compilación. Esa última columna es conceptual, porque PySpark no ofrece Dataset tipado y el taller no lo implementa.

La fila de lenguajes debe leerse con cuidado. RDD y DataFrame están disponibles en Python, Scala y Java. Dataset está disponible en Scala y Java, porque necesita tipos del lenguaje. La fila de rendimiento también necesita contexto. El DataFrame suele ser más eficiente en trabajos tabulares porque Catalyst reordena filtros y agregaciones. El RDD puede ser competitivo cuando la lógica es personalizada y se evita el costo del esquema.

En el taller, `Spark_rdd.py` representa la columna RDD y `DataFrame.py` representa la columna DataFrame. La comparación no es teórica. Los dos scripts leen el mismo CSV y llegan a un top cinco de géneros muy parecido con estrategias distintas.

### Página 6. Análisis con RDD, transformaciones

La diapositiva muestra el código de las cuatro transformaciones. `flatMap` separa los géneros de cada juego, `union` junta los géneros de los dos grupos, `intersection` encuentra los compartidos y `subtract` aísla los exclusivos del grupo A. La lista inferior explica cada paso y aclara que la división entre A y B no es una transformación de Spark.

El fragmento tiene dos detalles que conviene corregir. Escribe `split("|")` y el repositorio usa `split("||")`. El resultado es el mismo porque los valores vacíos se descartan, pero la separación correcta usa el doble separador del archivo. Además, a la llamada de `flatMap` le falta el paréntesis de cierre. Si el código se copia en la exposición, debe verse igual que el script.

El repositorio divide el archivo en posiciones pares e impares antes de crear los RDD. Esa división no es una transformación de Spark, es una preparación para comparar dos conjuntos. `flatMap` recorre cada tupla, separa los géneros, limpia los espacios y descarta los valores vacíos o de 50 caracteres o más. El filtro de longitud existe porque los géneros muy largos alimentan el cuelgue del pipe en Windows.

| Transformación | Qué hace | Resultado real |
|---|---|---|
| `flatMap` | Separa los géneros de cada juego | 50.859 asignaciones en A |
| `union` | Junta los géneros de A y B | 101.685 asignaciones |
| `intersection` | Conserva los géneros compartidos | 19 géneros |
| `subtract` | Devuelve los géneros de A que no están en B | 1 género, `"like reverb"` |

Las transformaciones son perezosas. Ninguna se ejecuta hasta que aparece un `count`, un `collect` o un `take`. Por eso la diapositiva puede mostrar el código sin resultados y la página 7 muestra las acciones que los producen.

### Página 7. Análisis con RDD, acciones

La diapositiva muestra el código de las cuatro acciones y una lista que las explica. Aclara que `count()` y `take()` solo sirven de apoyo y no cuentan como las cuatro acciones exigidas. Esa aclaración es correcta y evita una objeción del evaluador.

| Acción | Lo que dice la diapositiva | Lo que ejecuta el repositorio | Resultado real |
|---|---|---|---|
| `collect()` | Extrae a memoria los 20 géneros distintos | `generos_unidos.distinct().collect()` | 20 géneros |
| `reduce()` | Suma los elementos combinando valores | `map` a 1 y `reduce` con suma | 101.685 |
| `countByValue()` | Cuenta la frecuencia exacta de cada género | `countByValue()` sobre el RDD unido | 20 conteos |
| `takeOrdered()` | Extrae los cinco géneros principales | `takeOrdered(5)` sobre el RDD de conteos | Action, Platformer, Adventure, Puzzle y Shooter |

`collect()` es seguro porque el cardinal es bajo. Trae veinte cadenas al driver. `reduce()` convierte cada género en un 1 y suma todos los valores. `countByValue()` devuelve un diccionario con veinte entradas. `takeOrdered()` ordena un RDD pequeño construido con ese diccionario y devuelve los cinco primeros.

La diapositiva describe bien las acciones, pero no muestra las cifras. Conviene agregar Action 21.452, Platformer 12.683, Adventure 12.286, Puzzle 10.412 y Shooter 9.247, porque son la evidencia de que el RDD funcionó y permiten comparar con DataFrame.

El comentario sobre `takeOrdered()` también es correcto. La acción no se aplica directamente al RDD grande, porque `reduceByKey()` con `takeOrdered()` cuelga el pipe en Windows. El script calcula los conteos con `countByValue()` y ordena el resultado pequeño. Es una decisión de implementación que conviene explicar si preguntan por el rendimiento.

### Página 8. Cierre de RDD e inicio de DataFrame

La página cierra el modelo de bajo nivel con resultados y justifica el salto al modelo tabular. Declara 76.890 juegos con nombre y género, 38.445 en el grupo A, 38.445 en el grupo B y 101.685 asignaciones. Todas esas cifras coinciden con la salida del repositorio.

La página dice 29 géneros diferentes y el valor correcto es 20. De esos 20, 19 son compartidos entre A y B y 1 es exclusivo de A, el valor corrupto `"like reverb"`. La cuenta correcta es 19 más 1. Si se deja 29, la página contradice a la página 7 y al README, que documentan 20.

La transición conceptual está bien planteada. El RDD trabaja con tuplas y funciones lambda, ofrece control sobre cada paso y exige más código manual. El DataFrame organiza los datos en filas y columnas con esquema y deja que Catalyst optimice las consultas. Esa comparación coincide con el cuadro de la página 5 y con la sección RDD y DataFrame frente a frente del README.

La última viñeta necesita dos ajustes. `DataFrame.py` no descarga nada, porque lee el CSV local desde la carpeta del script. Tampoco elimina registros corruptos en sentido amplio. Elimina 306 duplicados con `dropDuplicates()`, deja `null` cuando un valor numérico no se puede convertir y conserva el género `"like reverb"`, que el README documenta como limitación. La frase correcta habla de lectura local del CSV, manejo de esquemas y eliminación de duplicados.

### Página 9. DataFrames, limpieza y preparación

La diapositiva muestra fragmentos de la consola y una tabla con los primeros cinco juegos. Los fragmentos visibles son `2. limpiando`, `juegos que q` y `3. withColum`. La tabla muestra Pewco, A Flower from Hermes, Instinct Z, Brain Theatre y Train, todos con rating 0.0 y categoría Sin calificar.

El flujo real del script tiene seis pasos. Lee el CSV con `header`, `inferSchema`, `quote`, `escape` y `multiLine`. Elimina las 146 columnas vacías con `drop()`. Convierte `rating` a double, `ratings_count` a int y `metacritic` a int con `cast()`. Calcula las estadísticas del rating con `describe()`. Elimina las filas repetidas con `dropDuplicates()`. Agrega la columna `categoria` con `withColumn()`.

La diapositiva dice que `drop()` elimina 146 filas columnas vacías. La palabra correcta es columnas, no filas. También escribe `withColum` sin la N final. Son detalles de redacción, pero conviene corregirlos porque la diapositiva se proyecta.

Los números sostienen la explicación. Antes de limpiar hay 100.565 filas. `dropDuplicates()` elimina 306 y deja 100.259. La tabla de la diapositiva muestra cinco juegos con rating 0.0 porque la mayoría de los registros no tiene votos. Ese 0 se interpreta como ausencia de calificación y no como una nota baja.

La viñeta de control de volumetría se cumple con los dos conteos. La viñeta de optimización tabular se cumple con Catalyst. La diapositiva puede agregar la frase 100.565 antes y 100.259 después para que el impacto de la limpieza quede explícito.

### Página 10. DataFrames, funciones y agregaciones

La diapositiva muestra el resultado de `groupBy().agg()` y una lista de funciones investigadas. La tabla coincide exactamente con la salida del repositorio. Sin calificar tiene 97.101 juegos, rating promedio 0,00 y 8.394 votos. Bueno tiene 1.447 juegos, promedio 3,46 y 121.004 votos. Regular tiene 1.349 juegos, promedio 2,29 y 37.259 votos. Excelente tiene 362 juegos, promedio 4,19 y 91.103 votos.

El script calcula `count("*")` como total de juegos, `round(avg("rating"), 2)` como promedio y `sum("ratings_count")` como votos totales. Después ordena con `orderBy(desc("total_juegos"))` para dejar primero la categoría con más juegos. La suma de las cuatro categorías da 100.259, que es el total después de deduplicar.

La columna `categoria` se construye con cuatro reglas. Un rating nulo queda como Sin calificar. Un rating mayor o igual a 4 queda como Excelente. Un rating mayor o igual a 3 queda como Bueno. Un rating mayor que 0 queda como Regular. Cualquier otro caso queda como Sin calificar, así que el 0 también cae en esa categoría.

La diapositiva escribe `withColumns()` en plural y el repositorio usa `withColumn()` en singular. Conviene mostrar el nombre que se ejecutó. Las funciones investigadas son `describe()`, `dropDuplicates()`, `withColumn()` y `groupBy().agg()`. El apoyo de `filter()`, `split()` y `explode()` se explica en las páginas 11 y 12.

### Página 11. DataFrames, filtro

La diapositiva muestra el resultado de `filter()` con dos condiciones. Conserva los juegos con rating mayor o igual a 4 y al menos 500 votos. El resultado son 63 juegos. La tabla muestra los diez primeros ordenados por cantidad de votos.

El orden de la tabla se debe a `orderBy(desc("ratings_count"))` y no al rating. Portal aparece primero con 4,52 y 3.050 votos. Half-Life 2 aparece segundo con 4,50 y 2.516 votos. Limbo aparece tercero con 4,16 y 2.239 votos. Left 4 Dead 2, INSIDE, Half-Life, Sid Meier's Civilization V, The Wolf Among Us, The Witcher 2 y The Stanley Parable completan los diez primeros.

`filter()` es una transformación y no se ejecuta hasta que aparece `count()` o `show()`. La diapositiva muestra el conteo y la tabla, así que la acción ya ocurrió. Conviene explicar que las dos condiciones se combinan con `&` y que cada una se escribe entre paréntesis para respetar la precedencia.

La imagen adicional que repite la tabla de `groupBy().agg()` de la página 10 sobra. Ocupa espacio y distrae del filtro. Conviene eliminarla o reemplazarla por una frase que recuerde que el filtro se aplica sobre `df_cat`, el DataFrame que ya tiene la columna `categoria`.

### Página 12. DataFrames, géneros

La diapositiva muestra el resultado de `split()` con `explode()`. La tabla coincide con la salida del repositorio. Action tiene 21.440 juegos y promedio 2,99. Platformer tiene 12.674 y 3,37. Adventure tiene 12.273 y 3,03. Puzzle tiene 10.410 y 3,21. Shooter tiene 9.242 y 3,41. Simulation, Indie, Strategy, RPG y Casual completan los diez primeros.

El script separa los géneros con `split(col("genres"), r"\|\|")` y convierte cada elemento en una fila con `explode()`. Después agrupa por género, cuenta los juegos y promedia el rating. El promedio se calcula solo con los juegos calificados, porque casi todos valen 0 y bajarían la media. Por eso la columna se llama `rating_promedio_calificados`.

La expresión regular usa `\|\|` y no `||` porque la barra vertical es un carácter especial en las expresiones regulares. Si se escribe `split("||")` sin escapar, el resultado no es el esperado. La diapositiva no muestra esa línea, pero conviene tenerla presente si preguntan por el código.

La tabla de la diapositiva usa el título cantidad de juegos por género y la columna de promedio. Es correcto. Conviene aclarar que el total de juegos por género no suma 100.259, porque un juego puede tener varios géneros y aparece en varias filas.

### Página 13. Conclusiones

La diapositiva cierra con cuatro ideas. Spark permitió trabajar con videojuegos desde dos enfoques. El RDD ofreció operaciones sobre colecciones distribuidas. El DataFrame facilitó el procesamiento mediante columnas y funciones de agrupación. La elección entre RDD y DataFrame depende de las necesidades del procesamiento.

Las cuatro ideas son correctas y se pueden reforzar con los resultados del taller. El RDD exigió más código manual, pero permitió separar los géneros con `flatMap` y comparar conjuntos con `intersection` y `subtract`. El DataFrame exigió menos código, resolvió la limpieza con `drop`, `cast` y `dropDuplicates`, y resolvió las agregaciones con `groupBy().agg()`.

La conclusión más útil para la exposición es que ambos modelos comparten el mismo motor y el mismo archivo. La diferencia está en la abstracción y en el esfuerzo de programación. Para datos tabulares y consultas de negocio conviene DataFrame. Para datos no tabulares o lógica personalizada conviene RDD. El taller muestra las dos caras con el mismo conjunto.

### Página 14. Bibliografía

La diapositiva lista cuatro fuentes. El conjunto de Kaggle, una página de Spark, la guía de Databricks y el artículo de IBM. Las tres últimas sirven para introducir el motor y su ecosistema. La primera es la fuente del dataset.

Hay un error que debe corregirse. La segunda URL apunta a `sparkmailapp.com`, que es un cliente de correo, y no a la documentación de Apache Spark. La dirección correcta es `spark.apache.org`. También conviene agregar la documentación de Spark 3.3.4 y la referencia de la API de PySpark, porque son las fuentes que explican las funciones usadas en el código.

La bibliografía debe coincidir con las citas del informe. Si el informe menciona a Catalyst o a las transformaciones, conviene que esas afirmaciones tengan una fuente. Las URL pueden mostrarse como dominio plano para que la diapositiva quede limpia.

### Página 15. Cierre

La última diapositiva repite el título, el equipo, la sección y el logo. Es el cierre visual de la exposición. La transcripción muestra a Jesús Poturo y Benjamín González en un orden distinto al de la página 1. Conviene mantener el mismo orden en las dos portadas para evitar dudas.

El cierre puede incluir una frase de agradecimiento y el repositorio `github.com/Nemryz/spark-lab05`. También conviene dejar la diapositiva de conclusiones visible durante las preguntas, porque resume las ideas que el evaluador puede consultar.

### Correcciones para todas las diapositivas

| Página | Texto actual | Texto recomendado |
|---|---|---|
| 1 | Rodigro en el PDF local | Rodrigo |
| 3 | Python 3.1+ | Python 3.10.11 |
| 3 | Java 17 o 21 | JDK 11 |
| 3 | pyspark y kagglehub en requirements | pyspark viene con Spark y no se descarga con kagglehub |
| 3 | Carpeta prueba | Carpeta LaboratorioPyspark |
| 4 | 105.565 filas | 100.565 filas |
| 4 | Sin cifras de duplicados | 306 duplicados y 100.259 filas tras la limpieza |
| 4 | Columnas `_cN` | Columnas `_cNN` |
| 6 | `split("\|")` | `split("\|\|")` |
| 6 | `flatMap` sin paréntesis de cierre | Agregar el paréntesis |
| 7 | Sin resultados numéricos | Agregar el top cinco con sus conteos |
| 8 | 29 géneros diferentes | 20 géneros, 19 compartidos y 1 exclusivo |
| 8 | Descarga limpia y registros corruptos | Lectura local del CSV y eliminación de duplicados |
| 9 | drop() elimina 146 filas columnas vacías | drop() elimina 146 columnas vacías |
| 9 | withColum | withColumn |
| 10 | withColumns() | withColumn() |
| 11 | Tabla repetida de la página 10 | Eliminarla o reemplazarla por una frase |
| 14 | sparkmailapp.com | spark.apache.org |
| 15 | Orden del equipo distinto al de la página 1 | Mantener el mismo orden |

## Problemas encontrados y soluciones

| Problema | Causa | Solución |
|---|---|---|
| `Connection reset by peer` | PySpark 4.2.0 con JDK 17 | Instalar Spark 3.3.4 con JDK 11 |
| `Python worker exited unexpectedly` | `take`, `collect` y `reduce` sobre RDD grandes | Evitar esas llamadas y usar `distinct().take()` o `takeOrdered()` |
| `reduceByKey` con `takeOrdered` se cuelga | El shuffle satura el pipe de Windows | Calcular con `countByValue` y ordenar un RDD pequeño |
| 146 columnas vacías | El encabezado del CSV trae comas de más | Eliminar las columnas `_cNN` |
| `rating` como texto y mayoría en 0 | El origen del dataset | Convertir con `cast` y analizar solo valores mayores que 0 |
| Género `"like reverb"` | Registro corrupto | Documentarlo y excluirlo del análisis |
| El instalador de Python 3.10 falla | El registro de Windows informa una versión previa | El entorno ya está operativo, así que no hace falta repetir la instalación |

## Preguntas de repaso

| Pregunta | Respuesta |
|---|---|
| Qué es Apache Spark | Un motor de procesamiento distribuido que reparte el trabajo entre particiones y executors |
| Qué es un RDD | Una colección distribuida e inmutable de objetos que se transforma con funciones |
| Qué es un DataFrame | Una tabla distribuida con esquema, filas y columnas que se consulta con una API declarativa |
| Qué es un Dataset | Una colección tipada disponible en Scala y Java, sin equivalente tipado en PySpark |
| Cuál es la diferencia entre transformación y acción | La transformación devuelve un nuevo RDD o DataFrame y la acción produce un resultado o escribe datos |
| Qué hace Catalyst | Optimiza el plan lógico y elige un plan físico para las consultas de DataFrame |
| Qué es una partición | Una división del conjunto que se procesa en un executor |
| Por qué se usa `local[1]` | Porque con más hilos aparecieron cuelgues del pipe de Windows durante el shuffle |
| Qué significa evaluación perezosa | Que las transformaciones no se ejecutan hasta que aparece una acción |
| Qué hace `flatMap` | Aplica una función que devuelve varios elementos y aplana el resultado |
| Qué hace `union` | Combina dos RDD conservando todos los elementos |
| Qué hace `intersection` | Conserva solo los elementos presentes en ambos RDD |
| Qué hace `subtract` | Devuelve los elementos del primero que no aparecen en el segundo |
| Qué hace `collect` | Trae la colección completa al driver y por eso exige un cardinal pequeño |
| Qué hace `reduce` | Combina todos los elementos con una función asociativa hasta obtener un valor |
| Qué hace `countByValue` | Cuenta cuántas veces aparece cada valor distinto |
| Qué hace `takeOrdered` | Devuelve los primeros elementos según un orden definido |
| Por qué `takeOrdered` no se aplica al RDD grande | Porque `reduceByKey` con `takeOrdered` cuelga el pipe de Windows |
| Cuántos juegos carga el RDD | 76.890 juegos con nombre y género |
| Cuántos géneros distintos hay | 20, contando el valor corrupto `"like reverb"` |
| Cuál es el top cinco del RDD | Action 21.452, Platformer 12.683, Adventure 12.286, Puzzle 10.412 y Shooter 9.247 |
| Qué columnas elimina el DataFrame | Las 146 columnas vacías que empiezan con `_c` |
| Qué hace `cast` | Convierte el tipo de una columna y deja `null` cuando el valor no es válido |
| Por qué no se usa `try_cast` | Porque Spark 3.3.4 no incluye esa función |
| Cuántas filas quedan después de deduplicar | 100.259 filas |
| Qué significa un rating en 0 | Que el juego no tiene votos y no que tenga una nota baja |
| Cuántos juegos cumplen el filtro | 63 juegos con rating mayor o igual a 4 y al menos 500 votos |
| Cuántos géneros devuelve el DataFrame | 20 géneros, con Action a la cabeza |
| Por qué los conteos de RDD y DataFrame difieren | Porque el RDD filtra por nombre y género y el DataFrame deduplica y descarta géneros nulos |
| Cuántos entregables tiene el taller | El cuadro comparativo, la demo con RDD, la demo con DataFrame, el informe y la exposición |

## Guion de exposición de diez minutos

| Minuto | Diapositivas | Contenido | Responsable sugerido |
|---|---|---|---|
| 0 a 1 | 1 y 2 | Portada, equipo y objetivo del taller | Ignacio |
| 1 a 3 | 3 y 4 | Entorno, instalación y ficha del dataset | Engel |
| 3 a 5 | 5 y 6 | Cuadro comparativo y transformaciones del RDD | Benjamín |
| 5 a 7 | 7 y 8 | Acciones, resultados del RDD y salto al DataFrame | Santiago |
| 7 a 9 | 9 a 12 | Limpieza, funciones, filtros y agregaciones | Matías |
| 9 a 10 | 13 a 15 | Conclusión, bibliografía y cierre | Jesús |

Rodrigo puede encargarse de la demostración en vivo o de responder las preguntas técnicas. Los tiempos son una sugerencia y conviene ajustarlos después del ensayo.

## Lista de verificación antes de entregar

- [ ] El repositorio está clonado en la rama `videojuegos`
- [ ] `.\install\run.ps1 status` muestra Java 11.0.25, Python 3.10.11, Spark 3.3.4 y Hadoop 3.3.6
- [ ] `.\install\run.ps1 submit LaboratorioPyspark\DataFrame.py` termina con código 0
- [ ] `.\install\run.ps1 submit LaboratorioPyspark\Spark_rdd.py` termina con código 0
- [ ] La página 4 dice 100.565 filas
- [ ] La página 8 dice 20 géneros y no 29
- [ ] La página 8 no habla de descarga
- [ ] La bibliografía apunta a `spark.apache.org` y no a `sparkmailapp.com`
- [ ] La errata Rodigro está corregida
- [ ] Las diapositivas 9 y 10 no dicen `texto aqui`
- [ ] El informe está adjunto si el taller lo exige
- [ ] El ensayo de diez minutos se hizo con todos los integrantes

## Referencias

- Apache Spark 3.3.4. Documentación oficial. spark.apache.org/docs/3.3.4
- PySpark API Reference. spark.apache.org/docs/3.3.4/api/python
- Databricks. Getting Started with Apache Spark. databricks.com/spark/getting-started-with-apache-spark
- IBM. What is Apache Spark. ibm.com/topics/apache-spark
- Kaggle. 100000 Video Game Dataset with Records. kaggle.com/datasets/onlypythondatasheet/100000-video-game-dataset-with-records
- RAWG. Video Game Database. rawg.io
