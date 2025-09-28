#!/bin/bash
set -euo pipefail

# Configuration
DOCKERUSER="docker"
BACKUP_DIR="/home/$DOCKERUSER/vault/nextcloud_backup"
DOCKER_COMPOSE_DIR="/home/$DOCKERUSER/quadrocloud"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="nextcloud_backup_$TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

echo "Starting Nextcloud backup process..."

# Change to the docker compose directory
cd "$DOCKER_COMPOSE_DIR"

# Check if containers are running
if ! docker compose ps -q app >/dev/null 2>&1; then
    echo "Error: Nextcloud app container is not running!"
    exit 1
fi

if ! docker compose ps -q db >/dev/null 2>&1; then
    echo "Error: Database container is not running!"
    exit 1
fi

# Verify the nextcloud volume exists and has data
echo "Verifying nextcloud volume..."
if ! docker volume inspect quadrocloud_nextcloud >/dev/null 2>&1; then
    echo "Error: nextcloud volume does not exist!"
    exit 1
fi

# Check the size of the volume to ensure it has data
VOLUME_SIZE=$(docker run --rm -v quadrocloud_nextcloud:/data alpine du -sb /data | cut -f1)
echo "Volume size: $((VOLUME_SIZE / 1024 / 1024)) MB"

if [ "$VOLUME_SIZE" -lt 10000000 ]; then  # Less than 10 MB
    echo "WARNING: Volume seems too small! This might indicate a problem with your volume."
fi

# Create backup info file
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << EOF
Nextcloud Backup
Created: $(date)
Backup ID: $BACKUP_NAME
Volume Size: $((VOLUME_SIZE / 1024 / 1024)) MB
EOF

# Backup Nextcloud volume
echo "Backing up Nextcloud data volume (this may take a while for large datasets)..."
docker run --rm \
  -v quadrocloud_nextcloud:/source:ro \
  -v "$BACKUP_DIR/$BACKUP_NAME:/backup" \
  alpine tar czf /backup/nextcloud_data.tar.gz -C /source .

# Backup database
echo "Backing up database..."
source .env  # Load DB password from .env file
docker compose exec -T db \
  mysqldump --single-transaction \
  --default-character-set=utf8mb4 \
  -u nextcloud \
  -p"$MYSQL_PASSWORD" \
  nextcloud | gzip > "$BACKUP_DIR/$BACKUP_NAME/nextcloud_db.sql.gz"

# Verify backup sizes
BACKUP_DATA_SIZE=$(stat -c%s "$BACKUP_DIR/$BACKUP_NAME/nextcloud_data.tar.gz")
echo "Backup data size: $((BACKUP_DATA_SIZE / 1024 / 1024)) MB"

if [ "$BACKUP_DATA_SIZE" -lt 10000000 ]; then  # Less than 10 MB
    echo "ERROR: Backup file is too small! Expected much larger file for 10GB of data."
    echo "This suggests the volume backup didn't work correctly."
    exit 1
fi

# Create checksums for verification
cd "$BACKUP_DIR/$BACKUP_NAME"
sha256sum nextcloud_data.tar.gz > nextcloud_data.tar.gz.sha256
sha256sum nextcloud_db.sql.gz > nextcloud_db.sql.gz.sha256

echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR/$BACKUP_NAME"
echo "Total backup size: $(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)"
