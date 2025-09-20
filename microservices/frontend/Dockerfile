# Dockerfile for the Vue.js Frontend Service
#
# This file uses a multi-stage build to create a lean production image.
# The first stage uses a Node.js environment to build the static assets,
# and the second stage uses a lightweight Nginx server to serve those assets.

# --- Stage 1: Build Environment ---
# Defines the 'build-stage' using a specific Node.js version. This stage contains
# all the tools required to compile the Vue.js application (Node, npm).
FROM node:8.17.0 as build-stage

# Sets the working directory within the build container.
WORKDIR /app

# Copies the package definition files. This is done first to leverage Docker's
# layer caching. The dependencies will only be re-installed if these files change.
COPY package*.json ./

# Installs all project dependencies defined in package.json.
RUN npm install

# Copies the entire source code of the frontend application into the container.
COPY . .

# Declares build-time arguments. These can be passed during the image build
# (e.g., via docker-compose) to inject environment-specific variables into the application.
ARG AUTH_API_ADDRESS
ARG TODOS_API_ADDRESS

# Sets environment variables within the build container from the build arguments.
# Vue CLI uses variables prefixed with VUE_APP_ to make them available in the client-side code.
ENV VUE_APP_AUTH_API_ADDRESS=$AUTH_API_ADDRESS
ENV VUE_APP_TODOS_API_ADDRESS=$TODOS_API_ADDRESS

# Executes the production build script defined in package.json. This command
# transpiles and bundles the Vue application into a set of static HTML, CSS, and JS files
# in the '/app/dist' directory.
RUN npm run build

# --- Stage 2: Runtime Environment ---
# Defines the final production stage, using a lightweight and secure Nginx image.
# This stage does not contain Node.js or the original source code.
FROM nginx:stable-alpine

# Copies only the compiled static assets from the 'build-stage' into the
# default directory that Nginx serves files from. This is the key to creating a small
# and secure production image.
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Replaces the default Nginx configuration with the custom project-specific configuration.
# This file contains the reverse proxy and SPA fallback rules.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Documents that the container will listen on port 80.
EXPOSE 80

# The command to start the Nginx server. The '-g "daemon off;"' directive ensures
# Nginx runs in the foreground, which is standard practice for containers.
CMD ["nginx", "-g", "daemon off;"]