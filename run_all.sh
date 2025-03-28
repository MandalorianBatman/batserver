#!/bin/bash

# Start networks first
docker compose -f docker-compose-files/networks.yml up -d

# Short delay to ensure network is created
sleep 2

# Start infrastructure services
docker compose -f docker-compose-files/infra.yml up -d

# Start VPN services
docker compose -f docker-compose-files/vpn.yml up -d

# Start all other services
for file in docker-compose-files/*.yml; do
  if [[ "$file" != "docker-compose-files/networks.yml" && "$file" != "docker-compose-files/infra.yml" && "$file" != "docker-compose-files/vpn.yml" ]]; then
    echo "Starting services from $file..."
    docker compose -f "$file" up -d
  fi
done

echo "All services started!"
