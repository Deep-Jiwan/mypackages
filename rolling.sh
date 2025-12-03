#!/bin/bash

# Use environment variables with fallback to lowercase versions
GHCR_USERNAME="${GHCR_USERNAME:-$ghcr_username}"
GHCR_TOKEN="${GHCR_TOKEN:-$ghcr_token}"

# Only login if credentials are provided
if [ -n "$GHCR_USERNAME" ] && [ -n "$GHCR_TOKEN" ]; then
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
else
    echo "Skipping docker login - credentials not provided"
fi

echo "Downloading latest stack file..."
curl -L -o docker-compose-sensor.yml https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/docker-compose-sensor.yml

echo "Downloading scrape configuration..."
rm -rf scrape.yml  # Remove if it exists as directory or file
curl -L -o scrape.yml https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/scrape.yml

# Verify scrape.yml is a file, not a directory
if [ -d "scrape.yml" ]; then
    echo "Error: scrape.yml is a directory, removing and re-downloading..."
    rm -rf scrape.yml
    curl -L -o scrape.yml https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/scrape.yml
fi

echo "Pulling latest images..."
docker compose -f docker-compose-sensor.yml pull

# Rolling update: victoria-metrics
echo "Starting temporary victoria-metrics container..."
docker run -d --name victoria-metrics-temp --network edge-stack victoriametrics/victoria-metrics:latest --storageDataPath=/tmp/vm-data --httpListenAddr=:8428

echo "Waiting 5s for temporary container..."
sleep 5

echo "Removing old victoria-metrics container..."
docker rm -f victoria-metrics-10x || true

echo "Starting victoria-metrics from compose..."
docker compose -f docker-compose-sensor.yml up -d --force-recreate victoria-metrics

echo "Cleaning temporary victoria-metrics container..."
docker rm -f victoria-metrics-temp || true

# Rolling update: vmagent
echo "Starting temporary vmagent container..."
docker run -d --name vmagent-temp --network edge-stack victoriametrics/vmagent:latest --promscrape.config=/etc/vmagent/scrape.yml --remoteWrite.url=http://victoria-metrics-10x:8428/api/v1/write --httpListenAddr=:8429

echo "Waiting 5s for temporary container..."
sleep 5

echo "Removing old vmagent container..."
docker rm -f vmagent-10x || true

echo "Starting vmagent from compose..."
docker compose -f docker-compose-sensor.yml up -d --force-recreate vmagent

echo "Cleaning temporary vmagent container..."
docker rm -f vmagent-temp || true

# Rolling update: sensor-service
echo "Starting temporary sensor-service container..."
docker run -d --name sensor-service-temp --network edge-stack -e PYTHONUNBUFFERED=1 ghcr.io/deep-jiwan/10x-sensor-node:autobuild

echo "Waiting 5s for temporary container..."
sleep 5

echo "Removing old sensor-service container..."
docker rm -f sensor-service-10x || true

echo "Starting sensor-service from compose..."
docker compose -f docker-compose-sensor.yml up -d --force-recreate sensor-service

echo "Cleaning temporary sensor-service container..."
docker rm -f sensor-service-temp || true

echo "Rolling update complete - all services healthy"
