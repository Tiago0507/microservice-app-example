# Dockerfile for the Go Authentication API (auth-api)
#
# This Dockerfile utilizes a multi-stage build pattern to create a minimal,
# secure, and optimized final image for the Go application.

# --- Stage 1: Build Environment ---
# Defines the first stage of the build, named 'builder'. It uses a lightweight
# Alpine-based Go image that contains all the necessary tools to compile the application.
FROM golang:1.22-alpine AS builder

# Installs git within the build container. Go modules require git to fetch
# dependencies from version control repositories. '--no-cache' reduces image size.
RUN apk add --no-cache git

# Sets the working directory inside the container. All subsequent commands
# will be executed from this path.
WORKDIR /app

# Copies the Go module files into the container. This step is done separately
# to leverage Docker's layer caching. If these files don't change, Docker
# will reuse the cached dependency layer, speeding up subsequent builds.
COPY go.mod go.sum ./

# Downloads the application's dependencies as specified in the module files.
RUN go mod download

# Copies the rest of the application's source code into the container.
COPY . .

# Ensures that go.mod and go.sum are in sync and include all necessary modules.
RUN go mod tidy

# Compiles the Go application into a single, statically-linked binary.
# - CGO_ENABLED=0 disables Cgo, creating a pure Go binary without C dependencies.
# - GOOS=linux specifies the target operating system.
# - '-a -installsuffix cgo' forces a rebuild of all packages, ensuring static linking.
# - '-o /auth-api' sets the output path and name of the compiled binary.
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /auth-api .

# --- Stage 2: Runtime Environment ---
# Defines the final stage, which creates the production image. It starts from
# 'scratch', an empty base image, for maximum security and minimal size.
FROM scratch

# Copies only the compiled binary from the 'builder' stage into the final image.
# This is the core of the multi-stage pattern: the final image contains only the
# executable, without any source code, build tools, or system libraries.
COPY --from=builder /auth-api /auth-api

# Informs Docker that the container listens on the specified network port at runtime.
# This is for documentation and does not actually publish the port.
EXPOSE 8000

# Specifies the command to run when the container starts. It executes the
# compiled application binary.
ENTRYPOINT ["/auth-api"]