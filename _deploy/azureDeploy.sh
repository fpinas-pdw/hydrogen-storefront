#!/bin/bash

# Cargar variables del archivo .env local
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: Archivo .env no encontrado en _deploy/"
    exit 1
fi

# Verificar que las variables requeridas estén definidas
if [ -z "$RESOURCE_GROUP" ] || [ -z "$REGISTRY_NAME" ] || [ -z "$APP_SERVICE_NAME" ] || [ -z "$APP_SERVICE_PLAN" ] || [ -z "$DOCKER_IMAGE_NAME" ]; then
    echo "Error: Variables requeridas no están definidas en .env"
    echo "Requeridas: RESOURCE_GROUP, REGISTRY_NAME, APP_SERVICE_NAME, APP_SERVICE_PLAN, DOCKER_IMAGE_NAME"
    exit 1
fi

echo "🚀 Iniciando proceso de deploy..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Registry: $REGISTRY_NAME"
echo "App Service: $APP_SERVICE_NAME"
echo "Docker Image: $DOCKER_IMAGE_NAME"

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
docker tag $DOCKER_IMAGE_NAME $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:latest
if [ $? -ne 0 ]; then
    echo "❌ Error al taggear imagen"
    exit 1
fi

# 5. Push a ACR
echo "⬆️ Subiendo imagen a ACR..."
docker push $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:latest
if [ $? -ne 0 ]; then
    echo "❌ Error al subir imagen a ACR"
    exit 1
fi

# 6. Crear App Service Plan (si no existe)
echo "📋 Creando App Service Plan..."
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --sku B1 --is-linux
if [ $? -ne 0 ]; then
    echo "⚠️ App Service Plan ya existe o error al crear (continuando...)"
fi

# 7. Deploy en Azure App Service
echo "🚀 Desplegando en Azure App Service..."
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --name $APP_SERVICE_NAME \
  --deployment-container-image-name $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:latest

if [ $? -ne 0 ]; then
    echo "❌ Error en el deploy del App Service"
    exit 1
fi

# 8. Configurar autenticación ACR
echo "🔧 Configurando autenticación ACR..."

# Habilitar usuario administrador en ACR
echo "🔑 Habilitando usuario administrador en ACR..."
az acr update --name $REGISTRY_NAME --admin-enabled true

# Obtener credenciales de administrador
echo "📋 Obteniendo credenciales de ACR..."
ACR_USERNAME=$(az acr credential show --name $REGISTRY_NAME --query "username" --output tsv)
ACR_PASSWORD=$(az acr credential show --name $REGISTRY_NAME --query "passwords[0].value" --output tsv)

# Configurar container con credenciales
echo "🐳 Configurando container con credenciales..."
az webapp config container set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name $REGISTRY_NAME.azurecr.io/$DOCKER_IMAGE_NAME:latest \
  --docker-registry-server-url https://$REGISTRY_NAME.azurecr.io \
  --docker-registry-server-user $ACR_USERNAME \
  --docker-registry-server-password $ACR_PASSWORD

# 9. Configurar variables de entorno
echo "⚙️ Configurando variables de entorno..."
az webapp config appsettings set \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \

# 9.1. Habilitar logging para diagnóstico
echo "📋 Habilitando logging..."
az webapp log config \
  --name $APP_SERVICE_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-container-logging filesystem


# 10. Reiniciar App Service
echo "🔄 Reiniciando App Service..."
az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP

echo "✅ Deploy completado exitosamente!"
echo "🌐 Tu aplicación estará disponible en: https://$APP_SERVICE_NAME.azurewebsites.net"
echo "⏱️ La aplicación puede tardar unos minutos en estar completamente operativa"