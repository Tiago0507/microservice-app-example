# Ansible Configuration Management

This directory contains the Ansible playbooks and roles responsible for the configuration management and application deployment onto the virtual machine provisioned by Terraform. Ansible automates the process of software installation, configuration, and service management in an idempotent and declarative way.

## Guiding Principles

The Ansible setup is designed with the following principles in mind:

* **Idempotence**: Playbooks are written to be safely executed multiple times. Running a playbook will only apply changes if the system is not already in the desired state, ensuring consistency and predictability.
* **Separation of Concerns**: The responsibilities are split into two main playbooks:
    * **`provision.yml`**: Handles the one-time initial setup and bootstrapping of the server (e.g., installing Docker).
    * **`playbook.yml`**: Manages the deployment and lifecycle of the application's microservices.
* **Reusability**: The deployment logic is encapsulated within an Ansible Role (`deploy`), allowing the same set of tasks to be used for deploying any of the microservices by simply passing different parameters.
* **Automation-Centric**: The playbooks are designed to be executed automatically as part of the CI/CD pipelines, using command-line variables (`--extra-vars`) to pass dynamic information like the service name to deploy.

---

## Architecture and Workflow

The overall process is divided into two distinct phases: Provisioning and Deployment.

1.  **Provisioning (Initial Setup)**: After Terraform creates the virtual machine, the `provision.yml` playbook is executed. It connects to the new VM and installs all the necessary runtime dependencies for the application, primarily Docker and Docker Compose. This phase prepares the server to host the containerized application.

2.  **Deployment (Application Update)**: When a change is pushed to a microservice's source code, the CI/CD pipeline triggers the `playbook.yml`. This playbook executes the `deploy` role, which performs the following steps on the VM:
    * Pulls the latest changes from the Git repository.
    * Uses Docker Compose to pull the newly built container image for the specific service being updated.
    * Stops the existing container for that service.
    * Starts the new container with the updated image.
    * Cleans up old, unused Docker images to conserve disk space.

---

## File Structure Breakdown

* `ansible.cfg`: This is the main configuration file for Ansible. It defines default behaviors, such as the inventory file to use (`inventory.yml`), disabling strict host key checking for convenience in automated environments, and setting the default remote user (`adminuser`).

* `inventory.yml`: A basic inventory file. In this project, the target host's IP address is not hardcoded here but is passed dynamically from the Terraform output directly to the `ansible-playbook` command in the CI/CD pipeline.

* `provision.yml`: This playbook is responsible for bootstrapping the target server. Its tasks include:
    * Updating the `apt` package cache.
    * Installing prerequisite packages (`git`, `curl`, `python3-pip`).
    * Adding Docker's official GPG key and APT repository.
    * Installing Docker Engine (`docker-ce`) and the Docker Compose plugin.
    * Installing the Docker SDK for Python via `pip`.
    * Ensuring the Docker service is started and enabled on boot.
    * Adding the remote user to the `docker` group to allow running Docker commands without `sudo`.

* `playbook.yml`: The main playbook for application deployments. It is very concise, as its only job is to invoke the `deploy` role, which contains all the deployment logic.

### Role: `deploy`

This role contains the reusable logic for deploying a single microservice.

* `roles/deploy/tasks/main.yml`: This file defines the sequence of tasks executed during a deployment:
    1.  **Verify Dependencies**: Checks that Docker and Docker Compose are available on the target host.
    2.  **Update Repository**: Pulls the latest version of the `main` branch from the GitHub repository.
    3.  **Create `.env` file**: Uses a template to create an `.env` file in the project root, which injects the `DOCKERHUB_USERNAME` variable. This allows `docker-compose.prod.yml` to pull the correct images.
    4.  **Stop Service**: Gracefully stops and removes the container for the specific service being deployed (`docker compose down <service_name>`).
    5.  **Pull & Restart Service**: Pulls the latest Docker image for the service and then starts it in detached mode (`docker compose pull <service_name> && docker compose up -d`).
    6.  **Verify State**: Checks the status of the container to confirm it is running.
    7.  **Prune Images**: Removes old, dangling Docker images to free up space.

* `roles/deploy/templates/.env.j2`: A Jinja2 template for the `.env` file. It contains a single line that sets the `DOCKERHUB_USERNAME` variable, which is passed in during the pipeline's execution.

---

## Execution

While these playbooks are executed automatically by GitHub Actions, they can also be run manually.

### Manual Provisioning

To provision a new server:

```bash
ansible-playbook provision.yml \
  -i "YOUR_VM_IP," \
  --extra-vars "ansible_user=YOUR_USERNAME ansible_ssh_pass=YOUR_PASSWORD"
```

### Manual Deployment

To deploy or update a specific microservice:

```bash
ansible-playbook playbook.yml \
  -i "YOUR_VM_IP," \
  --extra-vars "service_name=auth-api" \
  --extra-vars "github_repository=your-github-user/your-repo" \
  --extra-vars "dockerhub_username=your-docker-hub-user" \
  --extra-vars "ansible_user=YOUR_USERNAME ansible_ssh_pass=YOUR_PASSWORD"
```