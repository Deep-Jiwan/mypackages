#!/bin/bash

# Use environment variables with fallback to lowercase versions
GHCR_USERNAME="${GHCR_USERNAME:-$ghcr_username}"
GHCR_TOKEN="${GHCR_TOKEN:-$ghcr_token}"

echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin

echo "Downloading latest stack file..."
wget -O docker-compose-sensor.yml https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/docker-compose-sensor.yml

echo "Downloading scrape configuration..."
rm -rf scrape.yml  # Remove if it exists as directory
wget -O scrape.yml https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/scrape.yml

echo "Pulling latest images..."
docker compose -f docker-compose-sensor.yml pull

echo "Starting rolling update - victoria-metrics first (dependency)..."
docker compose -f docker-compose-sensor.yml up -d --wait --force-recreate victoria-metrics

echo "Rolling update - vmagent next..."
docker compose -f docker-compose-sensor.yml up -d --wait --force-recreate vmagent

echo "Rolling update - sensor-service last..."
docker compose -f docker-compose-sensor.yml up -d --wait --force-recreate sensor-service

echo "Rolling update complete - all services healthy"
