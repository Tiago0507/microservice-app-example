# CI/CD Automation with GitHub Actions

This directory contains all the GitHub Actions workflow definitions that automate the build, deployment, and management of both the infrastructure and the application services. The automation strategy follows modern GitOps and CI/CD principles to ensure a reliable, repeatable, and efficient delivery process.

## Guiding Philosophy

The CI/CD strategy is built upon a clear separation of concerns:

1.  **Infrastructure Pipeline (`cicd-infrastructure.yml`)**: This workflow is responsible for the entire lifecycle of the cloud infrastructure. It uses Terraform to provision resources and Ansible to perform initial server configuration and a full initial deployment. It is triggered by changes to infrastructure-related code.

2.  **Application Pipelines (`reusable-deploy.yml`)**: These workflows manage the lifecycle of the individual microservices. They are designed to be highly modular. A central, reusable workflow handles the logic of building a Docker image, pushing it to a registry, and deploying it. Each microservice then has a simple "trigger" workflow (e.g., `cicd-frontend.yml`) that calls the reusable one when its specific source code changes.

This separation ensures that infrastructure changes are handled safely and independently from application updates, which can happen much more frequently.

---

## End-to-End Workflow Visualization

The entire process is orchestrated to connect infrastructure provisioning with application deployment seamlessly.

1.  **Infrastructure Provisioning**: An operator pushes a change to the `iac/` directory.
    * The `cicd-infrastructure.yml` workflow is triggered.
    * A `terraform-deploy` job creates a new Azure VM and updates a GitHub variable (`SSH_HOST`) with the new IP.
    * A `provision-vm` job connects to this VM and installs Docker using Ansible.
    * A `build-all-services` job builds and pushes fresh Docker images for all microservices in parallel.
    * Finally, a `deploy-all-services` job runs the `deploy-all.yml` Ansible playbook to launch the entire application stack on the newly provisioned server.

2.  **Application Deployment**: A developer pushes a code change to the `auth-api` microservice.
    * The `cicd-auth-api.yml` workflow is triggered.
    * This workflow calls the `reusable-deploy.yml` workflow, passing `service_name: auth-api` as a parameter.
    * The `reusable-deploy.yml` workflow takes over:
        * A `build-and-push` job builds a new Docker image for `auth-api` and pushes it to Docker Hub.
        * A `deploy-to-vm` job connects to the VM (using the `SSH_HOST` variable) and runs the `playbook.yml` Ansible playbook, which pulls the new `auth-api` image and restarts only that container.

---

## Detailed Workflow Breakdown

### 1. `cicd-infrastructure.yml`

This is the master pipeline for managing the cloud environment. It follows a "recreate" strategy for simplicity and consistency.

* **Triggers**: On `push` to `main` with changes in `iac/**` or `ansible/provision.yml`, and manually (`workflow_dispatch`).

* **Jobs**:
    * **`terraform-deploy`**: Provisions all Azure resources using Terraform. Critically, it updates the `SSH_HOST` repository variable with the new VM's public IP.
    * **`provision-vm`**: Connects to the new VM and runs the `ansible/provision.yml` playbook to install Docker and other dependencies.
    * **`build-all-services`**: A matrix job that runs in parallel for all five microservices. It builds fresh Docker images and pushes them to Docker Hub. This ensures that a new infrastructure deployment always starts with the latest versions of all services.
    * **`deploy-all-services`**: The final job, which runs after provisioning and building is complete. It executes the `ansible/deploy-all.yml` playbook to clone the repository onto the VM and start the entire application stack using `docker compose`.

### 2. `reusable-deploy.yml`

This is the generic, reusable workflow for building and deploying any single microservice.

* **Trigger**: `workflow_call`, designed to be called by other workflows.
* **Inputs**: `service_name` (e.g., `frontend`) and `ssh_host`.

* **Jobs**:
    * **`build-and-push`**:
        1.  Logs in to Docker Hub.
        2.  Builds the Docker image for the specified service.
        3.  **Caché**: This job leverages GitHub Actions cache (`type=gha`) to speed up subsequent builds by reusing layers from previous runs, significantly reducing build times.
        4.  Pushes the new image to Docker Hub with the `latest` tag.
    * **`deploy-to-vm`**:
        1.  Executes the `ansible/playbook.yml` playbook.
        2.  The playbook is passed the `service_name` so that it only pulls and restarts the container for that specific microservice, leaving the rest of the application untouched.

### 3. Application Trigger Workflows (e.g., `cicd-frontend.yml`)

These files are very simple triggers that call the reusable workflow.

* **Triggers**: On `push` to `main` when code changes within that microservice's specific directory.
* **Job**: A single job that calls `reusable-deploy.yml`, passing the correct `service_name` and inheriting secrets.

---

## Configuration: Secrets and Variables

The pipelines rely on the following GitHub repository secrets and variables:

* **Secrets**:
    * `AZURE_CREDENTIALS`: Azure service principal credentials.
    * `DOCKERHUB_USERNAME`: Docker Hub username.
    * `DOCKERHUB_TOKEN`: Docker Hub access token.
    * `SSH_USERNAME`: Admin username for the Azure VM.
    * `SSH_PASSWORD`: Admin password for the Azure VM.
    * `REPO_ACCESS_TOKEN`: A GitHub Personal Access Token (PAT) used to update repository variables.
* **Variables**:
    * `SSH_HOST`: The public IP of the Azure VM. This is managed automatically by the infrastructure pipeline.