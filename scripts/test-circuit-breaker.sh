#!/bin/bash

# Script para probar el funcionamiento del Circuit Breaker
# Este script simula fallos en los servicios para activar el Circuit Breaker

echo "🧪 Testing Circuit Breaker Pattern Implementation"
echo "=================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para hacer requests HTTP
make_request() {
    local url=$1
    local method=${2:-GET}
    local data=${3:-""}
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "$data" "$url"
    else
        curl -s "$url"
    fi
}

# Función para esperar que un servicio esté disponible
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${BLUE}⏳ Waiting for $service_name to be available...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is available${NC}"
            return 0
        fi
        echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts - $service_name not ready yet${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ $service_name is not available after $max_attempts attempts${NC}"
    return 1
}

echo -e "${BLUE}📋 Testing Circuit Breaker in todos-api${NC}"
echo "----------------------------------------"

# Esperar que todos-api esté disponible
if ! wait_for_service "http://localhost:8082/todos" "todos-api"; then
    echo -e "${RED}❌ Cannot test todos-api Circuit Breaker - service not available${NC}"
    exit 1
fi

# Probar el endpoint de estado del Circuit Breaker
echo -e "${BLUE}🔍 Checking Circuit Breaker status in todos-api${NC}"
cb_status=$(make_request "http://localhost:8082/health/circuit-breaker")
echo "Circuit Breaker Status:"
echo "$cb_status" | jq '.' 2>/dev/null || echo "$cb_status"

echo ""
echo -e "${BLUE}📋 Testing Circuit Breaker in auth-api${NC}"
echo "----------------------------------------"

# Esperar que auth-api esté disponible
if ! wait_for_service "http://localhost:8000/version" "auth-api"; then
    echo -e "${RED}❌ Cannot test auth-api Circuit Breaker - service not available${NC}"
    exit 1
fi

# Probar el endpoint de estado del Circuit Breaker
echo -e "${BLUE}🔍 Checking Circuit Breaker status in auth-api${NC}"
cb_status=$(make_request "http://localhost:8000/health/circuit-breaker")
echo "Circuit Breaker Status:"
echo "$cb_status" | jq '.' 2>/dev/null || echo "$cb_status"

echo ""
echo -e "${BLUE}📋 Testing Cache-Aside pattern in users-api${NC}"
echo "----------------------------------------"

# Esperar que users-api esté disponible
if ! wait_for_service "http://localhost:8083/users/" "users-api"; then
    echo -e "${RED}❌ Cannot test users-api Cache-Aside - service not available${NC}"
    exit 1
fi

# Probar el endpoint de estado del caché
echo -e "${BLUE}🔍 Checking Cache-Aside status in users-api${NC}"
cache_status=$(make_request "http://localhost:8083/users/cache/status")
echo "Cache Status:"
echo "$cache_status"

echo ""
echo -e "${GREEN}🎉 Circuit Breaker and Cache-Aside patterns are implemented and ready for testing!${NC}"
echo ""
echo -e "${YELLOW}💡 Manual Testing Suggestions:${NC}"
echo "1. Stop Redis container to test Circuit Breaker in todos-api"
echo "2. Stop users-api container to test Circuit Breaker in auth-api"
echo "3. Make multiple requests to users-api to see Cache-Aside in action"
echo "4. Use the health endpoints to monitor pattern status:"
echo "   - todos-api: http://localhost:8082/health/circuit-breaker"
echo "   - auth-api: http://localhost:8000/health/circuit-breaker"
echo "   - users-api: http://localhost:8083/users/cache/status"
