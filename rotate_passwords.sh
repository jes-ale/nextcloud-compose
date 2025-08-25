#!/bin/bash
set -euo pipefail

# Simple password rotation script for Nextcloud with Docker
echo "Starting MySQL password rotation..."

# Generate secure random passwords
NEW_DB_PASSWORD=$(openssl rand -base64 24)
NEW_ROOT_PASSWORD=$(openssl rand -base64 24)

echo "Generated new passwords:"
echo "DB Password: $NEW_DB_PASSWORD"
echo "Root Password: $NEW_ROOT_PASSWORD"
echo ""

# Update database passwords
echo "Updating database passwords..."
docker compose exec db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --execute="
ALTER USER 'nextcloud'@'%' IDENTIFIED BY '$NEW_DB_PASSWORD';
ALTER USER 'root'@'%' IDENTIFIED BY '$NEW_ROOT_PASSWORD';
FLUSH PRIVILEGES;
"

# Update .env file
echo "Updating .env file..."
sed -i "s/MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$NEW_DB_PASSWORD/" .env
sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$NEW_ROOT_PASSWORD/" .env

# Update Nextcloud's database configuration
echo "Updating Nextcloud's database configuration..."
docker compose exec app php occ config:system:set dbpassword --value="$NEW_DB_PASSWORD"

echo ""
echo "Password rotation completed successfully!"
echo "Please save the new passwords in a secure location."
echo "New DB Password: $NEW_DB_PASSWORD"
echo "New Root Password: $NEW_ROOT_PASSWORD"
