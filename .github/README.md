# CI/CD Automation with GitHub Actions

This directory contains all the GitHub Actions workflow definitions that automate the build, deployment, and management of both the infrastructure and the application services. The automation strategy follows modern GitOps and CI/CD principles to ensure a reliable, repeatable, and efficient delivery process.

## Guiding Philosophy

The CI/CD strategy is built upon a clear separation of concerns:

1.  **Infrastructure Pipeline (`cicd-infrastructure.yml`)**: This workflow is responsible for the entire lifecycle of the cloud infrastructure. It uses Terraform to provision resources and Ansible to perform initial server configuration (bootstrapping). It is triggered by changes to infrastructure-related code.

2.  **Application Pipelines (`reusable-deploy.yml`)**: These workflows manage the lifecycle of the individual microservices. They are designed to be highly modular and reusable. A central, reusable workflow handles the logic of building a Docker image, pushing it to a registry, and deploying it. Each microservice then has a simple "trigger" workflow that calls the reusable one when its specific source code changes.

This separation ensures that infrastructure changes are handled safely and independently from application updates, which can happen much more frequently.

---

## End-to-End Workflow Visualization

The entire process is orchestrated to connect infrastructure provisioning with application deployment seamlessly.

1.  **Infrastructure Provisioning**: An operator pushes a change to the `iac/` directory.
    * The `cicd-infrastructure.yml` workflow is triggered.
    * It runs a `terraform-deploy` job that creates a new Azure VM.
    * Upon completion, it retrieves the VM's Public IP address.
    * It securely updates a GitHub Repository Variable named `SSH_HOST` with this new IP.
    * A subsequent `provision-vm` job connects to this new VM (using the IP) and runs an Ansible playbook (`provision.yml`) to install Docker and other dependencies.

2.  **Application Deployment**: A developer pushes a code change to the `auth-api` microservice.
    * The `cicd-auth-api.yml` workflow is triggered.
    * This workflow's only job is to call the `reusable-deploy.yml` workflow, passing `service_name: auth-api` as a parameter.
    * The `reusable-deploy.yml` workflow takes over:
        * A `build-and-push` job builds a new Docker image for `auth-api` and pushes it to Docker Hub.
        * A `deploy-to-vm` job then starts. It reads the `SSH_HOST` variable from the repository to know which VM to target.
        * It connects to the VM and runs the main Ansible deployment playbook (`playbook.yml`), which pulls the new `auth-api` image from Docker Hub and restarts the corresponding container.

---

## Detailed Workflow Breakdown

### 1. `cicd-infrastructure.yml`

This is the master pipeline for managing the cloud environment. It follows a "recreate" strategy for simplicity and consistency.

* **Triggers**:
    * On `push` to the `main` branch if changes are detected in `iac/**`, `ansible/provision.yml`, or the workflow file itself.
    * Can also be triggered manually (`workflow_dispatch`).

* **Jobs**:
    * **`terraform-deploy`**:
        1.  **Checkout Code**: Clones the repository.
        2.  **Azure Login**: Authenticates with Azure using the `AZURE_CREDENTIALS` secret.
        3.  **Cleanup**: Deletes the entire existing resource group (`microservices-rg`) to ensure a clean slate.
        4.  **Terraform Init & Apply**: Initializes Terraform and runs `terraform apply -auto-approve` to provision all resources defined in the `iac/` directory (VM, VNet, NSG, etc.).
        5.  **Get Public IP**: After creation, it runs `terraform output` to extract the VM's public IP address.
        6.  **Update GitHub Variable**: This is a critical step. It uses the `gh` CLI to update the `SSH_HOST` repository variable with the new IP. This variable acts as the dynamic link between the infrastructure and application deployment pipelines.

    * **`provision-vm`**:
        1.  **Dependency**: This job `needs: terraform-deploy`, ensuring it only runs after the infrastructure is successfully created.
        2.  **Wait for VM**: It includes a robust step that waits for the VM to be fully available by polling port 22 (SSH).
        3.  **Provision with Ansible**: It executes the `ansible/provision.yml` playbook against the new VM. The VM's IP is passed in from the output of the `terraform-deploy` job. This playbook installs Docker, Docker Compose, and other essential tools, preparing the VM to run the application.

### 2. `reusable-deploy.yml`

This is the generic, reusable workflow for building and deploying any microservice. It is the core of the application CD process.

* **Trigger**:
    * `workflow_call`: It is designed to be called by other workflows.
* **Inputs**:
    * `service_name`: A mandatory string that specifies which microservice to build and deploy (e.g., `frontend`, `auth-api`).

* **Jobs**:
    * **`build-and-push`**:
        1.  **Docker Hub Login**: Authenticates with Docker Hub using `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets.
        2.  **Build and Push**: Uses the powerful `docker/build-push-action` to:
            * Find the correct Dockerfile within `./microservices/${{ inputs.service_name }}`.
            * Build the image.
            * Push it to the configured Docker Hub repository, tagged as `latest`.

    * **`deploy-to-vm`**:
        1.  **Dependency**: `needs: build-and-push`.
        2.  **Deploy with Ansible**: Executes the `ansible/playbook.yml`. This playbook is designed to be generic and relies on variables passed from the workflow:
            * It targets the host defined in the `vars.SSH_HOST` variable.
            * It uses the `service_name` input to tell Docker Compose which specific service to pull and restart.
            * It uses secrets for Docker Hub and SSH credentials to perform its tasks securely.
        3.  **Verify Service**: As a final step, it runs a command via Ansible to check the status of the deployed container on the VM, ensuring the deployment was successful.

### 3. Application Trigger Workflows (e.g., `cicd-frontend.yml`, `cicd-auth-api.yml`)

These files are very simple and act only as triggers.

* **Triggers**:
    * On `push` to `main` when code changes within that microservice's specific directory (e.g., `microservices/frontend/**`).

* **Job**:
    * **`call-reusable-workflow`**: A single job that calls `reusable-deploy.yml`.
        * It passes the specific microservice name via `with: service_name: ...`.
        * It uses `secrets: inherit` to securely forward all necessary credentials (like Docker Hub and SSH tokens) to the reusable workflow.

---

## Configuration: Secrets and Variables

The pipelines rely on the following GitHub repository secrets and variables for secure and flexible operation:

* **Secrets**:
    * `AZURE_CREDENTIALS`: JSON object containing Azure service principal credentials for Terraform.
    * `DOCKERHUB_USERNAME`: The username for Docker Hub.
    * `DOCKERHUB_TOKEN`: An access token for Docker Hub with push permissions.
    * `SSH_USERNAME`: The admin username for the Azure VM.
    * `SSH_PASSWORD`: The admin password for the Azure VM.
    * `REPO_ACCESS_TOKEN`: A GitHub Personal Access Token (PAT) with `repo` scope, used to update repository variables.

* **Variables**:
    * `SSH_HOST`: The public IP address of the Azure VM. This is managed automatically by the `cicd-infrastructure.yml` workflow and consumed by the `reusable-deploy.yml` workflow.