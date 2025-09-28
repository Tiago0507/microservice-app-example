# Polyglot Microservices Application with Automated DevOps Pipelines

This repository contains a complete TODO application built on a microservices architecture. It showcases a diverse technology stack (Go, Java, Vue, Python, Node.js) and is fully managed by a robust, automated CI/CD pipeline using GitHub Actions, Terraform, and Ansible. The entire infrastructure and application deployment process is automated, from cloud resource provisioning to application updates.

**DevOps Engineers**:
* Santiago Valencia García - A00395902
* Danna Valentina López Muñoz

**Professor**: DevOps and Cloud Engineer Christian David Flor Astudillo

**Course**: Software Engineering V

**Date**: September 29, 2025

Faculty of Engineering, Design and Applied Sciences

Icesi University. Cali, Valle del Cauca, Colombia

---

## Architecture Overview

The application is composed of five distinct microservices, a Redis cache, and a Zipkin instance for distributed tracing. The frontend acts as an API Gateway, routing requests to the appropriate backend services.

![Application Architecture Diagram](/images/Microservices.png)

A detailed breakdown of each service and the implementation of cloud design patterns (Cache-Aside and Circuit Breaker) can be found in the [**Microservices Documentation**](./microservices/README.md).

---

## Repository Structure

This repository is organized into distinct directories, each with a specific responsibility. Each directory contains its own detailed `README.md` file.

* **`./iac/`**: Contains all the Infrastructure as Code written in Terraform. It defines all the necessary Azure cloud resources, such as the virtual machine, virtual network, and security groups.
    * [**-> Go to IaC Documentation**](./iac/README.md)
* **`./ansible/`**: Holds the **Ansible** playbooks for **Configuration Management**. These scripts are responsible for bootstrapping the server (installing Docker) and automating application deployments.
    * [**-> Go to Ansible Documentation**](./ansible/README.md)
* **`./microservices/`**: The core of the application. It contains the source code for each individual microservice, their Dockerfiles, and the implementation of the cloud design patterns.
    * [**-> Go to Microservices Documentation**](./microservices/README.md)
* **`./.github/workflows/`**: Defines all the **CI/CD pipelines** using **GitHub Actions**. This is where the entire automated workflow for infrastructure and application deployment is orchestrated.
    * [**-> Go to Pipelines Documentation**](./.github/workflows/README.md)

---

## Automated CI/CD Flow

The project is driven by a fully automated CI/CD process that separates infrastructure and application concerns.

1.  **Infrastructure Pipeline**: Triggered by changes in the `iac/` or `ansible/` directories. This GitHub Actions workflow uses Terraform to build (or rebuild) the Azure environment and then runs an Ansible playbook to provision the VM with Docker.
2.  **Application Pipelines**: Each microservice has its own pipeline that is triggered by code changes in its specific directory. These pipelines build a new Docker image, push it to Docker Hub, and then run an Ansible playbook to deploy the new version to the VM.

This entire flow is designed to be hands-off, enabling continuous delivery from a `git push`.

---

## Branching Strategy: Unified GitHub Flow

To maintain agility and a constantly deployable `main` branch, both the Development and Operations teams use a unified GitHub Flow strategy.

The `main` branch is always considered production-ready and is protected. All work is done on short-lived feature branches that are merged into `main` via Pull Requests (PRs).

#### **Branch Naming Convention**

To clearly distinguish the type of work, branches follow this convention: `<type>/<team>/<description>`

* **`<type>`**: `feature`, `fix`, `chore`, `hotfix`.
* **`<team>`**: `dev` for application development, `ops` for infrastructure or operations work.
* **`<description>`-**: A brief, kebab-case description of the task.

**Examples**:
* `feature/dev/add-user-profile-picture`
* `fix/ops/update-terraform-vm-size`
* `chore/dev/refactor-auth-service`

#### **Workflow**

1.  Create a new, descriptive branch from `main`.
2.  Commit changes to the branch.
3.  Push the branch and open a Pull Request to `main`.
4.  The PR must pass all automated CI checks and receive a mandatory code review from another team member.
5.  Once approved, the PR is merged into `main`, which automatically triggers the corresponding CD pipeline to deploy the changes.

---

## Getting Started: Automated Deployment

There is no manual setup required to deploy the application. The entire process is handled by the GitHub Actions CI/CD pipelines.

### Prerequisites

To enable the automation, the following secrets and variables must be configured in the GitHub repository settings (`Settings > Secrets and variables > Actions`):

* **Secrets**:
    * `AZURE_CREDENTIALS`: Service principal for authenticating with Azure.
    * `DOCKERHUB_USERNAME`: Your Docker Hub username.
    * `DOCKERHUB_TOKEN`: Your Docker Hub access token.
    * `SSH_PASSWORD`: The password for the admin user on the Azure VM.
    * `SSH_USERNAME`: The admin username for the Azure VM (e.g., `adminuser`).
    * `REPO_ACCESS_TOKEN`: A GitHub PAT to allow workflows to update repository variables.
* **Variables**:
    * `SSH_HOST`: This variable is created and managed automatically by the infrastructure pipeline. You do not need to set it initially.

### Triggering a Deployment

* **To Deploy Infrastructure**: Make a commit and push to the `main` branch with changes inside the `iac/` directory. This will trigger the `cicd-infrastructure.yml` workflow.
* **To Deploy a Microservice**: Make a commit and push to the `main` branch with changes inside a specific service's directory (e.g., `microservices/frontend/`). This will trigger that service's specific CI/CD workflow.

### Accessing the Application

Once the infrastructure pipeline has run successfully, the public IP of the virtual machine will be available in the logs of the pipeline run. The application will be accessible at: `http://<VM_PUBLIC_IP>:8080`.

### Cleanup

To destroy all the cloud resources created by the automation, you can run the `terraform destroy` command from the `iac` directory on your local machine after authenticating with Azure CLI.

```bash
# Navigate to the iac directory
cd iac

# Authenticate with Azure
az login

# Destroy all infrastructure
terraform destroy
```