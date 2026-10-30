# ==============================================================================
# Dockerfile Multi-stage pour Karavan Backend (Spring Boot 3.5 / Java 21)
# Optimisé pour Render.com
# ==============================================================================

# Étape 1 : Compilation et packaging
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder
WORKDIR /app

# Cache des dépendances Maven
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Compilation du code source (tests ignorés pour accélérer le build de production)
COPY src ./src
RUN mvn clean package -DskipTests -B

# Étape 2 : Image d'exécution minimale
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Création d'un utilisateur applicatif sécurisé
RUN addgroup -S karavan && adduser -S karavan -G karavan
USER karavan

# Copie de l'artefact généré
COPY --from=builder /app/target/*.jar app.jar

# Configuration du port dynamique pour Render ($PORT)
ENV PORT=8080
EXPOSE ${PORT}

# Lancement de l'application
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]

