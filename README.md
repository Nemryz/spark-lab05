# Laboratorio 05 de Apache Spark

Este documento reúne el enunciado, el plan y la ejecución del laboratorio 05 de Apache Spark. El tema elegido es el catálogo público de IMDb y todas las secciones describen ese conjunto, de modo que el archivo sirve a la vez como guía de trabajo, como justificación de las decisiones y como evidencia de lo que se entrega.

## Qué pide el enunciado

El taller califica cinco puntos. El primero es un cuadro comparativo entre RDD, DataFrame y Dataset. El segundo es un ejemplo con RDD que use cuatro transformaciones y cuatro acciones distintas de las vistas en clase. El tercero es un ejemplo con DataFrame que muestre las funciones vistas en clase más cuatro funciones investigadas por el equipo. El cuarto es la conformación de cuatro equipos con un mínimo de dos estudiantes, informada por correo antes de la medianoche del 28 de octubre. El quinto es una exposición de diez minutos.

| Punto | Lo que se entrega | Cómo se comprueba |
| --- | --- | --- |
| Cuadro comparativo | Tabla con criterios de abstracción, tipado, optimización, serialización y uso | Se lee en el informe y en las diapositivas |
| Ejemplo con RDD | Script ejecutable con cuatro transformaciones y cuatro acciones nuevas | La salida imprime el nombre de cada función |
| Ejemplo con DataFrame | Script ejecutable con las funciones de clase más cuatro investigadas | La salida imprime el nombre de cada función |
| Equipos | Correo con la lista de integrantes antes del cierre | Acuse del docente |
| Exposición | Diez minutos con tolerancia de dos minutos | Cronómetro del docente |

Las condiciones de la exposición son estrictas. Cada minuto fuera del rango de ocho a doce minutos descuenta dos puntos sobre la nota. Todos los integrantes deben exponer y estar presentes al momento de la entrega, porque la ausencia de una persona vale 1,0 individualmente y resta dos puntos al equipo. La conformación también tiene regla propia, ya que deben existir cuatro equipos, el mínimo es de dos estudiantes y el docente reasigna a quien quede sin equipo.

## Qué hay que hacer

El trabajo se parte en seis piezas que se verifican por separado. Cada una tiene un archivo responsable y un criterio de aceptación que no depende de interpretaciones.

| Entregable | Archivo | Criterio de aceptación |
| --- | --- | --- |
| Ingesta | `scripts\get_data.py` y `scripts\build_curated.py` | Reproduce los datos desde cero con un solo comando por paso |
| Muestra | `data\sample\imdb_sample.csv` | 5.000 filas, menos de 5 MB y versión en git |
| Demo con RDD | `src\rdd_lab.py` | Ocho funciones etiquetadas, cuatro transformaciones y cuatro acciones |
| Demo con DataFrame | `src\dataframe_lab.py` | Nueve funciones etiquetadas, cinco de clase y cuatro investigadas |
| Cuadro comparativo | Este archivo y el informe | Criterios con fuente y una fila de medición real |
| Informe | `informe\informe.pdf` | Resultados, capturas y conclusiones |
| Exposición | `diapositivas\presentacion.pdf` | Diez minutos y todos los integrantes hablando |

La ingesta es la base de todo lo demás. Si la descarga no queda registrada con su hash, la muestra no se puede reconstruir y el informe pierde trazabilidad. Por eso el primer script escribe un manifiesto con URL, tamaño, fecha y SHA256 de cada archivo, y el segundo convierte ese crudo en Parquet tipado sin volver a descargar nada.

Las dos demos son independientes entre sí. La de RDD trabaja con pares clave valor y con un particionador explícito. La de DataFrame trabaja con columnas nombradas y deja que Catalyst decida el plan. Cada una imprime el nombre de la función antes de usarla, de modo que la salida sirva como evidencia en la exposición.

El cierre tiene cuatro pasos que no aparecen en la tabla porque son de proceso. Enviar el correo de conformación, ensayar con cronómetro al menos dos veces, revisar que todos puedan explicar cualquier punto y guardar las capturas de ejecución antes de armar las diapositivas.

## Cómo funciona

El flujo tiene cinco estaciones y cada una produce algo que la siguiente consume. El crudo se descarga una sola vez, la curaduría lo convierte en columnas tipadas, y las demos leen ese resultado sin tocar la red.

```text
datasets.imdbws.com
        |
        v
data/raw/imdb/*.tsv.gz  +  manifest.json
        |
        v
data/curated/imdb/titles/  +  ratings/  (Parquet)
data/curated/imdb/titles.tsv  +  ratings.tsv  (texto plano)
        |
        +--> src/rdd_lab.py  ----------> salida por consola
        |
        +--> src/dataframe_lab.py -----> salida por consola, plan y tiempos
        |
        v
data/sample/imdb_sample.csv
        |
        v
informe/informe.pdf  +  diapositivas/presentacion.pdf
```

Los comandos se ejecutan siempre a través del lanzador, que carga el entorno del laboratorio y fija la memoria del controlador antes de arrancar la JVM.

```powershell
.\install\run.ps1 python scripts\get_data.py --resource basics
.\install\run.ps1 python scripts\get_data.py --resource ratings
.\install\run.ps1 python scripts\build_curated.py
.\install\run.ps1 python scripts\make_sample.py --rows 5000
.\install\run.ps1 python tests\check_data.py
.\install\run.ps1 submit src\rdd_lab.py
.\install\run.ps1 submit src\dataframe_lab.py
```

| Paso | Qué produce | Qué se espera ver |
| --- | --- | --- |
| Descarga | `title.basics.tsv.gz`, `title.ratings.tsv.gz` y `manifest.json` | Dos líneas con bytes y SHA256 |
| Curaduría | `titles` y `ratings` en Parquet y en TSV | 71.355 títulos y 1.727.597 notas |
| Muestra | `imdb_sample.csv` | 5.000 filas y el peso del archivo |
| Demo con RDD | Ocho bloques en consola | Particiones, conteos y top de votos |
| Demo con DataFrame | Nueve bloques, el plan y los tiempos | Plan físico y milisegundos por consulta |

La descarga se reanuda desde el último byte cuando se interrumpe, gracias a una petición por rango sobre el archivo parcial. La curaduría lee el TSV por transmisión, sin cargarlo entero en memoria, y escribe Parquet por bloques. Ese detalle es el que permite procesar 1,12 GB con un equipo de 8 GB.

## El conjunto elegido

IMDb publica dos archivos que cubren todo lo que el taller necesita. El primero describe cada título con su clave, su tipo, su año, su duración y sus géneros. El segundo añade la nota media y el número de votos para los títulos que tienen suficientes calificaciones.

| Archivo | Comprimido | Sin comprimir | Contenido |
| --- | --- | --- | --- |
| `title.basics.tsv.gz` | 219 MB | 1,12 GB | 12.916.450 títulos |
| `title.ratings.tsv.gz` | 8,3 MB | 30 MB | 1.727.597 títulos calificados |

Los archivos están en [datasets.imdbws.com](https://datasets.imdbws.com/), se descargan sin clave ni registro, vienen en TSV con cabecera y usan `\N` para el valor nulo. La licencia permite uso personal y no comercial, así que el repositorio publica solo la muestra de 5.000 filas y el informe cita la fuente.

La elección se sostiene en cinco razones. El volumen de 1,12 GB justifica el uso de Spark y obliga a hablar de particiones. La clave `tconst` aparece en los dos archivos y habilita un `join` real. La columna `genres` trae listas separadas por comas y permite `explode` sin inventar datos. Los años y las notas permiten `Window`, promedios y percentiles. Y la descarga no depende de una API con límite de peticiones, que es el riesgo más común en los otros temas.

Quedaron atrás los demás candidatos por razones concretas. SECOP II depende de un portal que cambia de esquema, NYC TLC obliga a elegir un mes, MovieLens se queda corto de volumen, Inside Airbnb dispersa los datos por ciudad, OpenFlights no alcanza las 70.000 filas y NVD limita la frecuencia de consulta. IMDb gana porque un solo par de archivos cubre claves, categorías, años, números y listas.

## Esquema

La curaduría conserva los nombres originales y añade dos columnas derivadas. La tabla siguiente fija el tipo de cada una y el uso que tiene en las demos.

| Columna | Tipo | Origen | Uso en las demos |
| --- | --- | --- | --- |
| `tconst` | texto | basics y ratings | Clave del `join` y del `partitionBy` |
| `titleType` | texto | basics | `countByValue`, `pivot` y filtros |
| `primaryTitle` | texto | basics | `regexp_replace` y muestras |
| `startYear` | entero | basics | `Window` por década y filtro temprano |
| `runtimeMinutes` | entero | basics | `aggregate` y promedios |
| `genres` | texto con comas | basics | `explode` y `pivot` |
| `averageRating` | decimal | ratings | `takeOrdered` y `Window` |
| `numVotes` | entero | ratings | `aggregate` y ranking |
| `decade` | entero | derivada de `startYear` | Agrupación por periodo y `Window` |

La curaduría aplica cuatro reglas. Descarta las filas sin `tconst`, traduce `\N` a nulo, convierte años y duraciones a enteros y conserva los títulos con mil votos o más, salvo los episodios de serie. Con ese filtro quedan 71.355 títulos y 18,8 MB de Parquet, mientras que las notas conservan 1.727.597 filas para que el `join` muestre tanto las claves que emparejan como las que sobran. La columna `genre` no se almacena, la produce `explode` dentro de la demo de DataFrame.

## Demo con RDD

La demo lee el TSV curado como texto para mostrar el costo de interpretar cada línea a mano, y después encadena las ocho funciones sobre pares clave valor. El orden importa porque deja ver dónde aparece un shuffle y qué lo evita. Como el archivo no está comprimido, la demo lo abre con ocho particiones mínimas y muestra el conteo real de cada una.

| Función | Tipo | Qué hace en la demo | Salida esperada |
| --- | --- | --- | --- |
| `mapPartitionsWithIndex` | Transformación | Recorre cada partición con su índice y cuenta elementos | Una línea por partición con su conteo |
| `distinct` | Transformación | Reduce los tipos de título a su conjunto único | Menos de diez valores |
| `join` | Transformación | Cruza títulos con calificaciones por `tconst` | Conteo de pares emparejados |
| `partitionBy` | Transformación | Reparte por hash de `tconst` antes del `join` | Conteo por partición sin huecos |
| `takeOrdered` | Acción | Devuelve las diez películas con más votos | Diez tuplas ordenadas |
| `aggregate` | Acción | Calcula la nota media ponderada por votos | Un decimal con la nota global |
| `countByValue` | Acción | Cuenta títulos por tipo sin `reduceByKey` | Diccionario con el conteo |
| `foreachPartition` | Acción | Escribe un resumen por partición | Un archivo con una línea por partición |

Las cuatro transformaciones elegidas no aparecen en la lista de clase, que son `map`, `filter`, `flatMap` y `reduceByKey`. Las cuatro acciones tampoco aparecen en la otra lista, que son `collect`, `count`, `take` y `reduce`. `map` y `filter` sí se usan como apoyo para parsear y limpiar, pero no cuentan como las funciones nuevas y la salida las marca como auxiliares.

La demo imprime el número de particiones antes y después de cada paso. Ese detalle permite explicar en el informe que `join` y `distinct` provocan un shuffle, que `partitionBy` lo hace una sola vez y que el `join` posterior lo aprovecha, y que `takeOrdered` solo mueve un montón pequeño al controlador.

## Demo con DataFrame

La demo responde cinco preguntas con las funciones vistas en clase y cuatro más con funciones investigadas. Cada bloque imprime la consulta, el resultado y el plan físico para que la comparación con RDD use la misma evidencia.

| Función | Origen | Pregunta que resuelve |
| --- | --- | --- |
| `select` | Clase | Proyecta clave, título, año y nota |
| `filter` | Clase | Deja películas desde 1990 con más de mil votos |
| `groupBy` | Clase | Agrupa por género y década |
| `agg` | Clase | Calcula promedio de nota y suma de votos |
| `orderBy` | Clase | Ordena por nota y desempata por votos |
| `Window` con `row_number` | Investigada | Tres mejores títulos por género |
| `pivot` | Investigada | Nota media por década y tipo de título |
| `explode` con `split` | Investigada | Un renglón por género a partir de la lista |
| `regexp_replace` | Investigada | Normaliza títulos para detectar repetidos |

El cierre ejecuta la misma consulta con las dos interfaces, mide el tiempo con `time.perf_counter` y guarda el resultado en `informe\mediciones.csv` con tres columnas, consulta, interfaz y milisegundos. Esa tabla alimenta la fila de medición del cuadro comparativo y la conclusión sobre cuándo conviene cada interfaz.

La demo usa además `corr` para mostrar la relación entre duración y nota, y `percentile_approx` para la mediana de votos por género. Esas dos funciones quedan como refuerzo en el informe y no reemplazan a las cuatro investigadas.

## Comparativa de las tres interfaces

| Criterio | RDD | DataFrame | Dataset |
| --- | --- | --- | --- |
| Nivel de abstracción | Colección distribuida de objetos | Tabla con esquema y nombres de columna | Tabla tipada con un codificador |
| Tipado | Dinámico, el usuario interpreta cada elemento | Esquema en tiempo de ejecución | Estático en Scala y Java |
| Verificación en compilación | No existe | No existe | La ofrece el compilador |
| Optimización | Ninguna, el usuario decide el plan | Catalyst y Tungsten | Catalyst y Tungsten con codificadores |
| Serialización | Java o Kryo | Binaria de Tungsten | Binaria guiada por el codificador |
| API disponible en Python | Sí | Sí | No |
| Casos de uso | Control fino y datos sin estructura | ETL, SQL y analítica tabular | Dominios tipados sobre la JVM |
| Depuración | Errores en tiempo de ejecución | Plan físico legible con `explain` | Errores de tipo antes de ejecutar |
| Medición en la misma consulta | Se registra en `informe\mediciones.csv` | Se registra en `informe\mediciones.csv` | No aplica en Python |
| Líneas de código | Más, por el parseo manual | Menos, por las columnas nombradas | Intermedio, con clases del dominio |

PySpark no expone `Dataset`, puesto que el tipo `Dataset[T]` pertenece a Scala y Java, donde el `Encoder[T]` conserva el esquema en tiempo de compilación. En Python toda la API tabular pasa por `DataFrame`, que equivale a un `Dataset[Row]` sin tipado estático. El informe incluye un ejemplo corto en Scala para mostrar la diferencia real.

```scala
case class Title(tconst: String, titleType: String, startYear: Int, averageRating: Double)

val titles = spark.read.parquet("data/curated/imdb/titles").as[Title]
titles.filter(t => t.startYear >= 2000 && t.averageRating >= 8.0)
      .groupBy("titleType")
      .avg("averageRating")
```

Ese fragmento se ejecuta en `.\install\run.ps1 shell` si el equipo quiere una captura real de `Dataset`. Es opcional, porque el taller solo exige el cuadro y no un ejemplo ejecutable en Scala.

## Metodología de trabajo

El equipo trabaja en seis fases cortas. La primera cierra la conformación y envía el correo con la lista de integrantes. La segunda confirma el tema y deja escrita la justificación. La tercera construye la descarga y la curaduría, que es el paso más lento por el tamaño del archivo. La cuarta escribe la demo de RDD y verifica las ocho funciones. La quinta hace lo mismo con DataFrame y recoge los tiempos. La sexta redacta el informe, arma las diapositivas y ensaya con cronómetro.

Los roles se reparten sin excluir a nadie de la exposición. Una persona coordina entregas y correos, otra responde por la ingesta, otra por la demo de RDD, otra por la de DataFrame y otra por el informe y las diapositivas. Cuando el equipo tiene solo dos integrantes, cada uno asume dos bloques y el quinto se reparte por mitades. Todos leen el código de los demás antes del ensayo, porque cualquier integrante puede recibir una pregunta sobre cualquier parte.

## Plan de la exposición

| Minuto | Contenido | Quién |
| --- | --- | --- |
| 0 a 1 | Portada, objetivo y por qué IMDb | Coordinación |
| 1 a 3 | Cuadro comparativo entre las tres interfaces | Redacción |
| 3 a 6 | Demo de RDD y explicación de las ocho funciones | RDD |
| 6 a 9 | Demo de DataFrame, plan y tiempos | DataFrame |
| 9 a 10 | Conclusiones, límites y cierre | Todo el equipo |

El ensayo se hace al menos dos veces con cronómetro, porque la tolerancia es de dos minutos y cada minuto extra descuenta dos puntos. Las diapositivas muestran capturas reales de la ejecución y no solo código, y cada bloque de código aparece con su salida al lado.

## Riesgos y mitigación

| Riesgo | Señal temprana | Mitigación |
| --- | --- | --- |
| Memoria insuficiente | `OutOfMemoryError` o paginación al arrancar | Mantener el filtro de mil votos y el heap en 1 GB |
| Descarga lenta | Menos de 1 MB por segundo | Reanudar por rango y conservar el crudo comprimido |
| Disco lleno | Menos de 2 GB libres | Conservar solo el gzip y borrar los archivos parciales |
| Nulo mal leído | `\N` aparece como texto en los resultados | Reemplazar por nulo durante la curaduría |
| Licencia | Texto restrictivo en el sitio | Publicar solo la muestra y citar la fuente |
| Tiempo de exposición | Ensayo por encima de 12 minutos | Recortar la demo y dejar el detalle en el informe |
| Sitio caído | Error 5xx el día previo | Trabajar desde la caché local y el manifiesto |

## Entorno de trabajo

Se necesita Windows 10 u 11, PowerShell 5.1 o superior, unos 4 GB libres y conexión durante la primera instalación. No hace falta ser administrador ni tener Java o Python instalados, y tampoco hace falta un gestor de paquetes.

```powershell
.\install\install-spark.ps1
.\install\verify-install.ps1
.\install\run.ps1 status
```

El instalador descarga con `curl.exe` y usa `Invoke-WebRequest` como respaldo, extrae con `tar.exe` y `Expand-Archive`, y todo eso viene incluido en Windows 10 1803 o superior. Tampoco instala git, porque cuando falta descarga `winutils.exe` y `hadoop.dll` directamente desde el repositorio y verifica su SHA256. Git solo se necesita para clonar el repositorio, y quien no lo tenga puede bajar el ZIP desde GitHub.

Los scripts calculan la raíz desde su propia ubicación, así que el repositorio funciona en cualquier carpeta, unidad y usuario. La primera ejecución tarda entre 10 y 20 minutos y las siguientes omiten lo que ya existe.

| Componente | Versión | Destino | Comprobación |
| --- | --- | --- | --- |
| Apache Spark | 3.3.4 con Hadoop 3 | `%SystemDrive%\spark` | SHA512 oficial |
| Eclipse Temurin | 11.0.25+9 | `%SystemDrive%\jdk` | SHA256 de Adoptium |
| winutils y hadoop.dll | 3.3.6 | `%SystemDrive%\winutils\bin` | SHA256 por binario |
| Python | 3.10.11 | `<repo>\.tools\python310` | SHA256 del instalador |
| Entorno virtual | 3.10 | `<repo>\.venv` | Hash de `requirements.txt` |

Cuando la unidad del sistema no es escribible, Spark, el JDK y winutils pasan a `%LOCALAPPDATA%\spark-lab`. Si existe un JDK 11 previo, se reutiliza y no se descarga otra copia. Python 3.10 es obligatorio porque PySpark 3.3.4 importa `distutils`, eliminado en 3.12, y el `JAVA_HOME` global se conserva para no romper otras materias.

La ruta admite espacios y cualquier unidad, aunque se rechazan `&`, `|`, `<`, `>`, `^`, `%` y `!` porque rompen los scripts `.cmd` de Spark. Las rutas con caracteres no ASCII generan una advertencia.

| Parámetro | Efecto |
| --- | --- |
| `-ProjectRoot <ruta>` | Raíz del repositorio. Por defecto, el padre de `install\`. |
| `-UserRoot <ruta>` | Raíz de Spark, JDK y winutils. Por defecto, la unidad del sistema. |
| `-FallbackRoot <ruta>` | Raíz alternativa si la principal no es escribible. |
| `-SparkHome`, `-JavaHome`, `-HadoopHome` | Destinos explícitos por componente. |
| `-PythonHome`, `-VenvPath` | Destinos de Python y del entorno virtual. |
| `-CachePath <ruta>` | Descargas. Por defecto `<repo>\cache`. |
| `-SkipJava`, `-SkipSpark`, `-SkipWinutils`, `-SkipPython` | Omite ese componente. |
| `-NoUserEnv` | No modifica las variables de usuario. |
| `-Offline` | Usa solo la caché. |
| `-Force` | Reinstala aunque la versión sea correcta. |
| `-DryRun` | Muestra el plan sin escribir nada. |
| `-Ci` | Modo no interactivo. |
| `-NoGit` | Descarga winutils sin clonar el repositorio. |

`install\spark-env.ps1` guarda las rutas y lo carga `run.ps1`. El instalador registra en `HKCU` solo `SPARK_HOME`, `HADOOP_HOME`, un `JAVA_HOME` cuando antes no existía y las entradas de `PATH`, y antes guarda una copia en `install\env-backup.json`. El heap del controlador se fija en 1 GB con 64 MB iniciales para que Spark arranque en equipos de 8 GB.

| Comando | Efecto |
| --- | --- |
| `.\install\run.ps1 status` | Muestra rutas, versiones e IP local. |
| `.\install\run.ps1 pyspark` | Abre la consola de PySpark. |
| `.\install\run.ps1 submit src\rdd_lab.py` | Envía un script con la memoria del laboratorio. |
| `.\install\run.ps1 python tests\smoke_test.py` | Ejecuta el Python del entorno virtual. |
| `.\install\run.ps1 jupyter` | Inicia JupyterLab. |
| `.\install\run.ps1 shell` | Abre la consola de Scala. |

La verificación cubre el archivo de entorno, el estado de instalación, Java 11, los archivos y la versión de Spark, los hashes y la ejecución de winutils, Python 3.10, los paquetes, un trabajo real con CSV, agrupación y Parquet, la interfaz web y la preparación del equipo en hostname, rutas largas, espacio y `PATH`. Devuelve código 1 si algo falla y acepta `-Json` y `-SkipSmoke`.

```powershell
.\install\uninstall-spark.ps1
.\install\uninstall-spark.ps1 -Purge -Confirmed
```

La prueba sin privilegios se hace con una cuenta local estándar, porque GitHub Actions ejecuta como administrador y Windows Home no ofrece Sandbox.

```powershell
net user sparktest "Temporal123!" /add
net user sparktest /delete
```

El flujo `.github/workflows/installer.yml` cubre sintaxis y pruebas Pester, instalación limpia e idempotente, verificación completa, ruta con espacios, instalación sin git y aborto por checksum inválido. Solo se ejecuta cuando el repositorio se publica.

## Estructura del repositorio

```text
Spark/
├─ .github/workflows/installer.yml   Integracion continua
├─ install/                          Instalador, verificacion y lanzadores
├─ scripts/                          Descarga, curaduria y muestra de IMDb
├─ data/
│  ├─ raw/imdb/                      TSV comprimido, ignorado por git
│  ├─ curated/imdb/                  Parquet y TSV curados, ignorado por git
│  └─ sample/                        Muestra versionada
├─ src/                              rdd_lab.py y dataframe_lab.py
├─ informe/                          Informe en PDF y figuras
├─ diapositivas/                     Presentacion en PDF
├─ tests/                            Humo, comprobación de datos y Pester
└─ README.md                         Este documento
```

Las carpetas `informe` y `diapositivas` se crean cuando empieza esa fase.

## Estado

| Parte | Estado |
| --- | --- |
| Instalador, verificación y flujo de integración | Terminado y verificado con 12 comprobaciones |
| Documento único con el enunciado y el plan | Terminado |
| Descarga y curaduría de IMDb | Terminada, 71.355 títulos y 18,8 MB |
| Muestra versionada | Terminada, 5.000 filas y 479 KB |
| Comprobación de datos | Terminada, siete verificaciones en verde |
| Demo con RDD | Pendiente, con las ocho funciones ya elegidas |
| Demo con DataFrame | Pendiente, con las nueve funciones ya elegidas |
| Cuadro comparativo con mediciones | Pendiente de la ejecución |
| Informe y diapositivas | Pendientes |

El siguiente paso es escribir `src\rdd_lab.py`, que ya tiene las ocho funciones elegidas y los TSV curados como entrada. Después sigue `src\dataframe_lab.py` con las nueve funciones, y la medición de ambas alimenta el cuadro comparativo y el informe.
