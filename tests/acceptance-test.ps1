param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Label   = "LOCAL",
    [switch]$NoReset  # для PROD: пропускать migrate:fresh
)

# Устанавливаем кодировку UTF-8 для корректного отображения кириллицы в консоли
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================================================
# GGSel -- Приёмочные тесты (Acceptance Tests)
# Запуск локально:  .\tests\acceptance-test.ps1
# Запуск на проде:  .\tests\acceptance-test.ps1 -BaseUrl http://digital-store.duckdns.org -Label PROD
# ================================================================

$passCount = 0
$failCount = 0
$Results   = @()

function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}
function Write-Step($text) { Write-Host "  -> $text" -ForegroundColor Yellow }

function Record($id, $name, $ok, $detail) {
    $script:Results += [PSCustomObject]@{ID=$id;Name=$name;OK=$ok;Detail=$detail}
    if ($ok) { $script:passCount++; Write-Host "  [PASS] $name" -ForegroundColor Green }
    else      { $script:failCount++; Write-Host "  [FAIL] $name" -ForegroundColor Red }
    if ($detail) { Write-Host "         $detail" -ForegroundColor Gray }
}

function ApiPost($path, $body) {
    try {
        return Invoke-RestMethod -Uri "$BaseUrl$path" -Method POST `
            -ContentType "application/json" -Body ($body | ConvertTo-Json -Depth 5) `
            -ErrorAction Stop -TimeoutSec 30
    } catch {
        $code = 0; try { $code = $_.Exception.Response.StatusCode.value__ } catch {}
        return [PSCustomObject]@{__code=$code; status=""; id=$null; key_code=$null}
    }
}

function ApiGet($path) {
    try { return Invoke-RestMethod -Uri "$BaseUrl$path" -Method GET -ErrorAction Stop -TimeoutSec 15 }
    catch { return $null }
}

function WaitStatus($id, $targets, $sec = 20) {
    for ($i = 0; $i -lt $sec; $i++) {
        Start-Sleep -Seconds 1
        $o = ApiGet "/api/orders/$id"
        if ($o -and ($o.status -in $targets)) { return $o }
    }
    return ApiGet "/api/orders/$id"
}

function DoReset() {
    if ($NoReset) {
        Write-Host "  [SKIP] Сброс БД пропущен (режим -NoReset для PROD)" -ForegroundColor DarkYellow
        return
    }
    Write-Step "Сброс БД (migrate:fresh + seed)..."
    try {
        Invoke-RestMethod -Uri "$BaseUrl/api/admin/db/reset" -Method POST `
            -ErrorAction Stop -TimeoutSec 60 | Out-Null
    } catch {}
    # Ждём возвращения сервера к жизни после долгих миграций
    for ($w = 0; $w -lt 30; $w++) {
        Start-Sleep -Seconds 2
        try {
            $s = Invoke-RestMethod -Uri "$BaseUrl/api/admin/stats" -ErrorAction Stop
            Write-Host "     БД готова: $($s.keys_available) ключей" -ForegroundColor Gray
            return
        } catch {}
    }
    Write-Host "     ОШИБКА: сервер не ответил после сброса!" -ForegroundColor Red
}

function SendWebhooks($orderId, $eventId, $count) {
    $pool = [runspacefactory]::CreateRunspacePool(1, $count); $pool.Open()
    $jobs = @()
    $url  = "$BaseUrl/api/webhook/payment"
    $body = (@{event_id=$eventId;order_id=$orderId;status="paid";amount=1290;currency="RUB"} | ConvertTo-Json)
    for ($i = 0; $i -lt $count; $i++) {
        $ps = [powershell]::Create().AddScript({
            param($u,$b)
            try { Invoke-RestMethod -Uri $u -Method POST -ContentType "application/json" -Body $b -ErrorAction SilentlyContinue | Out-Null } catch {}
        }).AddArgument($url).AddArgument($body)
        $ps.RunspacePool = $pool
        $jobs += @{Pipe=$ps; Status=$ps.BeginInvoke()}
    }
    while ($jobs.Status.IsCompleted -contains $false) { Start-Sleep -Milliseconds 50 }
    $jobs | ForEach-Object { try { $_.Pipe.EndInvoke($_.Status) } catch {} }
    $pool.Close(); $pool.Dispose()
}

# ================================================================
Write-Header "Приёмочные тесты GGSel [$Label]  ->  $BaseUrl"
# ================================================================

# Проверка доступности
Write-Step "Проверка сервера..."
try {
    $s = Invoke-RestMethod -Uri "$BaseUrl/api/admin/stats" -ErrorAction Stop
    Write-Host "     OK: всего_заказов=$($s.total) ключей=$($s.keys_available)" -ForegroundColor Green
} catch {
    Write-Host "  ОШИБКА: сервер недоступен!" -ForegroundColor Red; exit 1
}

DoReset

# ---------------------------------------------------------------
# КРИТЕРИЙ 1: 50 параллельных вебхуков -> 1 выдача
# ---------------------------------------------------------------
Write-Header "КРИТЕРИЙ #1: 50 параллельных вебхуков -> 1 выдача, 1 ключ"

Write-Step "Создаём заказ..."
$o1 = ApiPost "/api/orders" @{sku="KEY-CS2-PRIME";amount=1290;email="race@test.com"}
Write-Host "     Заказ #$($o1.id)" -ForegroundColor Gray

if (-not $o1.id) {
    Record 1 "50 параллельных вебхуков -> 1 выдача" $false "Не удалось создать заказ"
} else {
    $evt1 = "race-$(Get-Date -UFormat %s)-$(Get-Random)"
    Write-Step "Шлём 50 параллельных вебхуков (event_id=$evt1)..."
    SendWebhooks $o1.id $evt1 50
    Write-Host "     50 вебхуков отправлено" -ForegroundColor Gray
    Write-Step "Ждём обработки (до 20 сек)..."
    $f1 = WaitStatus $o1.id @("delivered","out_of_stock","delivery_failed") 20
    Write-Host "     Статус=$($f1.status) Ключ=$($f1.key_code)" -ForegroundColor Gray
    $ok1 = ($f1.status -eq "delivered") -and $f1.key_code
    Record 1 "50 параллельных вебхуков -> 1 выдача, 1 ключ" $ok1 "Статус=$($f1.status) Ключ=$($f1.key_code)"
}

# ---------------------------------------------------------------
# КРИТЕРИЙ 2: Идемпотентность вебхука
# ---------------------------------------------------------------
Write-Header "КРИТЕРИЙ #2: Повторный вебхук с тем же event_id ничего не меняет"

Write-Step "Создаём заказ..."
$o2 = ApiPost "/api/orders" @{sku="KEY-CS2-PRIME";amount=1290;email="idem@test.com"}
Write-Host "     Заказ #$($o2.id)" -ForegroundColor Gray

if (-not $o2.id) {
    Record 2 "Идемпотентность вебхука" $false "Не удалось создать заказ"
} else {
    $evt2 = "idem-$(Get-Date -UFormat %s)-$(Get-Random)"
    Write-Step "Первый вебхук..."
    $w2a = ApiPost "/api/webhook/payment" @{event_id=$evt2;order_id=$o2.id;status="paid";amount=1290;currency="RUB"}
    Write-Host "     Ответ 1: $($w2a.status)" -ForegroundColor Gray
    $st2 = WaitStatus $o2.id @("delivered","out_of_stock","delivery_failed") 15
    Write-Host "     Статус: $($st2.status) Ключ=$($st2.key_code)" -ForegroundColor Gray
    Write-Step "Повторный вебхук с ТЕМ ЖЕ event_id..."
    $w2b = ApiPost "/api/webhook/payment" @{event_id=$evt2;order_id=$o2.id;status="paid";amount=1290;currency="RUB"}
    Write-Host "     Ответ 2: $($w2b.status)" -ForegroundColor Gray
    Start-Sleep -Seconds 3
    $st2b = ApiGet "/api/orders/$($o2.id)"
    Write-Host "     Статус после повтора: $($st2b.status) Ключ=$($st2b.key_code)" -ForegroundColor Gray
    $ok2 = ($w2b.status -eq "duplicate") -and ($st2b.status -eq $st2.status)
    Record 2 "Повторный вебхук -> duplicate, статус не изменился" $ok2 "Ответ 2=$($w2b.status) Статус=$($st2b.status)"
}

# ---------------------------------------------------------------
# КРИТЕРИЙ 3: Вебхук раньше заказа
# ---------------------------------------------------------------
Write-Header "КРИТЕРИЙ #3: Вебхук пришёл раньше создания заказа"

Write-Step "Вебхук для несуществующего order_id=9999999..."
$earlyCode = 0
try {
    Invoke-RestMethod -Uri "$BaseUrl/api/webhook/payment" -Method POST `
        -ContentType "application/json" -ErrorAction Stop -TimeoutSec 10 `
        -Body (@{event_id="early-$(Get-Random)";order_id=9999999;status="paid";amount=100;currency="RUB"} | ConvertTo-Json) | Out-Null
    $earlyCode = 200
} catch {
    try { $earlyCode = $_.Exception.Response.StatusCode.value__ } catch {}
}
Write-Host "     HTTP код: $earlyCode" -ForegroundColor Gray
$ok3 = ($earlyCode -ge 500 -and $earlyCode -le 599)
Record 3 "Вебхук до заказа -> HTTP 5xx (платёжка повторит)" $ok3 "Получен HTTP $earlyCode (ожидался 503)"

# ---------------------------------------------------------------
# КРИТЕРИЙ 4: Пустой пул -> out_of_stock + retry
# ---------------------------------------------------------------
Write-Header "КРИТЕРИЙ #4: Пустой пул -> out_of_stock, безопасный retry"

DoReset

Write-Step "Удаляем все ключи из БД..."
try {
    Invoke-RestMethod -Uri "$BaseUrl/api/admin/db/empty" -Method POST -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 1
} catch { Write-Host "     Ошибка: $_" -ForegroundColor Red }
$st4 = ApiGet "/api/admin/stats"
Write-Host "     Ключей в пуле: $($st4.keys_available)" -ForegroundColor Gray

Write-Step "Создаём заказ..."
$o4 = ApiPost "/api/orders" @{sku="KEY-CS2-PRIME";amount=1290;email="oos@test.com"}
Write-Host "     Заказ #$($o4.id)" -ForegroundColor Gray

if (-not $o4.id) {
    Record "4a" "Пустой пул -> out_of_stock" $false "Не удалось создать заказ"
    Record "4b" "Retry -> delivered" $false "Нет заказа"
    Record "4c" "Retry идемпотентен" $false "Нет заказа"
} else {
    Write-Step "Оплачиваем..."
    ApiPost "/api/webhook/payment" @{event_id="oos-$(Get-Random)";order_id=$o4.id;status="paid";amount=1290;currency="RUB"} | Out-Null
    $stOos = WaitStatus $o4.id @("out_of_stock","delivered","delivery_failed") 20
    Write-Host "     Статус: $($stOos.status)" -ForegroundColor Gray
    $ok4a = ($stOos.status -eq "out_of_stock")

    Write-Step "Добавляем 60 ключей..."
    try { Invoke-RestMethod -Uri "$BaseUrl/api/admin/db/add_keys" -Method POST -ErrorAction Stop | Out-Null; Start-Sleep -Seconds 1 } catch {}
    $st4b = ApiGet "/api/admin/stats"
    Write-Host "     Ключей в пуле: $($st4b.keys_available)" -ForegroundColor Gray

    Write-Step "Retry #1 (Повторная выдача)..."
    ApiPost "/api/admin/retry/$($o4.id)" @{} | Out-Null
    $stR1 = WaitStatus $o4.id @("delivered","delivery_failed") 25
    Write-Host "     Статус после retry1: $($stR1.status) Ключ=$($stR1.key_code)" -ForegroundColor Gray

    Write-Step "Retry #2 (Проверка идемпотентности)..."
    $r2 = ApiPost "/api/admin/retry/$($o4.id)" @{}
    Write-Host "     Retry 2: уже_доставлен=$($r2.already_delivered)" -ForegroundColor Gray
    Start-Sleep -Seconds 2
    $stR2 = ApiGet "/api/orders/$($o4.id)"
    Write-Host "     Статус после retry2: $($stR2.status) Ключ=$($stR2.key_code)" -ForegroundColor Gray

    $ok4b = ($stR1.status -eq "delivered")
    $ok4c = ($stR2.key_code -eq $stR1.key_code) -and ($stR1.key_code -ne "")

    Record "4a" "Пустой пул -> out_of_stock (без падения)" $ok4a "Статус=$($stOos.status)"
    Record "4b" "После пополнения retry -> delivered" $ok4b "Статус=$($stR1.status) Ключ=$($stR1.key_code)"
    Record "4c" "Повторный retry идемпотентен (тот же ключ)" $ok4c "Ключ 1=$($stR1.key_code) | Ключ 2=$($stR2.key_code)"
}

# ---------------------------------------------------------------
# КРИТЕРИЙ 5: Промокод ONCEONLY limit=1 под параллельностью
# ---------------------------------------------------------------
Write-Header "КРИТЕРИЙ #5: Промокод ONCEONLY лимит=1 под параллельностью (10 заказов)"

DoReset

Write-Step "10 параллельных заказов с промокодом ONCEONLY..."
$pool5 = [runspacefactory]::CreateRunspacePool(1, 10); $pool5.Open()
$jobs5 = @()
$bag5  = [System.Collections.Concurrent.ConcurrentBag[int]]::new()
$url5  = "$BaseUrl/api/orders"
for ($i = 0; $i -lt 10; $i++) {
    $ps = [powershell]::Create().AddScript({
        param($url, $bag)
        try {
            $r = Invoke-RestMethod -Uri $url -Method POST -ContentType "application/json" `
                -Body '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"promo5@test.com","promo":"ONCEONLY"}' `
                -ErrorAction SilentlyContinue -TimeoutSec 15
            if ($r -and $r.discount -gt 0) { $bag.Add(1) } else { $bag.Add(0) }
        } catch { $bag.Add(0) }
    }).AddArgument($url5).AddArgument($bag5)
    $ps.RunspacePool = $pool5
    $jobs5 += @{Pipe=$ps; Status=$ps.BeginInvoke()}
}
while ($jobs5.Status.IsCompleted -contains $false) { Start-Sleep -Milliseconds 50 }
$jobs5 | ForEach-Object { try { $_.Pipe.EndInvoke($_.Status) } catch {} }
$pool5.Close(); $pool5.Dispose()

$withDiscount = ($bag5 | Where-Object {$_ -eq 1}).Count
$noDiscount   = ($bag5 | Where-Object {$_ -eq 0}).Count
Write-Host "     Со скидкой: $withDiscount | Без скидки: $noDiscount" -ForegroundColor Gray
$ok5 = ($withDiscount -eq 1)
Record 5 "ONCEONLY: ровно 1 из 10 получил скидку" $ok5 "Со скидкой=$withDiscount (ожидалось 1)"

# ================================================================
Write-Header "ИТОГИ [$Label]"
# ================================================================
foreach ($r in $Results) {
    $c = if ($r.OK) {"Green"} else {"Red"}
    $s = if ($r.OK) {"[PASS]"} else {"[FAIL]"}
    Write-Host "  $s  #$($r.ID): $($r.Name)" -ForegroundColor $c
    if ($r.Detail) { Write-Host "          $($r.Detail)" -ForegroundColor Gray }
}
Write-Host ""
$color = if ($failCount -eq 0) {"Green"} else {"Red"}
Write-Host "  PASS: $passCount  |  FAIL: $failCount" -ForegroundColor $color
if ($failCount -eq 0) { Write-Host "  *** ВСЕ КРИТЕРИИ ПРОЙДЕНЫ [$Label] ***" -ForegroundColor Green }
else                  { Write-Host "  *** ПРОВАЛЕНО: $failCount тест(ов) [$Label] ***" -ForegroundColor Red }
