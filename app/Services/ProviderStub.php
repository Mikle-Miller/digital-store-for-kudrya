<?php

namespace App\Services;

use App\Models\ProviderRequest;
use Illuminate\Support\Facades\Log;

/**
 * ProviderStub — заглушка внешнего поставщика ключей.
 *
 * Моделирует два провайдера (A и B) с настраиваемыми error_rate/timeout_rate.
 * Идемпотентность: повторный вызов с тем же request_id вернёт тот же ответ.
 *
 * В реальной системе — HTTP-клиент к API провайдера.
 */
class ProviderStub
{
    private array $config = [
        'A' => ['error_rate' => 0.15, 'timeout_rate' => 0.05],
        'B' => ['error_rate' => 0.05, 'timeout_rate' => 0.02],
    ];

    /**
     * @param  string $provider   'A' | 'B'
     * @param  string $requestId  Уникальный ID попытки (req_{orderId}-{attempt})
     * @param  string $sku        SKU товара
     * @return array{status: string, key_code: ?string, cached: bool}
     */
    public function request(string $provider, string $requestId, string $sku): array
    {
        // Идемпотентность: если уже запрашивали — вернуть кэш из БД
        $existing = ProviderRequest::find($requestId);
        if ($existing) {
            Log::info("ProviderStub [{$provider}] cache hit for {$requestId}");
            return [
                'status'   => $existing->status,
                'key_code' => $existing->key_code,
                'cached'   => true,
            ];
        }

        // Сохраняем pending сразу (чтобы при параллельных повторах был кэш)
        ProviderRequest::create([
            'request_id' => $requestId,
            'order_id'   => (int) explode('-', str_replace('req_', '', $requestId))[0],
            'provider'   => $provider,
            'status'     => ProviderRequest::STATUS_PENDING,
        ]);

        // Симулируем работу провайдера
        $result = $this->simulate($provider, $sku);

        // Обновляем запись с результатом
        ProviderRequest::where('request_id', $requestId)->update([
            'status'   => $result['status'],
            'key_code' => $result['key_code'] ?? null,
        ]);

        return array_merge($result, ['cached' => false]);
    }

    private function simulate(string $provider, string $sku): array
    {
        $cfg = $this->config[$provider] ?? $this->config['A'];
        $rand = mt_rand() / mt_getrandmax();

        if ($rand < $cfg['timeout_rate']) {
            Log::warning("ProviderStub [{$provider}] TIMEOUT for sku={$sku}");
            return ['status' => ProviderRequest::STATUS_TIMEOUT, 'key_code' => null];
        }

        if ($rand < $cfg['error_rate']) {
            Log::warning("ProviderStub [{$provider}] ERROR for sku={$sku}");
            return ['status' => ProviderRequest::STATUS_ERROR, 'key_code' => null];
        }

        // Успех — провайдер подтвердил доставку
        Log::info("ProviderStub [{$provider}] OK for sku={$sku}");
        return ['status' => ProviderRequest::STATUS_OK, 'key_code' => null];
    }
}
