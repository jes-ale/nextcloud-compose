#!/bin/bash

# Exit on errors and undefined variables
set -euo pipefail

# Configuration - EDITAR ESTAS VARIABLES SEGÚN TU ENTORNO
RESTORE_FILE="$1"                       # Archivo de backup a restaurar (pasado como argumento)
DOCKER_COMPOSE_DIR="/mycomposepath"     # Directorio del docker-compose.yml
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASSWORD="tu_password_bd"            # Reemplazar con tu password de BD

# Validar argumentos
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

if [[ ! -f "$RESTORE_FILE" ]]; then
    echo "Error: Archivo de backup no encontrado: $RESTORE_FILE"
    exit 1
fi

# Validar configuración
if [[ ! -d "$DOCKER_COMPOSE_DIR" ]] || [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
    echo "Error: No se encuentra el directorio o archivo docker-compose.yml"
    exit 1
fi

if [[ -z "$DB_PASSWORD" ]]; then
    echo "Error: Password de base de datos no configurado"
    exit 1
fi

# Extraer archivo de backup
echo "Extracting backup file..."
BACKUP_EXTRACT_DIR=$(mktemp -d)
tar xzf "$RESTORE_FILE" -C "$BACKUP_EXTRACT_DIR"
RESTORE_DIR=$(find "$BACKUP_EXTRACT_DIR" -maxdepth 1 -type d -name "nextcloud_backup_*" | head -1)

if [[ -z "$RESTORE_DIR" ]] || [[ ! -d "$RESTORE_DIR" ]]; then
    echo "Error: No se pudo encontrar el directorio de restauración"
    rm -rf "$BACKUP_EXTRACT_DIR"
    exit 1
fi

# Verificar checksums
echo "Verifying checksums..."
cd "$RESTORE_DIR"
if ! sha256sum -c nextcloud_volume.tar.gz.sha256 || ! sha256sum -c nextcloud_db.sql.gz.sha256; then
    echo "Error: Checksum verification failed"
    rm -rf "$BACKUP_EXTRACT_DIR"
    exit 1
fi

# Detener contenedores si están ejecutándose
echo "Stopping containers..."
cd "$DOCKER_COMPOSE_DIR"
docker compose down || true

# Crear volúmenes si no existen
echo "Creating volumes..."
docker volume create nextcloud 2>/dev/null || true
docker volume create db 2>/dev/null || true

# Restaurar volumen de Nextcloud
echo "Restoring Nextcloud volume..."
docker run --rm \
  -v nextcloud:/target \
  -v "$RESTORE_DIR:/backup" \
  alpine sh -c "rm -rf /target/* && tar xzf /backup/nextcloud_volume.tar.gz -C /target --strip-components=1"

# Iniciar contenedores
echo "Starting containers..."
docker compose up -d

# Esperar a que la base de datos esté disponible
echo "Waiting for database to be ready..."
sleep 30

# Restaurar base de datos
echo "Restoring database..."
gunzip -c "$RESTORE_DIR/nextcloud_db.sql.gz" | docker compose exec -T db mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"

# Limpiar archivos temporales
rm -rf "$BACKUP_EXTRACT_DIR"

echo "Restoration completed successfully!"
echo "Please remember to:"
echo "1. Verify your .env file is correctly placed in $DOCKER_COMPOSE_DIR"
echo "2. Disable maintenance mode when ready"
