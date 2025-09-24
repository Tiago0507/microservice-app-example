#!/bin/bash

# Script para validar la infraestructura localmente
# Uso: ./scripts/validate-infrastructure.sh

set -e

echo "Validando infraestructura con Terraform..."

# Cambiar al directorio de infraestructura
cd iac

echo "Ejecutando terraform init..."
terraform init

echo "Ejecutando terraform fmt..."
terraform fmt -check -recursive

echo "Ejecutando terraform validate..."
terraform validate

echo "Ejecutando terraform plan..."
terraform plan -out=tfplan

echo "Mostrando el plan..."
terraform show -no-color tfplan

echo "Validación completada exitosamente!"

# Limpiar archivo de plan
rm -f tfplan

echo "Archivos temporales limpiados."
