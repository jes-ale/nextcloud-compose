#!/bin/bash

# Exit on errors and undefined variables
set -euo pipefail

# Configuration - EDITAR ESTAS VARIABLES SEGÚN TU ENTORNO
BACKUP_DIR="/home/ubuntu/vault/nextcloud_backup"                    # Directorio donde se guardarán los backups
DOCKER_COMPOSE_DIR="/home/ubuntu/apis/quadrocloud"     # Directorio del docker-compose.yml
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASSWORD="tu_password_bd"            # Reemplazar con tu password de BD

# Obtener timestamp para los archivos
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_SUBDIR="$BACKUP_DIR/nextcloud_backup_$TIMESTAMP"

# Validar configuración
if [[ ! -d "$DOCKER_COMPOSE_DIR" ]] || [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
    echo "Error: No se encuentra el directorio o archivo docker-compose.yml"
    exit 1
fi

if [[ -z "$DB_PASSWORD" ]]; then
    echo "Error: Password de base de datos no configurado"
    exit 1
fi

# Crear directorio de backup
mkdir -p "$BACKUP_SUBDIR"

# Verificar que los contenedores estén ejecutándose
cd "$DOCKER_COMPOSE_DIR"
if ! docker compose ps -q app >/dev/null 2>&1; then
    echo "Error: Contenedor 'app' no está ejecutándose"
    exit 1
fi

if ! docker compose ps -q db >/dev/null 2>&1; then
    echo "Error: Contenedor 'db' no está ejecutándose"
    exit 1
fi

# Crear archivo de información del backup
echo "Creating backup information file..."
cat > "$BACKUP_SUBDIR/backup_info.txt" << EOF
Nextcloud Backup
Timestamp: $TIMESTAMP
Date: $(date)
Docker Compose Directory: $DOCKER_COMPOSE_DIR
Database Name: $DB_NAME
Database User: $DB_USER
EOF

# Backup de volúmenes Docker
echo "Backing up Docker volumes..."
docker run --rm \
  -v nextcloud:/source \
  -v "$BACKUP_SUBDIR:/backup" \
  alpine tar czf /backup/nextcloud_volume.tar.gz -C /source .

# Backup de la base de datos
echo "Backing up database..."
docker compose exec -T db \
  mysqldump --single-transaction \
  --default-character-set=utf8mb4 \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  "$DB_NAME" | gzip > "$BACKUP_SUBDIR/nextcloud_db.sql.gz"

# Verificar que los backups se crearon correctamente
if [[ ! -f "$BACKUP_SUBDIR/nextcloud_volume.tar.gz" ]] || \
   [[ ! -f "$BACKUP_SUBDIR/nextcloud_db.sql.gz" ]]; then
    echo "Error: Los archivos de backup no se crearon correctamente"
    exit 1
fi

# Crear checksums para verificación
echo "Creating checksums..."
cd "$BACKUP_SUBDIR"
sha256sum nextcloud_volume.tar.gz > nextcloud_volume.tar.gz.sha256
sha256sum nextcloud_db.sql.gz > nextcloud_db.sql.gz.sha256

# Comprimir todo el directorio de backup para facilitar la transferencia
echo "Compressing backup directory..."
cd "$BACKUP_DIR"
tar czf "nextcloud_backup_$TIMESTAMP.tar.gz" "nextcloud_backup_$TIMESTAMP"

# Limpiar directorio sin comprimir
rm -rf "$BACKUP_SUBDIR"

echo "Backup completed successfully!"
echo "Backup file: $BACKUP_DIR/nextcloud_backup_$TIMESTAMP.tar.gz"
echo "Checksum: $(sha256sum "$BACKUP_DIR/nextcloud_backup_$TIMESTAMP.tar.gz" | cut -d' ' -f1)"
