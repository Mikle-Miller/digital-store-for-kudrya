#!/bin/bash

# ================================================================
# GGSel -- Приёмочные тесты (Acceptance Tests)
# Для macOS и Linux (Bash)
# ================================================================

BASE_URL=${1:-"http://localhost:8080"}
LABEL=${2:-"LOCAL"}
NO_RESET=$3

PASS_COUNT=0
FAIL_COUNT=0

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

write_header() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================================${NC}"
}
write_step() { echo -e "${YELLOW}  -> $1${NC}"; }
record() {
    local name=$1
    local ok=$2
    local detail=$3
    if [ "$ok" = true ]; then
        PASS_COUNT=$((PASS_COUNT+1))
        echo -e "${GREEN}  [PASS] $name${NC}"
    else
        FAIL_COUNT=$((FAIL_COUNT+1))
        echo -e "${RED}  [FAIL] $name${NC}"
    fi
    if [ -n "$detail" ]; then echo -e "${GRAY}         $detail${NC}"; fi
}

api_post() {
    local path=$1
    local body=$2
    curl -s -X POST "$BASE_URL$path" \
         -H "Content-Type: application/json" \
         -d "$body" || echo '{"error": "curl failed"}'
}
api_get() {
    curl -s "$BASE_URL$1" || echo ""
}

wait_status() {
    local id=$1
    for i in {1..20}; do
        sleep 1
        local resp=$(api_get "/api/orders/$id")
        local status=$(echo "$resp" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        if [[ "$status" == "delivered" || "$status" == "out_of_stock" || "$status" == "delivery_failed" ]]; then
            echo "$resp"
            return
        fi
    done
    api_get "/api/orders/$id"
}

do_reset() {
    if [ "$NO_RESET" == "-NoReset" ]; then
        echo -e "${YELLOW}  [SKIP] Сброс БД пропущен (режим -NoReset для PROD)${NC}"
        return
    fi
    write_step "Сброс БД (migrate:fresh + seed)..."
    curl -s -X POST -m 60 "$BASE_URL/api/admin/db/reset" >/dev/null 2>&1
    
    for i in {1..30}; do
        sleep 2
        local resp=$(curl -s -m 2 "$BASE_URL/api/admin/stats" || echo "")
        if [[ "$resp" == *"keys_available"* ]]; then
            local keys=$(echo "$resp" | grep -o '"keys_available":[0-9]*' | cut -d':' -f2)
            echo -e "${GRAY}     БД готова: $keys ключей${NC}"
            return
        fi
    done
    echo -e "${RED}     ОШИБКА: сервер не ответил после сброса!${NC}"
}

# ================================================================
write_header "Приёмочные тесты GGSel [$LABEL]  ->  $BASE_URL"
# ================================================================

write_step "Проверка сервера..."
stats=$(api_get "/api/admin/stats")
if [[ -z "$stats" || "$stats" != *"keys_available"* ]]; then
    echo -e "${RED}  ОШИБКА: сервер недоступен!${NC}"
    exit 1
fi
total=$(echo "$stats" | grep -o '"total":[0-9]*' | cut -d':' -f2)
keys=$(echo "$stats" | grep -o '"keys_available":[0-9]*' | cut -d':' -f2)
echo -e "${GREEN}     OK: всего_заказов=$total ключей=$keys${NC}"

do_reset

# ---------------------------------------------------------------
write_header "КРИТЕРИЙ #1: 50 параллельных вебхуков -> 1 выдача, 1 ключ"

write_step "Создаём заказ..."
order1=$(api_post "/api/orders" '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"race@test.com"}')
id1=$(echo "$order1" | grep -o '"id":[0-9]*' | cut -d':' -f2)
echo -e "${GRAY}     Заказ #$id1${NC}"

if [ -z "$id1" ]; then
    record "50 параллельных вебхуков -> 1 выдача" false "Не удалось создать заказ"
else
    evt1="race-$(date +%s)-$RANDOM"
    write_step "Шлём 50 параллельных вебхуков (event_id=$evt1)..."
    
    body="{\"event_id\":\"$evt1\",\"order_id\":$id1,\"status\":\"paid\",\"amount\":1290,\"currency\":\"RUB\"}"
    for i in {1..50}; do
        curl -s -X POST "$BASE_URL/api/webhook/payment" -H "Content-Type: application/json" -d "$body" >/dev/null &
    done
    wait
    
    echo -e "${GRAY}     50 вебхуков отправлено${NC}"
    write_step "Ждём обработки (до 20 сек)..."
    
    f1=$(wait_status "$id1")
    status1=$(echo "$f1" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    key_code1=$(echo "$f1" | grep -o '"key_code":"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${GRAY}     Статус=$status1 Ключ=$key_code1${NC}"
    if [[ "$status1" == "delivered" && -n "$key_code1" && "$key_code1" != "null" ]]; then
        record "50 параллельных вебхуков -> 1 выдача, 1 ключ" true "Статус=$status1 Ключ=$key_code1"
    else
        record "50 параллельных вебхуков -> 1 выдача, 1 ключ" false "Статус=$status1 Ключ=$key_code1"
    fi
fi

# ---------------------------------------------------------------
write_header "КРИТЕРИЙ #2: Повторный вебхук с тем же event_id ничего не меняет"

write_step "Создаём заказ..."
order2=$(api_post "/api/orders" '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"idem@test.com"}')
id2=$(echo "$order2" | grep -o '"id":[0-9]*' | cut -d':' -f2)
echo -e "${GRAY}     Заказ #$id2${NC}"

if [ -z "$id2" ]; then
    record "Идемпотентность вебхука" false "Не удалось создать заказ"
else
    evt2="idem-$(date +%s)-$RANDOM"
    write_step "Первый вебхук..."
    w2a=$(api_post "/api/webhook/payment" "{\"event_id\":\"$evt2\",\"order_id\":$id2,\"status\":\"paid\",\"amount\":1290,\"currency\":\"RUB\"}")
    w2a_status=$(echo "$w2a" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Ответ 1: $w2a_status${NC}"
    
    st2=$(wait_status "$id2")
    st2_status=$(echo "$st2" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    st2_key=$(echo "$st2" | grep -o '"key_code":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Статус: $st2_status Ключ=$st2_key${NC}"
    
    write_step "Повторный вебхук с ТЕМ ЖЕ event_id..."
    w2b=$(api_post "/api/webhook/payment" "{\"event_id\":\"$evt2\",\"order_id\":$id2,\"status\":\"paid\",\"amount\":1290,\"currency\":\"RUB\"}")
    w2b_status=$(echo "$w2b" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Ответ 2: $w2b_status${NC}"
    
    sleep 3
    st2b=$(api_get "/api/orders/$id2")
    st2b_status=$(echo "$st2b" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${GRAY}     Статус после повтора: $st2b_status${NC}"
    
    if [[ "$w2b_status" == "duplicate" && "$st2b_status" == "$st2_status" ]]; then
        record "Повторный вебхук -> duplicate, статус не изменился" true "Ответ 2=$w2b_status Статус=$st2b_status"
    else
        record "Повторный вебхук -> duplicate, статус не изменился" false "Ответ 2=$w2b_status Статус=$st2b_status"
    fi
fi

# ---------------------------------------------------------------
write_header "КРИТЕРИЙ #3: Вебхук пришёл раньше создания заказа"

write_step "Вебхук для несуществующего order_id=9999999..."
early_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/webhook/payment" \
    -H "Content-Type: application/json" \
    -d "{\"event_id\":\"early-$RANDOM\",\"order_id\":9999999,\"status\":\"paid\",\"amount\":100,\"currency\":\"RUB\"}")

echo -e "${GRAY}     HTTP код: $early_code${NC}"

if [[ "$early_code" -ge 500 && "$early_code" -lt 600 ]]; then
    record "Вебхук до заказа -> HTTP 5xx (платёжка повторит)" true "Получен HTTP $early_code (ожидался 503)"
else
    record "Вебхук до заказа -> HTTP 5xx (платёжка повторит)" false "Получен HTTP $early_code (ожидался 503)"
fi

# ---------------------------------------------------------------
write_header "КРИТЕРИЙ #4: Пустой пул -> out_of_stock, безопасный retry"

do_reset

write_step "Удаляем все ключи из БД..."
curl -s -X POST "$BASE_URL/api/admin/db/empty" >/dev/null
sleep 1
stats4=$(api_get "/api/admin/stats")
keys4=$(echo "$stats4" | grep -o '"keys_available":[0-9]*' | cut -d':' -f2)
echo -e "${GRAY}     Ключей в пуле: $keys4${NC}"

write_step "Создаём заказ..."
order4=$(api_post "/api/orders" '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"oos@test.com"}')
id4=$(echo "$order4" | grep -o '"id":[0-9]*' | cut -d':' -f2)
echo -e "${GRAY}     Заказ #$id4${NC}"

if [ -z "$id4" ]; then
    record "Пустой пул -> out_of_stock" false "Не удалось создать заказ"
else
    write_step "Оплачиваем..."
    api_post "/api/webhook/payment" "{\"event_id\":\"oos-$RANDOM\",\"order_id\":$id4,\"status\":\"paid\",\"amount\":1290,\"currency\":\"RUB\"}" >/dev/null
    
    stOos=$(wait_status "$id4")
    oos_status=$(echo "$stOos" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Статус: $oos_status${NC}"
    
    write_step "Добавляем 60 ключей..."
    curl -s -X POST "$BASE_URL/api/admin/db/add_keys" >/dev/null
    sleep 1
    stats4b=$(api_get "/api/admin/stats")
    keys4b=$(echo "$stats4b" | grep -o '"keys_available":[0-9]*' | cut -d':' -f2)
    echo -e "${GRAY}     Ключей в пуле: $keys4b${NC}"
    
    write_step "Retry #1 (Повторная выдача)..."
    api_post "/api/admin/retry/$id4" "{}" >/dev/null
    stR1=$(wait_status "$id4")
    r1_status=$(echo "$stR1" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    r1_key=$(echo "$stR1" | grep -o '"key_code":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Статус после retry1: $r1_status Ключ=$r1_key${NC}"
    
    write_step "Retry #2 (Проверка идемпотентности)..."
    r2=$(api_post "/api/admin/retry/$id4" "{}")
    r2_already=$(echo "$r2" | grep -o '"already_delivered":true')
    echo -e "${GRAY}     Retry 2: уже_доставлен? $r2_already${NC}"
    sleep 2
    
    stR2=$(api_get "/api/orders/$id4")
    r2_key=$(echo "$stR2" | grep -o '"key_code":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GRAY}     Ключ после retry2: $r2_key${NC}"
    
    if [[ "$oos_status" == "out_of_stock" ]]; then
        record "Пустой пул -> out_of_stock (без падения)" true "Статус=$oos_status"
    else
        record "Пустой пул -> out_of_stock (без падения)" false "Статус=$oos_status"
    fi
    
    if [[ "$r1_status" == "delivered" ]]; then
        record "После пополнения retry -> delivered" true "Статус=$r1_status Ключ=$r1_key"
    else
        record "После пополнения retry -> delivered" false "Статус=$r1_status Ключ=$r1_key"
    fi
    
    if [[ "$r2_key" == "$r1_key" && -n "$r1_key" && "$r1_key" != "null" ]]; then
        record "Повторный retry идемпотентен (тот же ключ)" true "Ключ 1=$r1_key | Ключ 2=$r2_key"
    else
        record "Повторный retry идемпотентен (тот же ключ)" false "Ключ 1=$r1_key | Ключ 2=$r2_key"
    fi
fi

# ---------------------------------------------------------------
write_header "КРИТЕРИЙ #5: Промокод ONCEONLY лимит=1 под параллельностью (10 заказов)"

do_reset

write_step "10 параллельных заказов с промокодом ONCEONLY..."
temp_dir=$(mktemp -d)

for i in {1..10}; do
    curl -s -X POST "$BASE_URL/api/orders" \
         -H "Content-Type: application/json" \
         -d '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"promo5@test.com","promo":"ONCEONLY"}' > "$temp_dir/out_$i.json" &
done
wait

with_discount=0
no_discount=0

for i in {1..10}; do
    if grep -q '"discount":[1-9]' "$temp_dir/out_$i.json"; then
        with_discount=$((with_discount+1))
    else
        no_discount=$((no_discount+1))
    fi
done
rm -rf "$temp_dir"

echo -e "${GRAY}     Со скидкой: $with_discount | Без скидки: $no_discount${NC}"
if [ "$with_discount" -eq 1 ]; then
    record "ONCEONLY: ровно 1 из 10 получил скидку" true "Со скидкой=$with_discount (ожидалось 1)"
else
    record "ONCEONLY: ровно 1 из 10 получил скидку" false "Со скидкой=$with_discount (ожидалось 1)"
fi

# ================================================================
write_header "ИТОГИ [$LABEL]"
# ================================================================

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}  PASS: $PASS_COUNT  |  FAIL: $FAIL_COUNT${NC}"
    echo -e "${GREEN}  *** ВСЕ КРИТЕРИИ ПРОЙДЕНЫ [$LABEL] ***${NC}"
else
    echo -e "${RED}  PASS: $PASS_COUNT  |  FAIL: $FAIL_COUNT${NC}"
    echo -e "${RED}  *** ПРОВАЛЕНО: $FAIL_COUNT тест(ов) [$LABEL] ***${NC}"
fi
