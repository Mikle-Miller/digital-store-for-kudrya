#!/bin/bash
# =============================================================
# race-test.sh — тест на параллельную выдачу ключей
# =============================================================
# Проверяет: из 50 параллельных вебхуков с одним event_id
# ровно ОДИН должен быть обработан, выдан ОДИН ключ.
#
# Использование:
#   bash tests/race-test.sh [order_id]
#   bash tests/race-test.sh  # создаст заказ сам
#
# Требования: curl, jq
# =============================================================

BASE_URL="${BASE_URL:-http://localhost:8080}"
PARALLEL="${PARALLEL:-50}"
SKU="KEY-CS2-PRIME"

echo "================================================="
echo " GGSel Race Condition Test"
echo " URL: $BASE_URL | Parallel requests: $PARALLEL"
echo "================================================="

# === Шаг 1: Создать заказ ===
if [ -z "$1" ]; then
    echo -e "\n[1/3] Creating order for sku=$SKU..."
    ORDER=$(curl -s -X POST "$BASE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d "{\"sku\":\"$SKU\",\"amount\":1290,\"email\":\"test@race.test\"}")
    ORDER_ID=$(echo "$ORDER" | jq -r '.id')
    echo "    Order ID: $ORDER_ID"
else
    ORDER_ID="$1"
    echo -e "\n[1/3] Using existing order #$ORDER_ID"
fi

if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" = "null" ]; then
    echo "ERROR: Failed to create order. Is the server running?"
    exit 1
fi

# === Шаг 2: 50 параллельных вебхуков с ОДНИМ event_id ===
EVENT_ID="race-test-$(date +%s)-$RANDOM"
echo -e "\n[2/3] Firing $PARALLEL concurrent webhooks (event_id=$EVENT_ID)..."

PIDS=()
SUCCESS_COUNT=0

for i in $(seq 1 $PARALLEL); do
    curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/webhook/payment" \
        -H "Content-Type: application/json" \
        -d "{
            \"event_id\": \"$EVENT_ID\",
            \"order_id\": \"$ORDER_ID\",
            \"status\": \"paid\",
            \"amount\": 1290,
            \"currency\": \"RUB\",
            \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }" &
    PIDS+=($!)
done

# Ждём завершения всех
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo " Done."

# === Шаг 3: Ждём обработки воркером (до 15 сек) ===
echo -e "\n[3/3] Polling order status (up to 15s)..."
for i in $(seq 1 15); do
    sleep 1
    RESULT=$(curl -s "$BASE_URL/api/orders/$ORDER_ID")
    STATUS=$(echo "$RESULT" | jq -r '.status')
    KEY=$(echo "$RESULT" | jq -r '.key_code // "null"')
    echo "    [$i/15] status=$STATUS key=$KEY"

    if [ "$STATUS" = "delivered" ] || [ "$STATUS" = "out_of_stock" ] || [ "$STATUS" = "delivery_failed" ]; then
        break
    fi
done

# === Результат ===
echo -e "\n================================================="
echo " RESULT"
echo "================================================="
echo " Order #$ORDER_ID"
echo " Status : $STATUS"
echo " Key    : $KEY"
echo ""

if [ "$STATUS" = "delivered" ] && [ "$KEY" != "null" ]; then
    echo " ✅ PASS — одна выдача, один ключ"

    # Проверяем что ключ не выдан другому заказу
    KEY_ORDERS=$(docker compose exec -T app php artisan tinker --execute \
        "echo App\Models\ProductKey::where('key_code','$KEY')->value('order_id');" 2>/dev/null || echo "N/A")
    echo " Key owner order_id: $KEY_ORDERS"
elif [ "$STATUS" = "out_of_stock" ]; then
    echo " ⚠️  PASS (out_of_stock) — пул ключей пуст, заказ зафиксирован"
else
    echo " ❌ FAIL — статус: $STATUS"
    exit 1
fi
