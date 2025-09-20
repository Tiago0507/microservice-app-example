# Dockerfile for the Node.js Todos API Service
#
# This file defines the steps to create a Docker image for the todos-api.
# It is optimized for production use by installing only necessary dependencies
# and leveraging Docker's layer caching for faster builds.

# Specifies the base image for the build. 'node:8.17.0-slim' is a lightweight
# version of the Node.js image, which helps to keep the final image size small.
FROM node:8.17.0-slim

# Sets the working directory inside the container to '/app'. All subsequent
# commands will be executed from this directory.
WORKDIR /app

# Copies the 'package.json' and 'package-lock.json' files into the container.
# This is done as a separate step to take advantage of Docker's layer caching.
# The dependencies layer will only be rebuilt if these files change.
COPY package*.json ./

# Installs the project dependencies. The '--only=production' flag ensures that
# development dependencies (like nodemon) are not installed, which is a best
# practice for creating lean and secure production images.
RUN npm install --only=production

# Copies the rest of the application's source code into the container's
# working directory.
COPY . .

# Informs Docker that the container listens on port 8082 at runtime.
# This serves as documentation for the user and for Docker.
EXPOSE 8082

# Defines the command to run when the container starts. It executes the
# application directly with 'node', which is the standard and most stable
# way to run a Node.js application in production.
CMD [ "node", "server.js" ]