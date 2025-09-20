# Dockerfile for the Python Log Message Processor Service
#
# This file uses a multi-stage build to create a lightweight and efficient
# production image. The first stage compiles dependencies, and the second
# stage uses a slim runtime to execute the application.

# --- Stage 1: Build Environment ---
# Defines the 'builder' stage using the full Python 3.6 image, which includes
# the necessary build tools for compiling C extensions.
FROM python:3.6 as builder

# Sets the working directory inside the build container.
WORKDIR /app

# Installs the 'build-essential' package, which contains compilers (like gcc)
# required to build Python dependencies that use C extensions, such as 'cython'.
RUN apt-get update && apt-get install -y build-essential

# Copies the requirements file to leverage Docker's layer caching. This layer
# is only rebuilt if the dependencies file changes.
COPY requirements.txt .

# Installs the Python dependencies. '--no-cache-dir' is used to reduce the
# image size by not storing the pip cache.
RUN pip install --no-cache-dir -r requirements.txt

# --- Stage 2: Runtime Environment ---
# Defines the final production stage using a 'slim' Python image, which is
# significantly smaller than the full image.
FROM python:3.6-slim

# Sets the working directory for the runtime container.
WORKDIR /app

# Copies the pre-installed Python packages from the 'builder' stage into the
# final image. This ensures all dependencies are available without needing
# build tools in the production environment.
COPY --from=builder /usr/local/lib/python3.6/site-packages /usr/local/lib/python3.6/site-packages

# Copies the application script into the final image.
COPY main.py .

# Specifies the default command to execute when the container starts.
# It runs the Python script to begin processing log messages.
CMD [ "python3", "main.py" ]