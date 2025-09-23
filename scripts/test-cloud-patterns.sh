#!/bin/bash

# Script completo para probar los patrones de diseño de nube implementados
# Circuit Breaker y Cache-Aside

echo "☁️  Testing Cloud Design Patterns Implementation"
echo "==============================================="
echo "Patterns implemented:"
echo "1. Circuit Breaker (todos-api & auth-api)"
echo "2. Cache-Aside (users-api)"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
fi

# Verificar que Docker esté ejecutándose
echo -e "${BLUE}🐳 Checking Docker status...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Verificar que los contenedores estén ejecutándose
echo -e "${BLUE}📦 Checking container status...${NC}"
containers=("redis" "zipkin" "users-api" "auth-api" "todos-api" "frontend")
all_running=true

for container in "${containers[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
        echo -e "${GREEN}✅ $container is running${NC}"
    else
        echo -e "${RED}❌ $container is not running${NC}"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo -e "${YELLOW}⚠️  Some containers are not running. Starting all services...${NC}"
    docker-compose up -d
    echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
    sleep 30
fi

echo ""
echo -e "${PURPLE}🔧 Testing Circuit Breaker Pattern${NC}"
echo "=================================="

# Test Circuit Breaker en todos-api
echo -e "${BLUE}📋 Testing Circuit Breaker in todos-api${NC}"
if wait_for_service "http://localhost:8082/todos" "todos-api"; then
    cb_status=$(make_request "http://localhost:8082/health/circuit-breaker")
    echo "Circuit Breaker Status:"
    echo "$cb_status" | jq '.' 2>/dev/null || echo "$cb_status"
else
    echo -e "${RED}❌ todos-api Circuit Breaker test failed${NC}"
fi

echo ""

# Test Circuit Breaker en auth-api
echo -e "${BLUE}📋 Testing Circuit Breaker in auth-api${NC}"
if wait_for_service "http://localhost:8000/version" "auth-api"; then
    cb_status=$(make_request "http://localhost:8000/health/circuit-breaker")
    echo "Circuit Breaker Status:"
    echo "$cb_status" | jq '.' 2>/dev/null || echo "$cb_status"
else
    echo -e "${RED}❌ auth-api Circuit Breaker test failed${NC}"
fi

echo ""
echo -e "${PURPLE}💾 Testing Cache-Aside Pattern${NC}"
echo "=============================="

# Test Cache-Aside en users-api
echo -e "${BLUE}📋 Testing Cache-Aside in users-api${NC}"
if wait_for_service "http://localhost:8083/users/" "users-api"; then
    # Primera consulta
    echo -e "${YELLOW}📊 First request (should hit database)${NC}"
    start_time=$(date +%s.%N)
    response1=$(make_request "http://localhost:8083/users/")
    end_time=$(date +%s.%N)
    duration1=$(echo "$end_time - $start_time" | bc)
    echo "Response time: ${duration1}s"
    
    sleep 1
    
    # Segunda consulta
    echo -e "${YELLOW}📊 Second request (should hit cache)${NC}"
    start_time=$(date +%s.%N)
    response2=$(make_request "http://localhost:8083/users/")
    end_time=$(date +%s.%N)
    duration2=$(echo "$end_time - $start_time" | bc)
    echo "Response time: ${duration2}s"
    
    # Comparar tiempos
    if (( $(echo "$duration2 < $duration1" | bc -l) )); then
        echo -e "${GREEN}✅ Cache-Aside working! Second request was faster${NC}"
    else
        echo -e "${YELLOW}⚠️  Cache-Aside may not be working optimally${NC}"
    fi
    
    # Test cache management
    echo -e "${YELLOW}📊 Testing cache management${NC}"
    cache_status=$(make_request "http://localhost:8083/users/cache/status")
    echo "Cache Status: $cache_status"
else
    echo -e "${RED}❌ users-api Cache-Aside test failed${NC}"
fi

echo ""
echo -e "${PURPLE}🧪 Integration Testing${NC}"
echo "====================="

# Test de integración: Login flow con Circuit Breaker
echo -e "${BLUE}📋 Testing login flow with Circuit Breaker${NC}"
login_data='{"username":"admin","password":"admin"}'
login_response=$(make_request "http://localhost:8000/login" "POST" "$login_data")
echo "Login Response:"
echo "$login_response" | jq '.' 2>/dev/null || echo "$login_response"

echo ""
echo -e "${GREEN}🎉 Cloud Design Patterns Testing Completed!${NC}"
echo ""
echo -e "${YELLOW}📊 Summary of Implemented Patterns:${NC}"
echo ""
echo -e "${BLUE}🔄 Circuit Breaker Pattern:${NC}"
echo "✅ todos-api: Protects against Redis failures"
echo "✅ auth-api: Protects against users-api failures"
echo "✅ Automatic fallback mechanisms"
echo "✅ Health monitoring endpoints"
echo ""
echo -e "${BLUE}💾 Cache-Aside Pattern:${NC}"
echo "✅ users-api: Caches user data in Redis"
echo "✅ Automatic cache invalidation"
echo "✅ Performance improvement for repeated requests"
echo "✅ Cache management endpoints"
echo ""
echo -e "${YELLOW}🔗 Monitoring Endpoints:${NC}"
echo "• todos-api Circuit Breaker: http://localhost:8082/health/circuit-breaker"
echo "• auth-api Circuit Breaker: http://localhost:8000/health/circuit-breaker"
echo "• users-api Cache Status: http://localhost:8083/users/cache/status"
echo "• users-api Cache Eviction: http://localhost:8083/users/cache/evict-all"
echo ""
echo -e "${PURPLE}💡 Next Steps for Testing:${NC}"
echo "1. Stop Redis container to test Circuit Breaker resilience"
echo "2. Stop users-api container to test auth-api Circuit Breaker"
echo "3. Monitor logs to see pattern behavior"
echo "4. Use the monitoring endpoints to track pattern status"
