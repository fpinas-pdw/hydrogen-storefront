# Azure Deploy Script

Este directorio contiene el script de automatización para desplegar la aplicación Hydrogen Storefront en **Azure Container Apps**.

## Prerrequisitos

Antes de ejecutar el script, asegúrate de tener instalado:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/)

Y estar autenticado en Azure:
```bash
az login
```

## Configuración

1. **Crear archivo de configuración de despliegue**:  
   Copia el archivo de ejemplo y configura tus variables para el despliegue:
   ```bash
   cp .env.example .env
   ```
   Este archivo debe estar en el directorio `_deploy/`.

2. **Crear y configurar el archivo `.env` del directorio raíz**:  
   Este archivo contiene las variables de entorno que tu aplicación Hydrogen necesita en producción (por ejemplo, tokens, dominios, secretos, etc.).  
   Debe estar en la raíz del proyecto (`hydrogen-storefront/.env`).  
   Ejemplo:
   ```
   SESSION_SECRET=foobar
   PUBLIC_STORE_DOMAIN=tu-tienda.myshopify.com
   PUBLIC_STOREFRONT_API_TOKEN=tu_token
   PUBLIC_CHECKOUT_DOMAIN=tu-tienda.myshopify.com
   ```

3. **Editar variables del archivo `_deploy/.env`**:  
   Modifica el archivo `_deploy/.env` con tus valores específicos:
   - `RESOURCE_GROUP`: Nombre del grupo de recursos de Azure
   - `REGISTRY_NAME`: Nombre del Azure Container Registry (solo minúsculas y números, sin guiones bajos ni puntos)
   - `CONTAINER_APP_NAME`: Nombre del Azure Container App (solo minúsculas, números y guiones)
   - `DOCKER_IMAGE_NAME`: Nombre de la imagen Docker
   - `DOCKER_IMAGE_TAG`: Tag de la imagen Docker (por ejemplo, `latest`)
   - `CONTAINERAPPS_ENV_NAME`: (opcional) Nombre del entorno de Container Apps. Si no se define, se usará `shopify-env`
   - `LOCATION`: (opcional) Región de Azure. Si no se define, se usará `westeurope`
   - `LOG_ANALYTICS_WORKSPACE`: (opcional) Nombre del Log Analytics Workspace. Si no se define, se usará `${CONTAINERAPPS_ENV_NAME}-logs`
   - Puedes añadir más variables de entorno necesarias para tu app Hydrogen

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

El script automatiza todo el proceso de deploy en Azure Container Apps:

1. 📦 **Build**: Crea la imagen Docker localmente
2. 🏗️ **ACR**: Crea Azure Container Registry (si no existe)
3. 🔐 **Login**: Se autentica en ACR
4. 🏷️ **Tag**: Etiqueta la imagen para ACR usando el tag definido en `DOCKER_IMAGE_TAG`
5. ⬆️ **Push**: Sube la imagen a ACR
6. 🌱 **Log Analytics Workspace**: Crea el Log Analytics Workspace (si no existe) usando el nombre definido en la variable de entorno
7. 🌱 **Environment**: Crea el Azure Container Apps Environment (si no existe)
8. 🚀 **Deploy**: Crea o actualiza el Azure Container App
9. ⚙️ **Variables de entorno de la app**: Lee el archivo `.env` del directorio raíz y configura esas variables en el Container App (imprescindible para que Hydrogen funcione en producción)

El script es idempotente: si los recursos ya existen, los actualiza (redeploy).

## Resultado

Al finalizar exitosamente, la aplicación estará disponible en una URL similar a:
```
https://[CONTAINER_APP_NAME].[random].azurecontainerapps.io
```

## Ver Logs

Para ver en tiempo real los logs de tu aplicación desplegada en Azure Container Apps:
```bash
az containerapp logs show --name [CONTAINER_APP_NAME] --resource-group [RESOURCE_GROUP] --follow
```

## Troubleshooting

- **Error de permisos**: Asegúrate de haber ejecutado `chmod +x azureDeploy.sh`
- **Error de autenticación**: Verifica que hayas ejecutado `az login`
- **Error de Docker**: Confirma que Docker esté corriendo con `docker ps`
- **Variables faltantes**: Revisa que todas las variables estén definidas en ambos archivos `.env` (`_deploy/.env` y el de la raíz)
- **Problemas de red o timeout**: Asegúrate de que tu app escuche en el puerto 3000 y en `0.0.0.0`
- **Errores de nombres de recursos**: Usa solo minúsculas, números y guiones para los nombres de recursos de Azure
- **Errores con Log Analytics Workspace**: Si no defines `LOG_ANALYTICS_WORKSPACE`, el script usará `${CONTAINERAPPS_ENV_NAME}-logs` por defecto.

---