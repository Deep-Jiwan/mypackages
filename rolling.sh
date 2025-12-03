#!/bin/bash

echo $ghcr_token | docker login ghcr.io -u $ghcr_username --password-stdin
echo "Downloading latest stack file..."
wget https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/docker-compose-sensor.yml -O docker-compose-sensor.yml
echo "Downloading scrape configuration..."
wget https://raw.githubusercontent.com/Deep-Jiwan/mypackages/main/scrape.yml -O scrape.yml

echo "Pulling latest images..."
docker compose -f docker-compose-sensor.yml pull

echo "Starting rolling update - victoria-metrics first (dependency)..."
docker compose -f docker-compose-sensor.yml up -d --wait victoria-metrics

echo "Rolling update - vmagent next..."
docker compose -f docker-compose-sensor.yml up -d --wait vmagent

echo "Rolling update - sensor-service last..."
docker compose -f docker-compose-sensor.yml up -d --wait sensor-service

echo "Rolling update complete - all services healthy"
