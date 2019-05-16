#!/bin/bash

DOWN=0

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d | --down)
            DOWN=1
            shift
            ;;
        *)
            echo Unknown option $key
            exit 1
            shift
            ;;
    esac
done

if [[ $DOWN -gt 0 ]]; then
    echo "==> Bringing containers down"
    docker-compose down
fi

echo "==> Building containers"
docker-compose up -d --build

notify-send "Docker build OK"

echo "==> Backend Logs"
docker logs resource-website_api_1 -f

