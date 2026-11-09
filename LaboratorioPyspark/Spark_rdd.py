# librerias basicas: os y sys pa configurar python, csv pa leer el archivo
import os
import sys
import csv

# le decimos a spark que use el mismo python que estamos usando nosotros
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

from pyspark import SparkContext

# levantamos spark en local con 2 hilos
sc = SparkContext("local[2]", "TallerRDDVideojuegos")

try:
    # leemos el csv y nos quedamos solo con nombre y generos de cada juego
    datos = []

    with open("dataset_videojuegos.csv", encoding="utf-8-sig", newline="") as archivo:
        lector = csv.DictReader(archivo)

        for fila in lector:
            nombre = fila["name"]
            generos = fila["genres"]

            if nombre and generos:
                datos.append((nombre, generos))

    print("Cantidad de videojuegos cargados:", len(datos))

    # partimos los juegos en dos grupos: A (posiciones pares) y B (impares)
    datos_a = datos[::2]
    datos_b = datos[1::2]

    # creamos los RDD con 8 particiones cada uno
    rdd_a = sc.parallelize(datos_a, 8)
    rdd_b = sc.parallelize(datos_b, 8)

    print("Cantidad de videojuegos grupo A:", rdd_a.count())
    print("Cantidad de videojuegos grupo B:", rdd_b.count())

    print("\nPrimeros 5 videojuegos:")
    print(rdd_a.take(5))

    # transformacion 1: flatMap, separa los generos de cada juego ("Action||Indie" queda en 2)
    generos_a = rdd_a.flatMap(
        lambda videojuego: videojuego[1].split("||")
    )

    generos_b = rdd_b.flatMap(
        lambda videojuego: videojuego[1].split("||")
    )

    print("\nTRANSFORMACION 1 - flatMap")
    print("Primeros 10 generos del grupo A:", generos_a.take(10))

    # transformacion 2: union, junta los generos de los dos grupos
    generos_unidos = generos_a.union(generos_b)

    print("\nTRANSFORMACION 2 - union")
    print("Primeros 10 generos unidos:", generos_unidos.take(10))

    # transformacion 3: intersection, los generos que estan en A y tambien en B
    generos_comunes = generos_a.intersection(generos_b)

    print("\nTRANSFORMACION 3 - intersection")
    print("Generos presentes en ambos grupos:")
    print(generos_comunes.take(20))

    # transformacion 4: subtract, los generos que estan en A pero no en B
    generos_exclusivos = generos_a.subtract(generos_b)

    print("\nTRANSFORMACION 4 - subtract")
    print("Generos exclusivos del grupo A:")
    print(generos_exclusivos.take(20))

    # accion 1: collect, trae los generos distintos del grupo A (con distinct pa que sea chico)
    generos_distintos_a = generos_a.distinct().collect()

    print("\nACCION 1 - collect")
    print("Cantidad de generos distintos en el grupo A:", len(generos_distintos_a))
    print("Generos distintos:", sorted(generos_distintos_a))

    # accion 2: reduce, suma 1 por cada genero pa sacar el total de asignaciones
    total_generos = generos_unidos.map(lambda g: 1).reduce(lambda a, b: a + b)

    print("\nACCION 2 - reduce")
    print("Total de generos asignados (grupo A + grupo B):", total_generos)

    # accion 3: countByValue, cuenta cuantas veces sale cada genero
    conteo_generos = generos_unidos.countByValue()

    print("\nACCION 3 - countByValue")
    print("Cantidad de videojuegos por genero:")
    for genero, cantidad in sorted(conteo_generos.items(), key=lambda x: -x[1]):
        print(f"  {genero}: {cantidad}")

    # accion 4: takeOrdered, los 5 generos mas frecuentes
    top_5 = (
        generos_unidos
        .map(lambda g: (g, 1))
        .reduceByKey(lambda a, b: a + b)
        .takeOrdered(5, key=lambda x: -x[1])
    )

    print("\nACCION 4 - takeOrdered")
    print("Top 5 generos mas frecuentes:")
    for posicion, (genero, cantidad) in enumerate(top_5, start=1):
        print(f"  {posicion}. {genero}: {cantidad}")

finally:
    # cerramos spark
    sc.stop()
