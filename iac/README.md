# Infrastructure as Code (IaC) - Terraform

Este directorio contiene la configuración de infraestructura como código usando Terraform para desplegar los microservicios en Azure.

## Estructura del Proyecto

```
iac/
├── main.tf                 # Configuración principal de Terraform
├── variables.tf            # Variables de entrada
├── outputs.tf              # Valores de salida
├── terraform.tfvars        # Valores de variables (no versionado)
├── cloud-init.yml          # Script de inicialización de la VM
└── modules/
    ├── network/            # Módulo de red virtual
    └── vm/                 # Módulo de máquina virtual
```

## Pipeline de CI/CD

El pipeline de infraestructura se ejecuta automáticamente en GitHub Actions y incluye los siguientes comandos:

### Comandos del Pipeline

1. **terraform init** - Inicializa el directorio de trabajo de Terraform
2. **terraform fmt** - Formatea los archivos de configuración
3. **terraform validate** - Valida la configuración de Terraform
4. **terraform plan** - Crea un plan de ejecución
5. **terraform show** - Muestra el plan detallado
6. **terraform apply** - Aplica los cambios (solo en main)
7. **terraform destroy** - Destruye la infraestructura (manual)

### Triggers del Pipeline

- **Push a main/develop**: Ejecuta validación y plan
- **Pull Request a main**: Ejecuta solo validación
- **Workflow Dispatch**: Ejecución manual con opción de destruir

### Secrets Requeridos

Configura los siguientes secrets en GitHub:

- `AZURE_CLIENT_ID`: ID del cliente de Azure
- `AZURE_CLIENT_SECRET`: Secreto del cliente de Azure
- `AZURE_TENANT_ID`: ID del tenant de Azure
- `AZURE_SUBSCRIPTION_ID`: ID de la suscripción de Azure

## Uso Local

### Prerrequisitos

- Terraform >= 1.6.0
- Azure CLI configurado
- Archivo `terraform.tfvars` con los valores necesarios

### Comandos Locales

```bash
# Inicializar Terraform
terraform init

# Formatear archivos
terraform fmt -recursive

# Validar configuración
terraform validate

# Crear plan
terraform plan -out=tfplan

# Mostrar plan
terraform show tfplan

# Aplicar cambios
terraform apply tfplan

# Destruir infraestructura
terraform destroy
```

### Variables Requeridas

Crea un archivo `terraform.tfvars` con:

```hcl
admin_password = "tu_password_seguro"
```

## Recursos Creados

- Grupo de recursos
- Red virtual y subred
- Máquina virtual con Docker
- Configuración de seguridad

## Monitoreo

El pipeline genera artefactos que incluyen:
- Plan de Terraform
- Outputs de la infraestructura
- Logs detallados de cada paso
