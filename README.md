# 1. Branching Strategy

Below is a clear branching strategy for both team roles.

## 1.1 Developers – GitHub Flow (2.5%)

The development team uses GitHub Flow for small and frequent changes with `main` always deployable.

- `main` is always deployable; small and frequent changes.
- short-lived branches off `main`: `feature/<topic>`, `fix/<bug>`, `chore/<task>`, `hotfix/<incident>`.
- open a PR to `main` with mandatory review; CI must be green before merge.
- merging to `main` triggers CD to the target environment.
- `hotfix`: prioritized, quick validation, merge to `main` and immediate deploy.

**Guards**: required CI checks, branch protection on `main`, and required approvals.

**Rationale**: simplicity, agility, and short recovery times.

## 1.2 Operations – GitHub Flow (2.5%)

The operations team also uses GitHub Flow for operational changes and continuous delivery.

- `main` is always deployable; small and frequent changes.
- short-lived branches off `main`: `fix/<topic>`, `chore/<task>`, `hotfix/<incident>`.
- PR to `main` with review; merging triggers CD to the target environment.
- `hotfix`: prioritized, quick validation, merge to `main` and immediate deploy.

**Guards**: required CI checks, branch protection on `main`, and required approvals.

**Rationale**: simplicity, agility, and short recovery times aligned with availability goals.

---

# 2. Infrastructure Deployment Guide

This section details the process for deploying the application's infrastructure to Azure using Terraform. The architecture consists of a single Virtual Machine that runs the microservices as Docker containers orchestrated by Docker Compose.

The deployment strategy is based on the principle of separating the artifact build stage from the deployment stage. Docker images are built and pushed to a container registry first, and the target VM then pulls these pre-built images. This ensures a fast, reliable, and resource-efficient deployment.

## 2.1 Prerequisites

Ensure the following tools and accounts are available on the local machine before proceeding.

- **Terraform v1.0+**: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Azure CLI**: [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Docker**: [Installation Guide](https://docs.docker.com/get-docker/)
- An active **Azure Subscription**.
- A **Docker Hub Account**: [Sign up here](https://hub.docker.com/).

## 2.2 Initial Environment Setup

These one-time setup steps are required for any user who wishes to deploy the infrastructure.

### Step 1: Authenticate with Azure

The user authenticates with Azure through the command-line interface. This command opens a browser window for login.

```bash
az login
```

### Step 2: Configure the Environment

There are two options for deployment depending on the goal. Option A is the fastest and uses pre-built container images. Option B is for developers who wish to modify the microservice source code and deploy their own versions.

#### Option A: Quick Deploy Using Pre-Built Images (Recommended for most users)

This path uses the official, pre-built Docker images for the application. The user does not need to build the images themselves.

1.  **Create the Secrets File**: Terraform requires a password for the VM. Create a file named `terraform.tfvars` inside the `iac/` directory. This file must not be committed to Git. Add the following content, replacing the password value:

    ```terraform
    admin_password = "YourComplexPassword123!"
    ```

After this step, proceed directly to the [2.3 Deployment Execution](#23-deployment-execution) section.

---

#### Option B: Build and Deploy Custom Images (Developer Workflow)

This path is for users who intend to modify the microservice source code and need to build their own custom Docker images.

1.  **Log in to Docker Hub:**
    ```bash
    docker login
    ```

2.  **Build and Push each microservice:** From the root of the project repository, execute the following commands. Replace `YOUR_DOCKERHUB_USERNAME` with the actual Docker Hub username.

    ```bash
    # Frontend
    docker build -t YOUR_DOCKERHUB_USERNAME/frontend ./microservices/frontend
    docker push YOUR_DOCKERHUB_USERNAME/frontend

    # Auth API
    docker build -t YOUR_DOCKERHUB_USERNAME/auth-api ./microservices/auth-api
    docker push YOUR_DOCKERHUB_USERNAME/auth-api

    # ... (Repeat for all other microservices) ...
    ```

3.  **Update `docker-compose.prod.yml`**: In this file, replace all instances of the original author's Docker Hub username with the user's own username (`YOUR_DOCKERHUB_USERNAME`).

4.  **Publish the Compose File**: Upload the updated `docker-compose.prod.yml` to a public URL, such as a [GitHub Gist](https://gist.github.com/). Click on the "Raw" button to get a direct URL to the file content.

5.  **Update `cloud-init.yml`**: In the `iac/cloud-init.yml` file, replace the placeholder URL in the `curl` command with the raw URL of the user's `docker-compose.prod.yml` file.

6.  **Create the Secrets File**: Create a file named `terraform.tfvars` inside the `iac/` directory with the VM password.

    ```terraform
    admin_password = "YourComplexPassword123!"
    ```
After this step, proceed to the **[2.3 Deployment Execution](#23-deployment-execution)** section.

## 2.3 Deployment Execution

With the setup complete, the infrastructure is deployed using the standard Terraform workflow. Navigate to the iac/ directory to run these commands.

1. **Initialize Terraform:** This command downloads the required providers.

```terraform
terraform init
```

2. **Plan the Deployment:** This command shows an execution plan of the resources that will be created.

```terraform
terraform plan
```

3. **Apply the Configuration:** This command creates the infrastructure in Azure.

```terraform
terraform apply
```

Confirm the action by typing yes when prompted. Then this will show the public IP that the vm took

## 2.4 Verification

**Access the Application:** The frontend is accessible in a web browser at http://<VM_PUBLIC_IP>:8080.

## 2.5 Cleanup

```terraform
terraform destroy
```

Confirm the action by typing yes when prompted.