
# syntax=docker/dockerfile:1

# Etapa 1: construcción
FROM maven:3.9-eclipse-temurin-26 AS build

WORKDIR /app

COPY pom.xml ./
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests

# Etapa 2: ejecución
FROM eclipse-temurin:21-jre

WORKDIR /app

# Ejecutar la aplicación con un usuario sin privilegios
RUN groupadd --system app \
    && useradd --system --gid app --home-dir /app app

COPY --from=build --chown=app:app /app/target/*.jar /app/app.jar

USER app

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
