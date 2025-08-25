#!/bin/bash
set -euo pipefail

# Configuration
BACKUP_DIR="/mypath"
DOCKER_COMPOSE_DIR="/mycomposepath"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="nextcloud_backup_$TIMESTAMP"

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

echo "Starting Nextcloud backup process..."

# Check if containers are running
cd "$DOCKER_COMPOSE_DIR"
if ! docker compose ps -q app >/dev/null 2>&1; then
    echo "Error: Nextcloud app container is not running!"
    exit 1
fi

if ! docker compose ps -q db >/dev/null 2>&1; then
    echo "Error: Database container is not running!"
    exit 1
fi

# Create backup info file
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << EOF
Nextcloud Backup
Created: $(date)
Backup ID: $BACKUP_NAME
EOF

# Backup Nextcloud volume
echo "Backing up Nextcloud data volume (this may take a while)..."
docker run --rm \
  -v nextcloud:/source \
  -v "$BACKUP_DIR/$BACKUP_NAME:/backup" \
  alpine tar czf /backup/nextcloud_data.tar.gz -C /source .

# Backup database
echo "Backing up database..."
source "$DOCKER_COMPOSE_DIR/.env"  # Load DB password from .env file
docker compose exec -T db \
  mysqldump --single-transaction \
  --default-character-set=utf8mb4 \
  -u nextcloud \
  -p"$MYSQL_PASSWORD" \
  nextcloud | gzip > "$BACKUP_DIR/$BACKUP_NAME/nextcloud_db.sql.gz"

# Create checksums for verification
cd "$BACKUP_DIR/$BACKUP_NAME"
sha256sum nextcloud_data.tar.gz > nextcloud_data.tar.gz.sha256
sha256sum nextcloud_db.sql.gz > nextcloud_db.sql.gz.sha256

# Create restore instructions
cat > "$BACKUP_DIR/$BACKUP_NAME/RESTORE_INSTRUCTIONS.txt" << 'EOF'
To restore this backup:

1. Ensure Docker and Docker Compose are installed
2. Place your docker-compose.yml and .env files in the target directory
3. Extract this backup folder to the target server
4. Run the restore script: ./restore_nextcloud.sh
EOF

# Create simple restore script
cat > "$BACKUP_DIR/$BACKUP_NAME/restore_nextcloud.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "Starting Nextcloud restore process..."

# Check if we're in the backup directory
if [[ ! -f "nextcloud_data.tar.gz" || ! -f "nextcloud_db.sql.gz" ]]; then
    echo "Error: Please run this script from the backup directory"
    exit 1
fi

# Verify backup integrity
echo "Verifying backup integrity..."
sha256sum -c nextcloud_data.tar.gz.sha256
sha256sum -c nextcloud_db.sql.gz.sha256

# Restore Nextcloud volume
echo "Restoring Nextcloud data..."
docker run --rm \
  -v nextcloud:/target \
  -v "$(pwd):/backup" \
  alpine sh -c "rm -rf /target/* && tar xzf /backup/nextcloud_data.tar.gz -C /target"

# Restore database
echo "Restoring database..."
source ../.env  # Load DB password from .env file in parent directory
gunzip -c nextcloud_db.sql.gz | docker compose exec -T db mysql -u nextcloud -p"$MYSQL_PASSWORD" nextcloud

echo "Restore completed successfully!"
echo "Please start your containers with: docker compose up -d"
echo "And remember to disable maintenance mode when ready"
EOF

chmod +x "$BACKUP_DIR/$BACKUP_NAME/restore_nextcloud.sh"

echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR/$BACKUP_NAME"
echo "To transfer to new server, compress this directory: tar czf $BACKUP_NAME.tar.gz $BACKUP_NAME/"
