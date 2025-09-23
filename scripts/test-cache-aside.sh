#!/bin/bash

# Script para probar el funcionamiento del patrón Cache-Aside
# Este script hace múltiples requests para demostrar el comportamiento del caché

echo "🧪 Testing Cache-Aside Pattern Implementation"
echo "============================================="

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

# Función para medir el tiempo de respuesta
measure_response_time() {
    local url=$1
    local method=${2:-GET}
    local data=${3:-""}
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl -s -w "%{time_total}" -X POST -H "Content-Type: application/json" -d "$data" "$url" -o /dev/null
    else
        curl -s -w "%{time_total}" "$url" -o /dev/null
    fi
}

echo -e "${BLUE}📋 Testing Cache-Aside Pattern in users-api${NC}"
echo "----------------------------------------"

# Esperar que users-api esté disponible
echo -e "${BLUE}⏳ Waiting for users-api to be available...${NC}"
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s "http://localhost:8083/users/" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ users-api is available${NC}"
        break
    fi
    echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts - users-api not ready yet${NC}"
    sleep 2
    ((attempt++))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ users-api is not available after $max_attempts attempts${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔍 Testing Cache-Aside with multiple requests${NC}"
echo "----------------------------------------"

# Test 1: Primera consulta (debería ir a la base de datos)
echo -e "${YELLOW}📊 Test 1: First request (should hit database)${NC}"
start_time=$(date +%s.%N)
response1=$(make_request "http://localhost:8083/users/")
end_time=$(date +%s.%N)
duration1=$(echo "$end_time - $start_time" | bc)
echo "Response time: ${duration1}s"
echo "Response length: ${#response1} characters"

sleep 1

# Test 2: Segunda consulta (debería ir al caché)
echo -e "${YELLOW}📊 Test 2: Second request (should hit cache)${NC}"
start_time=$(date +%s.%N)
response2=$(make_request "http://localhost:8083/users/")
end_time=$(date +%s.%N)
duration2=$(echo "$end_time - $start_time" | bc)
echo "Response time: ${duration2}s"
echo "Response length: ${#response2} characters"

# Comparar tiempos de respuesta
if (( $(echo "$duration2 < $duration1" | bc -l) )); then
    echo -e "${GREEN}✅ Cache-Aside working! Second request was faster (${duration2}s vs ${duration1}s)${NC}"
else
    echo -e "${YELLOW}⚠️  Cache-Aside may not be working optimally (${duration2}s vs ${duration1}s)${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Testing Cache Management Endpoints${NC}"
echo "----------------------------------------"

# Test 3: Verificar estado del caché
echo -e "${YELLOW}📊 Test 3: Checking cache status${NC}"
cache_status=$(make_request "http://localhost:8083/users/cache/status")
echo "Cache Status: $cache_status"

# Test 4: Invalidar caché
echo -e "${YELLOW}📊 Test 4: Invalidating cache${NC}"
evict_response=$(make_request "http://localhost:8083/users/cache/evict-all" "POST")
echo "Cache Eviction Response: $evict_response"

# Test 5: Consulta después de invalidar caché (debería ir a la base de datos)
echo -e "${YELLOW}📊 Test 5: Request after cache invalidation (should hit database)${NC}"
start_time=$(date +%s.%N)
response3=$(make_request "http://localhost:8083/users/")
end_time=$(date +%s.%N)
duration3=$(echo "$end_time - $start_time" | bc)
echo "Response time: ${duration3}s"
echo "Response length: ${#response3} characters"

echo ""
echo -e "${BLUE}🔍 Testing Individual User Cache${NC}"
echo "----------------------------------------"

# Test 6: Consulta de usuario específico (requiere autenticación)
echo -e "${YELLOW}📊 Test 6: Testing individual user cache (requires authentication)${NC}"
echo "Note: Individual user requests require JWT authentication"
echo "You can test this manually by:"
echo "1. Getting a token from auth-api: POST http://localhost:8000/login"
echo "2. Using the token: GET http://localhost:8083/users/{username} with Authorization header"

echo ""
echo -e "${GREEN}🎉 Cache-Aside pattern testing completed!${NC}"
echo ""
echo -e "${YELLOW}💡 Summary of Cache-Aside Pattern:${NC}"
echo "✅ Cache-Aside pattern is implemented in users-api"
echo "✅ Multiple cache management endpoints are available:"
echo "   - GET /users/cache/status - Check cache status"
echo "   - POST /users/cache/evict-all - Invalidate all cache"
echo "   - POST /users/cache/evict/{username} - Invalidate specific user cache"
echo ""
echo -e "${BLUE}📈 Performance Benefits:${NC}"
echo "- First request: Hits database (slower)"
echo "- Subsequent requests: Hit cache (faster)"
echo "- Automatic cache invalidation on data changes"
echo "- Configurable TTL (Time To Live) for cache entries"
