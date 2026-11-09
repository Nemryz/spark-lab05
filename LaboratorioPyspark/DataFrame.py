# librerias nativas de python para buscar y mover archivos en el computador
import os
import shutil

# libreria para que python logre ubicar donde esta instalado apache spark
# (con pip a veces no hace falta, por eso va en try)
try:
    import findspark
    findspark.init()
except Exception:
    pass

# el motor principal que nos permite crear y manejar los DataFrames
from pyspark.sql import SparkSession

#---------------------------------------------------- incicio del Script  ----------------------------------------------------

# levantamos la sesion de spark
spark = SparkSession.builder.appName("Lab05_DataFrame").getOrCreate()

# armamos la ruta para dejar el csv aca en nuestra misma carpeta
ruta_local = os.path.join(os.getcwd(), "dataset_videojuegos.csv")

# si el csv ya esta en la carpeta no hace falta bajarlo de nuevo
if not os.path.exists(ruta_local):
    # la libreria que instalamos para descargar el dataset directo desde internet
    import kagglehub
    # descargamos el dataset directo de kaggle
    print("bajando el dataset...")
    ruta_dataset = kagglehub.dataset_download("onlypythondatasheet/100000-video-game-dataset-with-records")
    # buscamos cual es el csv dentro de la carpeta oculta
    nombre_archivo_csv = [a for a in os.listdir(ruta_dataset) if a.endswith('.csv')][0]
    # lo copiamos para tenerlo a mano y no depender del cache
    shutil.copy2(os.path.join(ruta_dataset, nombre_archivo_csv), ruta_local)
    print("listo, archivo copiado a nuestra carpeta.")
else:
    print("el archivo ya estaba en la carpeta.")

# cargamos el df
df = spark.read.csv(ruta_local, header=True, inferSchema=True, quote='"', escape='"', multiLine=True)

# el csv trae comas de mas en el encabezado y por eso aparecen columnas vacias (_c19 en adelante)
# las sacamos con drop() y nos quedamos solo con las 19 columnas que si tienen datos
columnas_vacias = [c for c in df.columns if c.startswith("_c")]
df = df.drop(*columnas_vacias)


# --- funciones que vimos en clase ---
print("\n--- metodos de clase ---")

# un ojito a los primeros 5 datos
df.show(5)

# cuantos registros son
print("total de juegos:", df.count())

# vemos que columnas trae
print("columnas:", df.columns)

# revisamos los tipos de datos
df.printSchema()


# --- las 2 funciones nuevas que me tocaban ---
print("\n--- mis 2 funciones nuevas ---")

# 1. describe() pa sacar estadisticas al toque (promedio, min, max) de los ratings
print("1. estadisticas rapidas del rating:")
df.select("rating").describe().show()

# 2. dropDuplicates() pa limpiar la data y sacar juegos repetidos
print("2. limpiando repetidos:")
df_limpio = df.dropDuplicates()
print("juegos que quedaron despues de limpiar:", df_limpio.count())


# --- las otras 2 funciones nuevas (parte 4) ---
print("\n--- mis funciones nuevas (parte 4) ---")

from pyspark.sql import functions as F

# el csv trae todo como texto (y hay filas medio sucias), asi que pasamos a numero
# lo que vamos a usar. try_cast deja NULL si no es numero, asi no se cae
df_num = (df_limpio
          .withColumn("rating", F.expr("try_cast(rating as double)"))
          .withColumn("ratings_count", F.expr("try_cast(ratings_count as int)"))
          .withColumn("metacritic", F.expr("try_cast(metacritic as int)")))

# 3. withColumn() pa agregar una columna nueva: la categoria del juego segun su rating
print("3. withColumn(): categoria segun el rating")
df_cat = df_num.withColumn(
    "categoria",
    F.when(F.col("rating").isNull(), "Sin calificar")
     .when(F.col("rating") >= 4, "Excelente")
     .when(F.col("rating") >= 3, "Bueno")
     .when(F.col("rating") > 0, "Regular")
     .otherwise("Sin calificar"))
df_cat.select("name", "rating", "categoria").show(5, truncate=False)

# 4. groupBy().agg() pa resumir por grupo (cuantos juegos, rating promedio y votos totales)
#    y orderBy() pa dejar primero la categoria con mas juegos
print("4. groupBy().agg(): resumen por categoria")
(df_cat.groupBy("categoria")
       .agg(F.count("*").alias("total_juegos"),
            F.round(F.avg("rating"), 2).alias("rating_promedio"),
            F.sum("ratings_count").alias("votos_totales"))
       .orderBy(F.desc("total_juegos"))
       .show())


# --- dos funciones extra ---
print("\n--- funciones extra ---")

# 5. filter() pa quedarnos solo con los juegos mejor valorados (rating alto y con harta gente votando)
#    y orderBy() pa ordenarlos por cantidad de votos
print("5. filter(): juegos con rating >= 4 y al menos 500 votos")
df_top = df_cat.filter((F.col("rating") >= 4) & (F.col("ratings_count") >= 500))
print("juegos que cumplen:", df_top.count())
(df_top.select("name", "rating", "ratings_count", "metacritic")
       .orderBy(F.desc("ratings_count"))
       .show(10, truncate=False))

# 6. split() + explode() pa separar los generos de cada juego ("Action||Indie" queda en 2 filas)
#    y despues contar cuantos juegos hay por genero. el promedio lo sacamos solo con los
#    juegos calificados, porque casi todos tienen rating 0 y bajarian el promedio
print("6. explode(): cantidad de juegos por genero")
df_generos = (df_cat.filter(F.col("genres").isNotNull())
                    .withColumn("genero", F.explode(F.split(F.col("genres"), r"\|\|"))))
(df_generos.groupBy("genero")
           .agg(F.count("*").alias("total_juegos"),
                F.round(F.avg(F.when(F.col("rating") > 0, F.col("rating"))), 2).alias("rating_promedio_calificados"))
           .orderBy(F.desc("total_juegos"))
           .show(10, truncate=False))

# cerramos la sesion
spark.stop()
