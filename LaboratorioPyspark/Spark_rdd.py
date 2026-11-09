# librerias basicas: os y sys pa configurar python, csv pa leer el archivo
import os
import sys
import csv

# le decimos a spark que use el mismo python que estamos usando nosotros
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

from pyspark import SparkContext

# levantamos spark en local con 1 hilo (en windows, local[2] provoca cuelgues con shuffle)
sc = SparkContext("local[1]", "TallerRDDVideojuegos")
sc.setLogLevel("WARN")

try:
    # leemos el csv y nos quedamos solo con nombre y generos de cada juego
    datos = []

    script_dir = os.path.dirname(os.path.abspath(__file__))

    with open(os.path.join(script_dir, "dataset_videojuegos.csv"), encoding="utf-8-sig", newline="") as archivo:
        lector = csv.DictReader(archivo)

        for fila in lector:
            nombre = fila["name"]
            generos = fila["genres"]

            if nombre and generos:
                datos.append((nombre, generos))

    print("Cantidad de videojuegos cargados:", len(datos))

    # --- transformacion 0: particion de datos ---
    # dividimos el dataset en dos grupos: A (posiciones pares) y B (posiciones impares)
    datos_a = datos[::2]
    datos_b = datos[1::2]

    # creamos los RDD con 4 particiones cada uno
    rdd_a = sc.parallelize(datos_a, 4)
    rdd_b = sc.parallelize(datos_b, 4)

    print("Cantidad de videojuegos grupo A:", rdd_a.count())
    print("Cantidad de videojuegos grupo B:", rdd_b.count())

    print("\nPrimeros 5 videojuegos:")
    print(rdd_a.take(5))

    # transformacion 1: flatMap, separa los generos de cada juego ("Action||Indie" queda en 2)
    # limpiamos espacios y descartamos generos vacios o muy largos (evitan cuelgues del pipe en windows)
    generos_a = rdd_a.flatMap(
        lambda videojuego: [g.strip() for g in videojuego[1].split("||") if g.strip() and len(g.strip()) < 50]
    )

    generos_b = rdd_b.flatMap(
        lambda videojuego: [g.strip() for g in videojuego[1].split("||") if g.strip() and len(g.strip()) < 50]
    )

    print("\nTRANSFORMACION 1 - flatMap")
    print("Total de generos en el grupo A:", generos_a.count())
    print("Muestra de generos del grupo A:", generos_a.distinct().take(10))

    # transformacion 2: union, junta los generos de los dos grupos en un solo conjunto
    generos_unidos = generos_a.union(generos_b)

    print("\nTRANSFORMACION 2 - union")
    print("Total de generos unidos:", generos_unidos.count())
    print("Muestra de generos unidos:", generos_unidos.distinct().take(10))

    # transformacion 3: intersection, identifica los generos compartidos entre A y B
    generos_comunes = generos_a.intersection(generos_b)

    print("\nTRANSFORMACION 3 - intersection")
    print("Cantidad de generos compartidos:", generos_comunes.count())
    print("Generos compartidos:", sorted(generos_comunes.distinct().collect()))

    # transformacion 4: subtract, aísla los generos exclusivos del grupo A
    generos_exclusivos = generos_a.subtract(generos_b)

    print("\nTRANSFORMACION 4 - subtract")
    print("Cantidad de generos exclusivos de A:", generos_exclusivos.count())
    print("Generos exclusivos de A:", sorted(generos_exclusivos.distinct().collect()))

    # accion 1: collect, extrae a memoria la coleccion completa de generos distintos ya procesados
    generos_distintos = generos_unidos.distinct().collect()

    print("\nACCION 1 - collect")
    print("Cantidad de generos distintos:", len(generos_distintos))
    print("Generos distintos:", sorted(generos_distintos))

    # accion 2: reduce, sumatoria total de los elementos iterando y combinando los valores
    total_generos = generos_unidos.map(lambda g: 1).reduce(lambda a, b: a + b)

    print("\nACCION 2 - reduce")
    print("Total de generos asignados (grupo A + grupo B):", total_generos)

    # accion 3: countByValue, conteo de la frecuencia exacta en que aparece cada genero
    conteo_generos = generos_unidos.countByValue()

    print("\nACCION 3 - countByValue")
    print("Cantidad de videojuegos por genero:")
    for genero, cantidad in sorted(conteo_generos.items(), key=lambda x: -x[1]):
        print(f"  {genero}: {cantidad}")

    # accion 4: takeOrdered, extraccion de los 5 generos principales ordenados de forma descendente por frecuencia
    # (usamos countByValue para obtener los conteos y luego takeOrdered sobre un RDD pequeno,
    #  porque reduceByKey + takeOrdered sobre el RDD grande cuelga el pipe en windows)
    rdd_conteos = sc.parallelize(list(conteo_generos.items()))
    top_5 = rdd_conteos.takeOrdered(5, key=lambda x: -x[1])

    print("\nACCION 4 - takeOrdered")
    print("Top 5 generos mas frecuentes:")
    for posicion, (genero, cantidad) in enumerate(top_5, start=1):
        print(f"  {posicion}. {genero}: {cantidad}")

finally:
    # cerramos spark
    sc.stop()