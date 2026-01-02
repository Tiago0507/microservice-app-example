# Dockerfile for the Java Users API Service (users-api)
#
# This file employs a multi-stage build process to compile the Java application
# and create a minimal, optimized production image.

# Stage 1: Build Environment
# Defines the 'build' stage using a Maven image that includes a full JDK.
# This stage contains all necessary tools to compile and package the application.
FROM maven:3.8-eclipse-temurin-8 AS build

# Sets the working directory inside the build container.
WORKDIR /app

# Copies the Maven project file first. This leverages Docker's layer caching,
# ensuring that dependencies are only re-downloaded if the pom.xml file changes.
COPY pom.xml .

# Executes the 'go-offline' goal to download all project dependencies. This
# populates the local Maven repository within the layer, speeding up subsequent builds.
RUN mvn dependency:go-offline -B

# Copies the application's source code into the container.
COPY src ./src

# Compiles the source code and packages it into an executable JAR file.
# The '-DskipTests' flag is used to speed up the build process by skipping tests.
RUN mvn package -DskipTests

# Stage 2: Runtime Environment
# Defines the final production stage using a slim Eclipse Temurin (OpenJDK) image. This image
# contains only the Java Runtime Environment (JRE), making it smaller and more secure.
FROM eclipse-temurin:8-jre

# Updates the package list and installs 'netcat-openbsd'. This lightweight utility
# is used by the healthcheck command in docker-compose.yml to verify that the
# application's port is open and listening.
# The 'rm -rf /var/lib/apt/lists/*' command cleans up the package cache to keep the image small.
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Copies the executable JAR file from the 'build' stage into the final image.
# This ensures that only the compiled application is included in the production image,
# without any source code or build tools.
COPY --from=build /app/target/users-api-0.0.1-SNAPSHOT.jar /usr/local/lib/users-api.jar

# Documents that the container exposes port 8083 at runtime.
EXPOSE 8083

# Sets the command to execute when the container starts. It runs the Java application
# from the packaged JAR file.
ENTRYPOINT ["java", "-jar", "/usr/local/lib/users-api.jar"]