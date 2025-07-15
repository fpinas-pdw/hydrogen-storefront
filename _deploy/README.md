# Azure Deploy Script

Este directorio contiene el script de automatización para desplegar la aplicación Hydrogen Storefront en Azure.

## Prerrequisitos

Antes de ejecutar el script, asegúrate de tener instalado:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/)

Y estar autenticado en Azure:
```bash
az login
```

## Configuración

1. **Crear archivo de configuración**: Copia el archivo de ejemplo y configura tus variables:
   ```bash
   cp .env.example .env
   ```

2. **Editar variables**: Modifica el archivo `.env` con tus valores específicos:
   - `RESOURCE_GROUP`: Nombre del grupo de recursos de Azure
   - `REGISTRY_NAME`: Nombre del Azure Container Registry
   - `APP_SERVICE_NAME`: Nombre del Azure App Service
   - `APP_SERVICE_PLAN`: Nombre del plan de App Service
   - `DOCKER_IMAGE_NAME`: Nombre de la imagen Docker

## Ejecución

### 1. Dar permisos de ejecución al script
```bash
chmod +x azureDeploy.sh
```

### 2. Ejecutar el script
```bash
./azureDeploy.sh
```

## ¿Qué hace el script?

El script automatiza todo el proceso de deploy:

1. 📦 **Build**: Crea la imagen Docker localmente
2. 🏗️ **ACR**: Crea Azure Container Registry (si no existe)
3. 🔐 **Login**: Se autentica en ACR
4. 🏷️ **Tag**: Etiqueta la imagen para ACR
5. ⬆️ **Push**: Sube la imagen a ACR
6. 📋 **Plan**: Crea App Service Plan (si no existe)
7. 🚀 **Deploy**: Despliega en Azure App Service

## Resultado

Al finalizar exitosamente, la aplicación estará disponible en:
```
https://[APP_SERVICE_NAME].azurewebsites.net
```

## Troubleshooting

- **Error de permisos**: Asegúrate de haber ejecutado `chmod +x azureDeploy.sh`
- **Error de autenticación**: Verifica que hayas ejecutado `az login`
- **Error de Docker**: Confirma que Docker esté corriendo con `docker ps`
- **Variables faltantes**: Revisa que todas las variables estén definidas en