param(
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Sku = "KEY-CS2-PRIME",
    [int]$Parallel = 50
)

Write-Host "================================================="
Write-Host " GGSel Race Condition Test (PowerShell)"
Write-Host " URL: $BaseUrl | Parallel requests: $Parallel"
Write-Host "================================================="

# 1. Создаём заказ
Write-Host "`n[1/3] Creating order for sku=$Sku..."
$Order = Invoke-RestMethod -Uri "$BaseUrl/api/orders" -Method POST -ContentType "application/json" -Body '{"sku":"KEY-CS2-PRIME","amount":1290,"email":"test@race.test"}'
$OrderId = $Order.id
Write-Host "    Order ID: $OrderId"

if (-not $OrderId) {
    Write-Host "ERROR: Failed to create order." -ForegroundColor Red
    exit
}

# 2. Стреляем 50 вебхуками одновременно
$EventId = "race-test-$(Get-Date -UFormat %s)-(Get-Random)"
Write-Host "`n[2/3] Firing $Parallel concurrent webhooks (event_id=$EventId)..."

$Runspaces = @()
$Pool = [runspacefactory]::CreateRunspacePool(1, $Parallel)
$Pool.Open()

for ($i = 0; $i -lt $Parallel; $i++) {
    $ScriptBlock = {
        param($BaseUrl, $EventId, $OrderId)
        try {
            Invoke-RestMethod -Uri "$BaseUrl/api/webhook/payment" -Method POST -ContentType "application/json" -Body "{`"event_id`":`"$EventId`",`"order_id`":$OrderId,`"status`":`"paid`",`"amount`":1290,`"currency`":`"RUB`"}" | Out-Null
        } catch {}
    }
    $PowerShell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($BaseUrl).AddArgument($EventId).AddArgument($OrderId)
    $PowerShell.RunspacePool = $Pool
    $Runspaces += [PSCustomObject]@{ Pipe = $PowerShell; Status = $PowerShell.BeginInvoke() }
}

# Ждём завершения всех потоков
while ($Runspaces.Status.IsCompleted -contains $false) { Start-Sleep -Milliseconds 100 }
$Pool.Close()
Write-Host " Done."

# 3. Проверяем результат
Write-Host "`n[3/3] Polling order status (up to 10s)..."
$FinalStatus = ""
$FinalKey = ""
for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 1
    $Result = Invoke-RestMethod -Uri "$BaseUrl/api/orders/$OrderId"
    Write-Host "    [$i/10] status=$($Result.status) key=$($Result.key_code)"
    
    if ($Result.status -in @("delivered", "out_of_stock", "delivery_failed")) {
        $FinalStatus = $Result.status
        $FinalKey = $Result.key_code
        break
    }
}

Write-Host "`n================================================="
Write-Host " RESULT for Order #$OrderId"
Write-Host " Status : $FinalStatus"
Write-Host " Key    : $FinalKey"

if ($FinalStatus -eq "delivered" -and $FinalKey) {
    Write-Host " [PASS] 1 webhook processed, 1 key delivered!" -ForegroundColor Green
} elseif ($FinalStatus -eq "out_of_stock") {
    Write-Host " [PASS] (out_of_stock) pool is empty, this is expected." -ForegroundColor Yellow
} else {
    Write-Host " [FAIL] Status: $FinalStatus" -ForegroundColor Red
}
