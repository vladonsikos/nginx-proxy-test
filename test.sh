#!/bin/bash

# Скрипт автоматического тестирования nginx proxy chain
# Запускать после docker-compose up -d

set -e

echo "=========================================="
echo "NGINX PROXY CHAIN TEST SUITE"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция проверки
check_result() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    
    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}[PASS]${NC} $description"
        echo "      Expected: $expected"
        echo "      Got: $(echo "$actual" | grep -o "\"x_forwarded_for\": \"[^\"]*\"" || true)"
    else
        echo -e "${RED}[FAIL]${NC} $description"
        echo "      Expected to contain: $expected"
        echo "      Got: $actual"
    fi
    echo ""
}

# Ожидание запуска сервисов
echo "Waiting for services to start..."
sleep 3

echo "=========================================="
echo "TEST 1: Health Check"
echo "=========================================="
echo ""

echo "Checking nginx1 health..."
curl -s http://localhost:8081/health || echo -e "${RED}nginx1 not responding${NC}"
echo ""

echo "Checking app health..."
curl -s http://localhost:8000/ | head -c 100
echo ""
echo ""

echo "=========================================="
echo "TEST 2: Direct Request (nginx1 -> app)"
echo "=========================================="
echo ""

echo "Command: curl http://localhost:8081/direct/"
echo ""
RESULT=$(curl -s http://localhost:8081/direct/)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

# Проверяем, что x_forwarded_for содержит IP клиента (не поддельный)
check_result "Direct request shows client IP" "172.25.0.1" "$RESULT"

echo "=========================================="
echo "TEST 3: Chain Request (nginx1 -> nginx2 -> nginx3 -> app)"
echo "=========================================="
echo ""

echo "Command: curl http://localhost:8081/chain/"
echo ""
RESULT=$(curl -s http://localhost:8081/chain/)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

# Проверяем цепочку IP
check_result "Chain shows nginx1 IP (172.25.0.10)" "172.25.0.10" "$RESULT"
check_result "Chain shows nginx2 IP (172.25.0.20)" "172.25.0.20" "$RESULT"

echo "=========================================="
echo "TEST 4: Short Chain (nginx1 -> nginx3 -> app)"
echo "=========================================="
echo ""

echo "Command: curl http://localhost:8081/short-chain/"
echo ""
RESULT=$(curl -s http://localhost:8081/short-chain/)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

check_result "Short chain shows nginx1 IP" "172.25.0.10" "$RESULT"

echo "=========================================="
echo "TEST 5: FORGE PROTECTION TEST"
echo "=========================================="
echo ""

echo "Attempting to forge X-Forwarded-For header..."
echo "Command: curl -H \"X-Forwarded-For: 1.2.3.4, FAKE_IP, 999.999.999.999\" http://localhost:8081/chain/"
echo ""
RESULT=$(curl -s -H "X-Forwarded-For: 1.2.3.4, FAKE_IP, 999.999.999.999" http://localhost:8081/chain/)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

# Проверяем, что поддельные IP НЕ присутствуют
if echo "$RESULT" | grep -q "1.2.3.4\|FAKE_IP\|999.999"; then
    echo -e "${RED}[FAIL]${NC} Forged IP detected in response!"
else
    echo -e "${GREEN}[PASS]${NC} Forged IP correctly ignored"
fi

# Проверяем, что реальные IP присутствуют
check_result "Real client IP present" "172.25.0.1" "$RESULT"
check_result "nginx1 IP present" "172.25.0.10" "$RESULT"
check_result "nginx2 IP present" "172.25.0.20" "$RESULT"

echo "=========================================="
echo "TEST 6: Multiple Forged Headers"
echo "=========================================="
echo ""

echo "Command: curl -H \"X-Forwarded-For: 8.8.8.8\" -H \"X-Real-IP: 9.9.9.9\" http://localhost:8081/direct/"
echo ""
RESULT=$(curl -s -H "X-Forwarded-For: 8.8.8.8" -H "X-Real-IP: 9.9.9.9" http://localhost:8081/direct/)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
echo ""

if echo "$RESULT" | grep -q "8.8.8.8\|9.9.9.9"; then
    echo -e "${RED}[FAIL]${NC} Forged headers detected!"
else
    echo -e "${GREEN}[PASS]${NC} All forged headers correctly replaced"
fi

echo ""
echo "=========================================="
echo "TEST SUITE COMPLETED"
echo "=========================================="
