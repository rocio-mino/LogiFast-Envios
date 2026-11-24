
# syntax=docker/dockerfile:1

# Etapa 1: construcción
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /app

COPY pom.xml ./
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests

# Etapa 2: ejecución
FROM eclipse-temurin:25-jre

WORKDIR /app

# Ejecutar la aplicación con un usuario sin privilegios.
# UID/GID numéricos fijos (10001): Kubernetes solo puede verificar runAsNonRoot
# (Pod Security Standard "restricted") cuando el USER de la imagen es numérico.
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app app

# El JAR queda como propiedad de root (solo lectura para el usuario de ejecución):
# el proceso no puede modificar su propio código.
COPY --from=build /app/target/*.jar /app/app.jar

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
