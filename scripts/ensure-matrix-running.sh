#!/bin/bash
# Ensure Matrix server is always running
# This script checks if Matrix is running and starts it if needed

set -e

MATRIX_DIR="$(pwd)"

echo "🔍 Checking Matrix Server Status"
echo "================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running"
    echo ""
    echo "Please start Docker:"
    echo "  - Mac: Open Docker Desktop"
    echo "  - Linux: sudo systemctl start docker"
    echo ""
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Check if containers exist
echo "🐳 Checking Matrix containers..."

SYNAPSE_RUNNING=$(docker ps -q -f name=matrix-synapse)
POSTGRES_RUNNING=$(docker ps -q -f name=matrix-postgres)
REDIS_RUNNING=$(docker ps -q -f name=matrix-redis)
ELEMENT_RUNNING=$(docker ps -q -f name=matrix-element)

if [ -n "$SYNAPSE_RUNNING" ]; then
    echo "   ✅ Synapse is running"
else
    echo "   ⚠️  Synapse is not running"
fi

if [ -n "$POSTGRES_RUNNING" ]; then
    echo "   ✅ PostgreSQL is running"
else
    echo "   ⚠️  PostgreSQL is not running"
fi

if [ -n "$REDIS_RUNNING" ]; then
    echo "   ✅ Redis is running"
else
    echo "   ⚠️  Redis is not running"
fi

if [ -n "$ELEMENT_RUNNING" ]; then
    echo "   ✅ Element Web is running"
else
    echo "   ⚠️  Element Web is not running"
fi

echo ""

# Start containers if any are not running
if [ -z "$SYNAPSE_RUNNING" ] || [ -z "$POSTGRES_RUNNING" ] || [ -z "$REDIS_RUNNING" ] || [ -z "$ELEMENT_RUNNING" ]; then
    echo "🚀 Starting Matrix services..."
    docker-compose up -d
    
    echo ""
    echo "⏳ Waiting for services to be healthy..."
    sleep 5
    
    # Wait for Synapse to be healthy
    MAX_WAIT=60
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if curl -s -f http://localhost:8008/health > /dev/null 2>&1; then
            echo "   ✅ Matrix server is healthy"
            break
        fi
        echo "   ⏳ Waiting for Matrix server... (${WAITED}s)"
        sleep 5
        WAITED=$((WAITED + 5))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "   ⚠️  Matrix server took longer than expected to start"
        echo "   Check logs: docker-compose logs synapse"
    fi
else
    echo "✅ All Matrix services are already running"
fi

echo ""
echo "🌐 Service URLs:"
echo "   Matrix Server: http://localhost:8008"
echo "   Element Web:   http://localhost:8080"
echo ""

# Test connectivity
echo "🔍 Testing connectivity..."
if curl -s -f http://localhost:8008/health > /dev/null 2>&1; then
    echo "   ✅ Matrix server is accessible"
else
    echo "   ❌ Matrix server is not responding"
    echo "   Check logs: docker-compose logs synapse"
fi

if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
    echo "   ✅ Element Web is accessible"
else
    echo "   ⚠️  Element Web is not responding"
fi

echo ""
echo "================================="
echo "✅ Matrix Server Status Check Complete"
echo "================================="
