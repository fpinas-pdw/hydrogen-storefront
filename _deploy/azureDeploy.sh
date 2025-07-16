#!/bin/bash

# Cargar variables del archivo .env local (de _deploy/)
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: Archivo .env no encontrado en _deploy/"
    exit 1
fi

# Verificar que las variables requeridas estén definidas
if [ -z "$RESOURCE_GROUP" ] || [ -z "$REGISTRY_NAME" ] || [ -z "$CONTAINER_APP_NAME" ] || [ -z "$DOCKER_IMAGE_NAME" ] || [ -z "$DOCKER_IMAGE_TAG" ]; then
    echo "Error: Variables requeridas no están definidas en .env"
    echo "Requeridas: RESOURCE_GROUP, REGISTRY_NAME, CONTAINER_APP_NAME, DOCKER_IMAGE_NAME, DOCKER_IMAGE_TAG"
    exit 1
fi

CONTAINERAPPS_ENV_NAME="${CONTAINERAPPS_ENV_NAME:-shopify-env}"
LOCATION="${LOCATION:-westeurope}" # Cambia por tu región si es necesario

# Log Analytics Workspace opcional
if [ -z "$LOG_ANALYTICS_WORKSPACE" ]; then
    LOG_ANALYTICS_WORKSPACE="${CONTAINERAPPS_ENV_NAME}-logs"
fi

echo "🚀 Iniciando proceso de deploy..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Registry: $REGISTRY_NAME"
echo "Container App: $CONTAINER_APP_NAME"
echo "Docker Image: $DOCKER_IMAGE_NAME"
echo "Docker Tag: $DOCKER_IMAGE_TAG"
echo "Container Apps Env: $CONTAINERAPPS_ENV_NAME"
echo "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
echo "Location: $LOCATION"

# Cambiar al directorio raíz para el build de Docker
cd ..

# 1. Crear imagen local
echo "📦 Creando imagen Docker local..."
docker build -t $DOCKER_IMAGE_NAME .
BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
    echo "❌ Error al crear la imagen Docker (código: $BUILD_STATUS)"
    exit 1
else
    echo "✅ Imagen Docker creada exitosamente"
fi

# 2. Crear ACR en Azure (si no existe)
echo "🏗️ Creando Azure Container Registry..."
az acr create --name $REGISTRY_NAME --sku Basic --resource-group $RESOURCE_GROUP
if [ $? -ne 0 ]; then
    echo "⚠️ Registry ya existe o error al crear (continuando...)"
fi

# 3. Login a ACR
echo "🔐 Haciendo login a ACR..."
az acr login --name $REGISTRY_NAME
if [ $? -ne 0 ]; then
    echo "❌ Error al hacer login a ACR"
    exit 1
fi

# 4. Taggear imagen
echo "🏷️ Taggeando imagen..."
docker tag $DOCKER_IMAGE_NAME $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG
if [ $? -ne 0 ]; then
    echo "❌ Error al taggear imagen"
    exit 1
fi

# 5. Push a ACR
echo "⬆️ Subiendo imagen a ACR..."
docker push $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG
if [ $? -ne 0 ]; then
    echo "❌ Error al subir imagen a ACR"
    exit 1
fi

# 6. Configurar permisos de ACR para Container Apps (usar managed identity)
echo "🔑 Configurando permisos de ACR..."
az acr update --name $REGISTRY_NAME --admin-enabled false

# 7. Crear el environment de Container Apps (solo la primera vez)
echo "🌱 Creando Azure Container Apps Environment (si no existe)..."
az containerapp env show --name $CONTAINERAPPS_ENV_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1
if [ $? -ne 0 ]; then
  az containerapp env create \
    --name $CONTAINERAPPS_ENV_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION
  if [ $? -ne 0 ]; then
    echo "❌ Error al crear el environment de Container Apps"
    exit 1
  fi
else
  echo "ℹ️ El environment de Container Apps ya existe, continuando..."
fi

# 8. Leer variables del .env del directorio raíz y formatearlas para Azure
echo "⚙️ Preparando variables de entorno para la app..."
ENV_VARS=""
if [ -f .env ]; then
  while IFS='=' read -r key value; do
    if [[ ! "$key" =~ ^# ]] && [[ -n "$key" ]]; then
      key=$(echo $key | xargs)
      value=$(echo $value | sed 's/^"\(.*\)"$/\1/' | xargs)
      ENV_VARS="$ENV_VARS $key=$value"
    fi
  done < .env
else
  echo "❌ Error: No se encontró el archivo .env (variables de entorno de la app Hydrogen)"
  exit 1
fi

# 9. Crear o actualizar el Container App
echo "🚀 Desplegando en Azure Container Apps..."
az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "🔄 El Container App ya existe, actualizando imagen y variables de entorno..."
  az containerapp update \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --image $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG \
    --set-env-vars $ENV_VARS
else
  echo "🆕 El Container App no existe, creándolo..."
  az containerapp create \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINERAPPS_ENV_NAME \
    --image $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG \
    --target-port 3000 \
    --ingress external \
    --registry-server $REGISTRY_NAME.azurecr.io \
    --assign-identity --system-assigned \
    --env-vars $ENV_VARS
  
  # Asignar permisos AcrPull a la identidad del Container App
  echo "🔐 Asignando permisos AcrPull a la Container App..."
  PRINCIPAL_ID=$(az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query "identity.principalId" --output tsv)
  ACR_ID=$(az acr show --name $REGISTRY_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)
  az role assignment create --assignee $PRINCIPAL_ID --role "AcrPull" --scope $ACR_ID
fi

if [ $? -ne 0 ]; then
  echo "❌ Error al crear el Container App"
  exit 1
fi

echo "✅ Deploy completado exitosamente!"
echo "🌐 Cuando esté listo, tu aplicación estará disponible en la URL pública de Azure Container Apps."
echo "⏱️ La aplicación puede tardar unos minutos en estar completamente operativa"