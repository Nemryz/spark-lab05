# Laboratorio 05 de Apache Spark

Este archivo reúne el entorno, la planificación y los criterios del laboratorio 05 de Apache Spark. El tema de datos todavía no está elegido, así que la primera parte presenta candidatos verificados y la segunda describe la metodología, las demostraciones y la entrega con marcadores `[tema]` que se reemplazan cuando el equipo decida.

## Reglas de la entrega

El taller pide un cuadro comparativo entre RDD, DataFrame y Dataset, un ejemplo con RDD que use cuatro transformaciones y cuatro acciones no vistas en clase, y un ejemplo con DataFrame que muestre las funciones vistas en clase más cuatro funciones investigadas por el equipo. Cada equipo debe cubrir los tres puntos.

La conformación de equipos cierra antes de la medianoche del 28 de octubre y se informa por correo. Deben existir cuatro equipos con un mínimo de dos estudiantes y sin máximo, y el docente reasigna a quien quede fuera de ellos. La exposición dura diez minutos con una tolerancia de dos minutos hacia arriba o hacia abajo, y cada minuto fuera de ese rango descuenta dos puntos. Todos los integrantes deben exponer y estar presentes, porque la ausencia individual vale 1,0 y resta dos puntos al equipo.

## Estado actual

El instalador de Windows está terminado y verificado sobre Windows 11 Home con una cuenta estándar. Las doce comprobaciones pasan, un trabajo real de Spark se ejecuta y la interfaz web responde. Falta elegir el tema, construir la ingesta, escribir las dos demostraciones, redactar el informe y preparar la exposición.

## Temas candidatos

Los candidatos cumplen cinco condiciones. Se descargan sin clave ni registro, publican un volumen que justifica Spark, ofrecen columnas numéricas, categóricas y temporales, incluyen algún campo anidado que permita `explode` o `pivot`, y declaran una licencia compatible con un trabajo académico.

| Tema | Fuente | Formato | Volumen | Rasgo útil |
| --- | --- | --- | --- | --- |
| Videojuegos | SteamSpy | JSON por API | Unas 20.000 aplicaciones | Etiquetas y géneros anidados |
| Contratación pública | SECOP II | JSON y CSV | 5,6 millones de contratos | Entidades, modalidades y valores |
| Movilidad urbana | NYC TLC | Parquet | Unos 3 millones de viajes por mes | Fechas, tarifas y zonas |
| Cine | MovieLens | CSV comprimido | 100.000 valoraciones en la muestra pequeña | Géneros separados por barras |
| Cine y series | IMDb | TSV comprimido | 229 MB y unos 11 millones de títulos | Años, géneros y calificaciones |
| Vivienda turística | Inside Airbnb | CSV comprimido | Decenas de miles de avisos por ciudad | Barrios, tipos de alojamiento y precios |
| Aviación | OpenFlights | CSV | Unos 67.000 rutas | Origen, destino y aerolínea |
| Seguridad informática | NVD CVE | JSON por API | Unos 385.000 registros | Severidad, proveedor y fechas |

**SteamSpy.** La API pública en [steamspy.com/api.php](https://steamspy.com/api.php) entrega mil aplicaciones por página y añade género, etiquetas e idiomas al consultar cada juego. Permite separar etiquetas con `explode`, cruzar género con categoría de precio mediante `pivot` y ordenar por propietarios con `Window`. El límite de una petición cada sesenta segundos obliga a cachear el crudo y conviene descargarlo una sola vez.

**SECOP II.** El conjunto [SECOP II - Contratos Electrónicos](https://www.datos.gov.co/d/jbjy-vk9h) publica 5,6 millones de contratos con entidad, proveedor, modalidad, valor y fechas. La API Socrata responde en JSON y el portal ofrece una [descarga completa en CSV](https://www.datos.gov.co/api/views/jbjy-vk9h/rows.csv?accessType=DOWNLOAD). Sirve para `join` entre contratos y proveedores, `pivot` por modalidad y `Window` por entidad. La licencia es CC BY-SA 4.0 y no exige clave.

**NYC TLC.** Los [registros de viajes de taxi de Nueva York](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) se publican en Parquet por mes, con unos 50 MB y cerca de tres millones de filas por archivo. Un solo mes alcanza para las demostraciones y varios meses permiten comparar estaciones. Aporta marcas de tiempo, tarifas, propinas y zonas, de modo que habilita `Window` por hora, `pivot` por tipo de pago y `join` con la tabla de zonas. No requiere clave.

**MovieLens.** [GroupLens](https://grouplens.org/datasets/movielens/) distribuye calificaciones de películas en CSV comprimido. La versión pequeña pesa menos de un megabyte y contiene 100.000 valoraciones, mientras que la completa supera los 200 MB y llega a 32 millones. Los géneros vienen separados por barras, así que `explode` resulta natural, y `Window` permite ordenar por usuario o por película. La licencia autoriza el uso académico.

**IMDb.** Los [archivos públicos de IMDb](https://datasets.imdbws.com/) incluyen títulos, calificaciones y tripulaciones en TSV comprimido. `title.basics.tsv.gz` pesa 229 MB y reúne unos once millones de títulos con año, géneros y duración. Es la opción con mayor volumen inicial y exige filtrar antes de procesar, lo que se convierte en una buena lección de particionado. El uso es no comercial.

**Inside Airbnb.** El portal [Inside Airbnb](https://insideairbnb.com/get-the-data/) publica por ciudad los avisos, el calendario y las reseñas en CSV comprimido. Los avisos traen barrio, tipo de alojamiento, precio, disponibilidad y número de reseñas, de modo que `pivot` por tipo, `Window` por barrio y `join` con el calendario cubren las demostraciones. La licencia es abierta y cada archivo se descarga directamente.

**OpenFlights.** El repositorio [OpenFlights](https://github.com/jpatokal/openflights/tree/master/data) mantiene rutas, aeropuertos, aerolíneas y aviones en CSV sin encabezado. El archivo de rutas pesa 2,3 MB y contiene unas 67.000 conexiones, suficiente para `join` entre rutas y aeropuertos y para `Window` por aerolínea. La licencia es Open Database License y el volumen permite probar sin esperas.

**NVD CVE.** La [API de vulnerabilidades del NIST](https://nvd.nist.gov/developers/vulnerabilities) entrega registros JSON con severidad, proveedor, debilidades y fechas. El catálogo supera los 385.000 registros y se consulta en páginas de dos mil, aunque el servicio limita la frecuencia y conviene descargar por rangos de fecha. Los campos anidados permiten `explode` de debilidades y `pivot` por severidad. No requiere clave para el uso básico.

**Alternativas.** La API de [Jolpica para Fórmula 1](https://api.jolpi.ca/ergast/) reúne 26.000 resultados históricos y funciona sin clave desde que Ergast dejó de responder. La API de [TVmaze](https://www.tvmaze.com/api) publica series y episodios en JSON paginado y se presta para `explode` de géneros. La API del [Banco Mundial](https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?format=json) entrega indicadores por país y año con 17.000 observaciones por indicador.

Quedan descartadas las fuentes que exigen autenticación, como Kaggle y Yelp, las que superan los 7 GB de descarga, como StatsBomb, y las que dependen de una clave privada.

## Selección del tema

El equipo comparará los candidatos con cuatro preguntas. ¿Cuánto tarda la descarga completa en una conexión doméstica? ¿El esquema permite las cuatro transformaciones y las cuatro funciones sin forzar el ejemplo? ¿La licencia autoriza publicar una muestra en el repositorio? ¿La API se mantiene estable durante las dos semanas del trabajo? La decisión se documenta en una línea dentro de este archivo y se reemplaza el marcador `[tema]` en todas las secciones.

## Ingesta genérica

Los scripts no dependen del tema porque reciben el nombre como argumento. `scripts\get_data.py` descarga el recurso, guarda un manifiesto con URL, fecha y SHA256 y reanuda desde el último archivo cuando se interrumpe. `scripts\build_curated.py` normaliza tipos, separa listas y deriva columnas. `scripts\make_sample.py` produce una muestra versionada de 5.000 filas y menos de 5 MB.

```powershell
.\install\run.ps1 python scripts\get_data.py --source [tema] --resource [recurso] --delay [segundos]
.\install\run.ps1 python scripts\build_curated.py --source [tema]
.\install\run.ps1 python scripts\make_sample.py --source [tema] --rows 5000
```

El crudo queda en `data\raw\[tema]\[recurso]_000.json` y siguientes, la curación en `data\curated\[tema]` y la muestra en `data\sample\[tema]_sample.csv`. Las carpetas de crudo y curación se ignoran en git porque el contenido se reconstruye con el manifiesto, mientras que la muestra sí se versiona.

## Esquema genérico

| Columna | Tipo | Ejemplo | Uso previsto |
| --- | --- | --- | --- |
| id | entero | 730 | Clave de unión y particionado |
| categoria | texto | Acción | `distinct`, `countByValue`, `pivot` |
| subcategoria | texto | Indie | Cruces y filtros |
| valor | decimal | 19.99 | `aggregate`, `takeOrdered`, promedios |
| fecha | fecha | 2026-10-29 | `Window` por periodo |
| texto | texto | Edición deluxe | `regexp_replace` y limpieza |
| etiquetas | lista de texto | cooperativo, multijugador | `explode` |
| metricas | estructura | positivas, negativas | Acceso anidado |

Cada tema conserva sus nombres reales y la tabla anterior solo fija los roles. La curación traduce los rangos, los precios en centavos y las fechas en texto a tipos utilizables, y descarta las filas sin clave.

## Demo con RDD

La demostración parte del crudo curado y recorre cuatro transformaciones y cuatro acciones distintas de las vistas en clase, que son `map`, `filter`, `flatMap`, `reduceByKey`, `collect`, `count`, `take` y `reduce`. La selección propuesta usa `mapPartitionsWithIndex` para mostrar el reparto de particiones, `distinct` para reducir categorías, `join` para cruzar el catálogo con los hechos y `partitionBy` para controlar el particionado antes de una acción costosa.

Las acciones propuestas son `takeOrdered` para obtener los mayores valores, `aggregate` para calcular un promedio con acumuladores propios, `countByValue` para contar categorías sin pasar por un `reduceByKey` y `foreachPartition` para escribir un resumen por partición. Cada paso imprime el número de particiones antes y después, de modo que el informe explique dónde ocurre un shuffle y por qué.

## Demo con DataFrame

La demostración reproduce las operaciones vistas en clase con `select`, `filter`, `groupBy`, `agg` y `orderBy`, y añade cuatro funciones investigadas. La propuesta usa `Window` para ordenar dentro de cada categoría, `pivot` para cruzar categoría con rango de valor, `explode` para separar las etiquetas y `regexp_replace` para limpiar el texto antes de agrupar.

El cierre compara la misma consulta con RDD y con DataFrame, mide el tiempo de cada una y muestra el plan físico con `explain(True)`. Esa evidencia alimenta el cuadro comparativo y la conclusión sobre cuándo conviene cada interfaz.

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

PySpark no expone `Dataset`, puesto que el tipo `Dataset[T]` pertenece a Scala y Java, donde el `Encoder[T]` conserva el esquema en tiempo de compilación. En Python toda la API tabular pasa por `DataFrame`, que equivale a un `Dataset[Row]` sin tipado estático. La comparativa incluirá un fragmento de Scala en el informe y la medición real de RDD contra DataFrame.

## Metodología de trabajo

El equipo trabaja en seis fases cortas. La primera cierra la conformación y el correo al docente antes del 28 de octubre. La segunda elige el tema con la lista anterior y justifica la decisión. La tercera construye la ingesta y la muestra reproducible. La cuarta escribe la demostración de RDD y verifica las ocho funciones. La quinta hace lo propio con DataFrame y recoge los tiempos. La sexta redacta el informe, arma las diapositivas y ensaya la exposición con cronómetro.

Los roles se reparten sin excluir a nadie de la exposición. Una persona coordina entregas y correos, otra responde por la ingesta, otra por la demostración de RDD, otra por la de DataFrame y otra por el informe y las diapositivas. Todos leen el código de los demás antes del ensayo, porque cualquier integrante puede recibir una pregunta sobre cualquier parte.

## Plan de la exposición

| Minuto | Contenido | Quién |
| --- | --- | --- |
| 0 a 1 | Portada, objetivo y tema elegido | Coordinación |
| 1 a 3 | Cuadro comparativo entre las tres interfaces | Redacción |
| 3 a 6 | Demostración de RDD y explicación de las ocho funciones | RDD |
| 6 a 9 | Demostración de DataFrame y plan de ejecución | DataFrame |
| 9 a 10 | Conclusiones, límites y cierre | Todo el equipo |

El ensayo se hace al menos dos veces con cronómetro, porque la tolerancia es de dos minutos y cada minuto extra descuenta dos puntos. Las diapositivas muestran capturas reales de la ejecución y no solo código.

## Riesgos y mitigación

| Riesgo | Señal temprana | Mitigación |
| --- | --- | --- |
| Límite de la API | Respuestas 429 o esperas largas | Cachear el crudo y descargarlo una sola vez |
| Volumen excesivo | Descarga de más de 1 GB | Elegir un mes, una ciudad o un rango de fechas |
| Licencia incompatible | Texto restrictivo en el portal | Publicar solo la muestra y citar la fuente |
| Memoria insuficiente | Error de paginación al arrancar | Mantener el heap en 1 GB y reducir particiones |
| Tiempo de exposición | Ensayo por encima de 12 minutos | Recortar la demostración y dejar el detalle en el informe |
| API caída | Error 5xx el día previo | Guardar el crudo y trabajar desde la caché |

## Entorno de trabajo

Se necesita Windows 10 u 11, PowerShell 5.1 o superior, unos 3 GB libres y conexión durante la primera instalación. No hace falta ser administrador ni tener Java o Python instalados.

```powershell
.\install\install-spark.ps1
.\install\verify-install.ps1
.\install\run.ps1 status
```

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
├─ scripts/                          Ingesta y curacion de [tema]
├─ data/
│  ├─ raw/[tema]/                    Crudo, ignorado por git
│  ├─ curated/[tema]/                Tablas limpias, ignoradas por git
│  └─ sample/                        Muestra versionada
├─ src/                              Demos ejecutables en Python
├─ notebooks/                        Cuadernos de las demos
├─ tests/                            Trabajo de humo y pruebas Pester
└─ slides/                           Presentacion
```

Las carpetas `scripts`, `notebooks` y `slides` aparecen en el plan y se crean cuando empieza cada fase.

## Pendientes

Falta elegir el tema entre los candidatos, escribir los tres scripts de ingesta con el marcador `[tema]`, implementar las dos demostraciones, completar el cuadro comparativo con las mediciones, redactar el informe y preparar las diapositivas. También queda pendiente confirmar con el docente qué funciones de DataFrame se vieron en clase y la fecha exacta de la exposición.
