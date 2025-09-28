# Infrastructure as Code (IaC)

This directory contains all Terraform configurations required to provision and manage the cloud infrastructure for the microservices application on Microsoft Azure. By defining the infrastructure declaratively, this IaC setup ensures consistent, repeatable, and automated environment creation, which is a cornerstone of modern DevOps practices.

## Guiding Principles

The design of this infrastructure code adheres to several key principles:

* **Modularity**: The infrastructure is broken down into logical, reusable modules (`network`, `vm`). This separation of concerns makes the code easier to understand, maintain, and scale. For instance, the networking components can be updated independently of the virtual machine.
* **Reusability**: Modules are designed to be self-contained, allowing them to be potentially reused in other projects with different configurations.
* **Maintainability**: Using variables and a clear structure ensures that making changes, such as switching a region or VM size, is straightforward and requires modifying only a single point in the code.
* **Security**: Sensitive data, such as passwords, is managed through variable definitions and is intended to be provided via a secure mechanism (`.tfvars` file, environment variables, or a secrets manager), preventing hardcoded credentials in the version-controlled codebase.

---

## Architecture Deep Dive

The Terraform configuration provisions a complete, isolated, and accessible environment on Azure.

### Core Components

* **Resource Group (`azurerm_resource_group`)**: Acts as a logical container for all Azure resources deployed by this configuration. A resource group (`microservices-rg`) is fundamental for management, as it allows all related resources to be viewed, managed, and deleted as a single unit.

* **Virtual Network and Subnet (`azurerm_virtual_network`, `azurerm_subnet`)**: These resources create an isolated network environment in the cloud.
    * The **VNet** (`microservices-vnet`) provides a private network space (`10.0.0.0/16`) for the application's resources, ensuring they are not directly exposed to the public internet unless explicitly configured to be.
    * The **Subnet** (`microservices-subnet`) is a partition within the VNet (`10.0.1.0/24`) where the application's virtual machine is placed. This allows for finer-grained network control and organization.

* **Virtual Machine and Networking (`azurerm_linux_virtual_machine`, `azurerm_public_ip`, `azurerm_network_interface`, `azurerm_network_security_group`)**: These components provision the compute host and its connectivity.
    * A **Linux Virtual Machine** (`microservices-vm`) is the core compute resource where the Docker-based microservices will run. An `Ubuntu 22.04-LTS Gen2` image is used, providing a modern and stable operating system. The size `Standard_B2s` is chosen as a cost-effective option suitable for development and testing workloads.
    * A **Static Public IP** (`microservices-pip`) is provisioned to ensure the VM has a consistent, predictable public address. This is crucial for accessing the frontend application and for SSH management without the IP address changing on every reboot.
    * The **Network Interface (NIC)** (`microservices-nic`) attaches the VM to the subnet, allowing it to communicate with other resources within the VNet and the internet (via the public IP).
    * The **Network Security Group (NSG)** (`microservices-nsg`) serves as a stateful firewall. It is configured with specific inbound rules to allow traffic only on necessary ports, following the principle of least privilege:
        * **Port 22**: Allows SSH access for administrative purposes.
        * **Ports 8080, 8000, 8082, 8083**: Expose the specific endpoints for the `frontend`, `auth-api`, `todos-api`, and `users-api` respectively, allowing them to be accessed from the internet.

---

## File Structure and Workflow

The code is organized logically to provide a clear and maintainable structure.

* `main.tf`: This is the primary entry point for the root module. It defines the Azure provider, creates the main resource group, and then calls the `network` and `vm` modules, passing the necessary variables and resource dependencies between them.
* `variables.tf`: This file centralizes the declaration of all input variables used in the root module. Defining them here allows for easy customization and serves as documentation for the configurable parameters of the infrastructure.
* `outputs.tf`: This file declares the outputs of the root module. After a successful deployment, it makes key information, like the VM's public IP, easily accessible from the command line.

### Modules

* **`/modules/network`**: Encapsulates all networking resources (VNet, Subnet). It takes the resource group name and location as input and outputs the ID of the created subnet, which is then used by the `vm` module.
* **`/modules/vm`**: Encapsulates the compute resources (VM, NIC, Public IP, NSG). This module depends on the `network` module for the subnet ID, demonstrating a clear dependency graph within the infrastructure code.

---

## Deployment Process

Deploying this infrastructure involves a standard and predictable Terraform workflow, designed to be executed from the `iac` directory.

1.  **Initialization**:
    ```bash
    terraform init
    ```
    This command prepares the working directory. It downloads the necessary provider plugins (in this case, `azurerm`) and sets up the backend for storing the state file.

2.  **Planning**:
    ```bash
    terraform plan
    ```
    This command creates an execution plan. Terraform performs a dry run, determining what actions are needed to achieve the desired state defined in the `.tf` files. This step is critical for reviewing changes before applying them, preventing accidental modifications to the infrastructure.

3.  **Application**:
    ```bash
    terraform apply
    ```
    This command executes the plan created in the previous step, provisioning or modifying the resources in Azure. It will prompt for confirmation before proceeding. Once completed, the outputs defined in `outputs.tf` will be displayed.

## Configuration and Management

### Variables

The infrastructure is highly configurable through the variables defined in `variables.tf`. For local development or specific deployments, it is recommended to create a `terraform.tfvars` file (which is ignored by `.gitignore`) to provide values for these variables, especially for the sensitive `admin_password`.

**Example `terraform.tfvars`:**
```terraform
admin_password = "YourSecurePassword123!"
```