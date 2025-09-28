# Microservices Architecture

This directory is the core of the project, containing the source code for all the individual microservices that constitute the application's business logic and user interface. Each service is developed and maintained in its own dedicated subdirectory, promoting a decoupled and scalable architecture.

## Guiding Principles

The microservices are designed based on several core tenets of modern application development:

* **Single Responsibility**: Each service has a narrow, well-defined purpose (e.g., authentication, user management, todos management).
* **Technological Diversity**: The architecture embraces polyglot persistence and programming, using the best technology for each specific job. This project includes services written in **Go, Java (Spring Boot), Node.js, Python, and Vue.js**.
* **Containerization**: Every microservice is packaged as a lightweight, portable Docker container. This is defined in its own `Dockerfile`, ensuring a consistent runtime environment from development to production.
* **Centralized Orchestration**: The `docker-compose.yml` and `docker-compose.prod.yml` files in the root directory define how these individual services are networked and run together as a cohesive application.

---

## Service Breakdown

Here is a summary of each microservice within the application stack.

### `frontend`

* **Purpose**: A rich Single-Page Application (SPA) that provides the complete user interface for the application. It communicates with the backend APIs to fetch and manipulate data.
* **Technology**: **Vue.js**
* **Dockerfile Strategy**: It uses a multi-stage build. The first stage uses a Node.js image to build and bundle the static web assets (`npm run build`). The final stage uses a lightweight Nginx image to serve these static files and act as a reverse proxy/API Gateway for the backend services.

### `auth-api`

* **Purpose**: Handles user authentication. It validates user credentials against the `users-api` and, upon success, generates a JSON Web Token (JWT) for use in subsequent API requests.
* **Technology**: **Go**
* **Dockerfile Strategy**: Employs a multi-stage build. The first stage compiles the Go source code into a single, statically linked binary. The final stage uses the minimal `scratch` base image and copies only the compiled binary, resulting in an extremely small and secure production image.

### `users-api`

* **Purpose**: Provides CRUD (Create, Read, Update, Delete) operations for user data. It acts as the source of truth for user information.
* **Technology**: **Java (Spring Boot)**
* **Dockerfile Strategy**: Uses a multi-stage build. A `maven` image is used to compile the application and package it into a `.jar` file. The final image is a slim JRE (Java Runtime Environment) that only contains the compiled application, optimizing for size and security.

### `todos-api`

* **Purpose**: Manages the to-do lists for users. It provides endpoints for creating, retrieving, and deleting to-do items. It also publishes log messages to a Redis queue upon creation or deletion.
* **Technology**: **Node.js (Express)**
* **Dockerfile Strategy**: Uses a lightweight `node:18-alpine` base image. It installs only production dependencies to keep the final image size minimal.

### `log-message-processor`

* **Purpose**: A background worker service that listens to the Redis queue for messages published by the `todos-api`. It processes these messages by printing them to the standard output.
* **Technology**: **Python**
* **Dockerfile Strategy**: Leverages a multi-stage build. A full `python` image with build tools is used to install dependencies. The final image is a `python-slim` version that only contains the necessary runtime and the pre-installed packages, reducing the final footprint.

---

## Cloud Design Patterns Implementation

This project implements two key cloud-native design patterns to enhance performance and resilience: Cache-Aside and Circuit Breaker.

### Cache-Aside Pattern

This pattern is implemented in the **`users-api`** service to improve performance and reduce database load when fetching user data. It uses Redis as a fast, in-memory cache.

#### **Conceptual Flow**

1.  A request to fetch a user arrives at the `users-api`.
2.  The application first checks if the user's data exists in the Redis cache.
3.  **Cache Hit**: If the data is in Redis, it is returned immediately to the client without querying the database. This is extremely fast.
4.  **Cache Miss**: If the data is not in Redis, the application queries the primary database (H2 in this case).
5.  The retrieved data is then stored in the Redis cache for a specific duration (Time-To-Live or TTL) before being returned to the client. Subsequent requests for the same user will result in a cache hit.
6.  **Cache Invalidation**: When a user's data is modified or deleted, the corresponding entry in the Redis cache is explicitly removed (invalidated) to ensure data consistency.

#### **Implementation and Evidence**

The implementation can be seen in the `UsersController.java` file. The `getUser` method manually checks the cache, and the `deleteUser` method uses the `@CacheEvict` annotation to automatically remove data from the cache.

The following logs from the `users-api` demonstrate this pattern in action:

![microservice-app-example](/images/cache-aside.jpeg)

* **Log 1 (Cache Miss)**: The first request for user 'johnd' is not in the cache, so the application queries the database.
* **Logs 2 & 3 (Cache Hit)**: Subsequent requests for 'johnd' are found in Redis and returned instantly.
* **Log 4 (Invalidating Cache)**: A delete operation is performed on 'johnd', which removes the user from the database and simultaneously evicts the entry from the Redis cache.
* **Log 5 (Cache Miss)**: The next request for 'johnd' results in a cache miss again, as the entry was invalidated.

### Circuit Breaker Pattern

This resilience pattern is implemented in the **`auth-api`** to handle failures when it communicates with its downstream dependency, the **`users-api`**. This prevents cascading failures and allows the system to remain responsive even when parts of it are degraded.

#### **Conceptual Flow**

The `auth-api` wraps its network calls to the `users-api` in a circuit breaker.

1.  **Closed State**: Initially, the circuit is closed. Requests from `auth-api` flow normally to `users-api`. The breaker monitors for failures.
2.  **Open State**: If the number of consecutive failures exceeds a configured threshold (e.g., `users-api` is offline and not responding), the circuit "opens". In this state, all subsequent calls from `auth-api` to `users-api` fail immediately without even attempting a network connection. This is called "failing fast". The `auth-api` returns a `503 Service Unavailable` error, protecting itself from being consumed by failing requests.
3.  **Half-Open State**: After a cooldown period, the circuit moves to a "half-open" state. It allows a single "trial" request to pass through to the `users-api`. If this request succeeds, the circuit closes and normal operation resumes. If it fails, the circuit opens again, and the cooldown timer restarts.

#### **Implementation and Evidence**

This is implemented in `auth-api/main.go` using the `gobreaker` library. The circuit is configured to open after more than 3 consecutive failures.

The following screenshots demonstrate the user-facing effect of this pattern.

1.  **Initial Failures (Circuit is Closed)**: In this first image, the `users-api` is down. The `auth-api` attempts to contact it, times out, and returns a generic error. The user sees a "something went wrong" message.

    ![microservice-app-example](/images/circuit-breaker1.jpeg)

2.  **Circuit Opens**: After several repeated login attempts, the consecutive failures cause the circuit breaker in the `auth-api` to open. Now, when the user tries to log in, the request fails instantly.

    ![microservice-app-example](/images/circuit-breaker2.jpeg)

    The error message in the UI now explicitly states: "Servicio no disponible, por favor intente más tarde. El circuito está abierto." ("Service unavailable, please try again later. The circuit is open."). This confirms that the Circuit Breaker pattern is active, failing fast and providing a clear status to the system and the user.

---

## How to Test the Patterns

Any developer can locally verify the functionality of these patterns by following the steps below.

### **Testing the Cache-Aside Pattern**

This test demonstrates the cache hit, cache miss, and cache invalidation flow using two terminals: one for executing commands and one for monitoring logs.

#### **Prerequisites**

* Ensure all application services are running on the target VM.
* You will need two terminal windows.

#### **Execution Steps**

1.  **Terminal 1 (Your Local Machine): Prepare for the Test**
    * Get the public IP of your VM and save it as a variable:
        ```bash
        VM_PUBLIC_IP=$(terraform output -raw vm_public_ip)
        echo "La IP pública de la VM es: $VM_PUBLIC_IP"
        ```
    * Obtain a JWT for the user 'johnd' to authorize subsequent requests:
        ```bash
        TOKEN_JOHND=$(curl -s -X POST http://$VM_PUBLIC_IP:8080/api/auth/login -d '{"username": "johnd","password": "foo"}' | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')
        ```

2.  **Terminal 2 (SSH into the VM): Monitor the Logs**
    * Connect to the Azure VM via SSH:
        ```bash
        ssh adminuser@<VM_PUBLIC_IP>
        ```
    * Start streaming the logs from the `users-api` container. This window will show you the real-time server reactions.
        ```bash
        sudo docker logs -f microservice-app-example-users-api-1
        ```

3.  **Terminal 1: Execute the Test Sequence**
    * **Step 1: Trigger a Cache Miss**
        Make the first request to get 'johnd's user data.
        ```bash
        curl -H "Authorization: Bearer $TOKEN_JOHND" http://$VM_PUBLIC_IP:8080/api/users/johnd
        ```
        Observe the `users-api` logs in Terminal 2. You will see a `CACHE MISS` message.

    * **Step 2: Trigger a Cache Hit**
        Immediately run the exact same command again.
        ```bash
        curl -H "Authorization: Bearer $TOKEN_JOHND" http://$VM_PUBLIC_IP:8080/api/users/johnd
        ```
        This time, the logs in Terminal 2 will show a `CACHE HIT` message.

    * **Step 3: Invalidate the Cache**
        Delete the user, which is configured to evict them from the cache.
        ```bash
        curl -X DELETE -H "Authorization: Bearer $TOKEN_JOHND" http://$VM_PUBLIC_IP:8080/api/users/johnd
        ```
        The logs will show an `INVALIDANDO CACHÉ` message.

    * **Step 4: Confirm Cache Invalidation**
        Request the user one last time.
        ```bash
        curl -H "Authorization: Bearer $TOKEN_JOHND" http://$VM_PUBLIC_IP:8080/api/users/johnd
        ```
        The logs will once again show a `CACHE MISS`, proving the cache entry was successfully removed.

### **Testing the Circuit Breaker Pattern**

This test provides a step-by-step script for demonstrating the three states of the circuit breaker: Closed, Open, and Half-Open.

#### **Phase 0: Preparation**

1.  **Verify VM IP**: Make sure you have the public IP of your Azure VM.
2.  **SSH into VM**: Open a terminal and connect to your virtual machine. You will use this to stop and start services.
    ```bash
    ssh adminuser@<YOUR_VM_PUBLIC_IP>
    ```
3.  **Open the Application**: In your web browser, navigate to `http://<YOUR_VM_PUBLIC_IP>:8080`.
4.  **Open Developer Tools**: Press F12 and go to the "Network" tab to monitor API requests.

#### **Phase 1: Demostration of CLOSED State (Healthy System)**

* **Action**: In the web app, log in with credentials `admin` / `admin`.
* **Observation**: The login succeeds, and you are redirected. In the Network tab, the `/login` request shows a `200 OK` status. This is the circuit in its normal, Closed state.

#### **Phase 2: Simulating a Failure & Opening the Circuit**

* **Action**:
    1.  Log out of the application.
    2.  In your SSH terminal, stop the `users-api` container:
        ```bash
        # Inside the VM
        sudo docker compose stop users-api
        ```
    3.  Back in the browser, attempt to log in with `admin` / `admin` four times in a row.
* **Observation**:
    * The first few attempts will fail with a `500 Internal Server Error` and will take a few seconds to respond. This is the circuit attempting to connect.
    * After the threshold of 3 failures is met, the circuit will Open.

#### **Phase 3: Demonstrating the OPEN and HALF-OPEN States**

* **Action**: Attempt to log in one more time.
* **Observation**:
    * The login attempt will fail **instantly**.
    * The Network tab will show a `503 Service Unavailable` status for the `/login` request. The response time will be in milliseconds. This confirms the circuit is Open and "failing fast".
* **Action**:
    1.  Wait for 10 seconds (the configured cooldown period).
    2.  Attempt to log in again. This is the "trial" request in the Half-Open state.
* **Observation**:
    * Since `users-api` is still down, this trial request will fail with a `500 Internal Server Error`.
    * The circuit immediately transitions back to the Open state. Any immediate subsequent login attempts will result in a fast `503` failure.

#### **Phase 4: System Recovery (Closing the Circuit)**

* **Action**:
    1.  In your SSH terminal, restart the `users-api` container:
        ```bash
        # Inside the VM
        sudo docker compose start users-api
        ```
    2.  Wait another 10 seconds for the breaker's cooldown period to elapse, allowing it to enter the Half-Open state again.
    3.  In the browser, attempt to log in one last time.
* **Observation**:
    * The login will now be successful.