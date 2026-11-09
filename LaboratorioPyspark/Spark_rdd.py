# librerias basicas: os y sys pa configurar python, csv pa leer el archivo
import os
import sys
import csv

# le decimos a spark que use el mismo python que estamos usando nosotros
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

from pyspark import SparkContext

# levantamos spark en local con 2 hilos (setup validado en nuestro laboratorio de imdb)
sc = SparkContext("local[2]", "TallerRDDVideojuegos")
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

    # partimos los juegos en dos grupos: A (posiciones pares) y B (impares)
    datos_a = datos[::2]
    datos_b = datos[1::2]

    # creamos los RDD con 8 particiones cada uno (setup validado en nuestro laboratorio de imdb)
    rdd_a = sc.parallelize(datos_a, 8)
    rdd_b = sc.parallelize(datos_b, 8)

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

    # transformacion 2: union, junta los generos de los dos grupos
    generos_unidos = generos_a.union(generos_b)

    print("\nTRANSFORMACION 2 - union")
    print("Total de generos unidos:", generos_unidos.count())

    # transformacion 3: map, pasa cada genero a mayusculas (transformacion elemento a elemento)
    generos_mayuscula = generos_unidos.map(lambda g: g.upper())

    print("\nTRANSFORMACION 3 - map")
    print("Total de generos en mayuscula:", generos_mayuscula.count())

    # transformacion 4: filter, deja solo los generos que empiezan con A
    generos_con_a = generos_mayuscula.filter(lambda g: g.startswith("A"))

    print("\nTRANSFORMACION 4 - filter")
    print("Cantidad de generos que empiezan con A:", generos_con_a.count())

    # accion 1: take, trae los primeros generos distintos del grupo A
    generos_distintos_a = generos_a.distinct().take(100)

    print("\nACCION 1 - take (muestra de generos distintos)")
    print("Cantidad de generos distintos en el grupo A:", len(generos_distintos_a))
    print("Generos distintos:", sorted(generos_distintos_a))

    # accion 2: count, suma 1 por cada genero pa sacar el total de asignaciones
    # (en Windows, reduce() sobre RDDs grandes cuelga el pipe, usamos count() que es estable)
    total_generos = generos_unidos.map(lambda g: 1).count()

    print("\nACCION 2 - count (total de asignaciones)")
    print("Total de generos asignados (grupo A + grupo B):", total_generos)

    # accion 3: countByValue, cuenta cuantas veces sale cada genero
    conteo_generos = generos_unidos.countByValue()

    print("\nACCION 3 - countByValue")
    print("Cantidad de videojuegos por genero:")
    for genero, cantidad in sorted(conteo_generos.items(), key=lambda x: -x[1]):
        print(f"  {genero}: {cantidad}")

    # top 5 por frecuencia, calculado en Python a partir de countByValue
    # (evitamos reduceByKey + takeOrdered, que cuelgan el pipe en Windows)
    top_5 = sorted(conteo_generos.items(), key=lambda x: -x[1])[:5]

    print("\nTop 5 generos mas frecuentes (calculado en Python):")
    for posicion, (genero, cantidad) in enumerate(top_5, start=1):
        print(f"  {posicion}. {genero}: {cantidad}")

    # accion 4: takeOrdered, los 10 generos distintos ordenados alfabeticamente
    top_10_ordenados = generos_a.distinct().takeOrdered(10)

    print("\nACCION 4 - takeOrdered")
    print("10 generos distintos ordenados:")
    for posicion, genero in enumerate(top_10_ordenados, start=1):
        print(f"  {posicion}. {genero}")

finally:
    # cerramos spark
    sc.stop()