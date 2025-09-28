# Ansible Configuration Management

This directory contains the Ansible playbooks and roles responsible for the configuration management and application deployment onto the virtual machine provisioned by Terraform. Ansible automates the process of software installation, configuration, and service management in an idempotent and declarative way.

## Guiding Principles

The Ansible setup is designed with the following principles in mind:

* **Idempotence**: Playbooks are written to be safely executed multiple times. Running a playbook will only apply changes if the system is not already in the desired state, ensuring consistency and predictability.
* **Separation of Concerns**: Responsibilities are split into distinct playbooks:
    * **`provision.yml`**: Handles the one-time initial setup and bootstrapping of the server (e.g., installing Docker).
    * **`playbook.yml`**: Manages the deployment of a *single* microservice.
    * **`deploy-all.yml`**: Manages the deployment of the *entire* application stack, intended for the initial setup after provisioning.
* **Reusability**: The deployment logic is encapsulated within an Ansible Role (`deploy`), allowing the same set of tasks to be used for deploying any of the microservices.
* **Automation-Centric**: The playbooks are designed to be executed automatically by the CI/CD pipelines, using command-line variables (`--extra-vars`) to pass dynamic information.

---

## Architecture and Workflow

The overall process is divided into two distinct phases: Provisioning and Deployment.

1.  **Provisioning (Initial Setup)**: After Terraform creates the virtual machine, the `provision.yml` playbook is executed. It connects to the new VM and installs all the necessary runtime dependencies for the application, primarily Docker and Docker Compose. This phase prepares the server to host the containerized application.

2.  **Deployment (Application Update)**:
    * **Initial Deployment**: After provisioning, the `deploy-all.yml` playbook is run to deploy the entire stack of microservices for the first time.
    * **Single Service Update**: When a change is pushed to a microservice's source code, its CI/CD pipeline triggers the `playbook.yml`. This playbook executes the `deploy` role to update only that specific service on the VM.

---

## File Structure Breakdown

* `ansible.cfg`: The main configuration file for Ansible. It defines default behaviors, such as the inventory file, disabling strict host key checking, and enabling SSH pipelining and connection retries for performance and reliability.

* `inventory.yml`: A basic inventory file. The target host's IP address is not hardcoded here but is passed dynamically from the Terraform output in the CI/CD pipeline.

* `provision.yml`: This playbook bootstraps the target server. Its tasks include installing Docker, Docker Compose, Git, and other essential tools.

* `playbook.yml`: The main playbook for deploying a *single* application service. Its only job is to invoke the `deploy` role.

* `deploy-all.yml`: A playbook used by the infrastructure pipeline to deploy all microservices at once after the initial provisioning is complete. It also uses the `deploy` role but without specifying a single `service_name`.

### Role: `deploy`

This role contains the reusable logic for deploying services.

* `roles/deploy/tasks/main.yml`: This file defines the sequence of deployment tasks:
    1.  **Verify Dependencies**: Checks that Docker and Docker Compose are available.
    2.  **Update Repository**: Pulls the latest version of the `main` branch.
    3.  **Create `.env` file**: Uses a template to create an `.env` file with the `DOCKERHUB_USERNAME`.
    4.  **Pull & Restart Service**: Pulls the latest Docker image(s) and restarts the service(s) using `docker compose up -d`. If a `service_name` is provided, it only pulls and restarts that specific service.
    5.  **Prune Images**: Removes old, dangling Docker images to free up space.

* `roles/deploy/templates/.env.j2`: A Jinja2 template for the `.env` file.

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