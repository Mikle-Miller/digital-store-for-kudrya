<?php

namespace Database\Seeders;

use App\Models\ProductKey;
use App\Models\Promocode;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ===================== КЛЮЧИ ИЗ ЗАДАНИЯ =====================
        // 50 тестовых ключей, распределены по SKU
        $keys = [
            // CS2 — 10 ключей
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'LFXC-TNCS-BPCD'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'P3EI-W8UO-9B4K'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'FEL3-GUXN-TCCH'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'YPLV-QK2Z-IUS5'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => '0K9E-P1FR-BY1U'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => '5LZV-UQ48-RXCZ'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'X93K-NYAQ-GEC1'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'EIO5-CQT5-35KO'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'M58F-GIIR-VJAP'],
            ['sku' => 'KEY-CS2-PRIME', 'key_code' => 'NU8Y-SWYB-6252'],
            // GTA V — 8 ключей
            ['sku' => 'KEY-GTA5', 'key_code' => 'OODW-CCHF-MBAF'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'DNA5-WFJM-NE49'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'QRDD-MJ3F-A8TF'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'TAT9-5ZJN-G1T2'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'LI39-4330-ISMB'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'BKJY-8Q79-8NHI'],
            ['sku' => 'KEY-GTA5', 'key_code' => 'HHW6-4RX2-DX62'],
            ['sku' => 'KEY-GTA5', 'key_code' => '1RG2-L28O-O80G'],
            // EFT — 6 ключей
            ['sku' => 'KEY-EFT', 'key_code' => 'EF63-F39X-MTEA'],
            ['sku' => 'KEY-EFT', 'key_code' => '8XS7-P53H-JKIV'],
            ['sku' => 'KEY-EFT', 'key_code' => 'JPE6-MQV6-P7ST'],
            ['sku' => 'KEY-EFT', 'key_code' => 'SAPG-A2GR-0ULS'],
            ['sku' => 'KEY-EFT', 'key_code' => 'T2DU-IJ1S-U16P'],
            ['sku' => 'KEY-EFT', 'key_code' => 'WSSY-QTR7-Z57J'],
            // Steam 500 — 4 ключа
            ['sku' => 'STEAM-TOPUP-500', 'key_code' => 'U74E-EPCI-CY26'],
            ['sku' => 'STEAM-TOPUP-500', 'key_code' => 'FZXF-58H8-OR93'],
            ['sku' => 'STEAM-TOPUP-500', 'key_code' => 'FPSM-HLZA-TPAL'],
            ['sku' => 'STEAM-TOPUP-500', 'key_code' => 'WSC9-28DJ-B2JE'],
            // Steam 1000 — 4 ключа
            ['sku' => 'STEAM-TOPUP-1000', 'key_code' => 'P63J-F7UZ-DCYP'],
            ['sku' => 'STEAM-TOPUP-1000', 'key_code' => 'C7W2-D4C5-QMT7'],
            ['sku' => 'STEAM-TOPUP-1000', 'key_code' => 'JESI-DFBH-LK1K'],
            ['sku' => 'STEAM-TOPUP-1000', 'key_code' => 'SGMA-JA0T-GR7D'],
            // Steam 2500 — 4 ключа
            ['sku' => 'STEAM-TOPUP-2500', 'key_code' => '3PR4-OSY9-M3ZW'],
            ['sku' => 'STEAM-TOPUP-2500', 'key_code' => 'OMBE-C0JF-D45Y'],
            ['sku' => 'STEAM-TOPUP-2500', 'key_code' => 'KIKQ-FQJ8-9TI8'],
            ['sku' => 'STEAM-TOPUP-2500', 'key_code' => 'LMAN-RSHS-AJDO'],
            // Discord — 4 ключа
            ['sku' => 'SUB-DISCORD-1M', 'key_code' => 'BAKI-VT1X-Z5OL'],
            ['sku' => 'SUB-DISCORD-1M', 'key_code' => '9F0X-B46W-03FS'],
            ['sku' => 'SUB-DISCORD-1M', 'key_code' => 'S423-V6YY-IBEM'],
            ['sku' => 'SUB-DISCORD-1M', 'key_code' => 'D4UW-WYRA-20ST'],
            // YouTube — 4 ключа
            ['sku' => 'SUB-YT-3M', 'key_code' => 'XC0J-CJ0H-09RN'],
            ['sku' => 'SUB-YT-3M', 'key_code' => 'RY1W-XCFJ-0KUA'],
            ['sku' => 'SUB-YT-3M', 'key_code' => 'CJYY-YKSQ-QE6H'],
            ['sku' => 'SUB-YT-3M', 'key_code' => '97AQ-38QJ-H8HU'],
            // Spotify — 2 ключа
            ['sku' => 'SUB-SPOTIFY-1M', 'key_code' => 'FS8E-3S5Z-I6RA'],
            ['sku' => 'SUB-SPOTIFY-1M', 'key_code' => 'ARQK-FML4-A14E'],
            // PSN — 2 ключа
            ['sku' => 'GIFT-PSN-1000', 'key_code' => '7Z6K-NO9V-MPJB'],
            ['sku' => 'GIFT-PSN-1000', 'key_code' => 'D4K7-IJSG-N853'],
            // Xbox — 2 ключа
            ['sku' => 'GIFT-XBOX-1500', 'key_code' => 'W67T-ZB0Q-1XKB'],
            ['sku' => 'GIFT-XBOX-1500', 'key_code' => '7EQM-K09J-XKUO'],
            // Roblox — 2 ключа
            ['sku' => 'GIFT-ROBLOX-800', 'key_code' => 'LMAN-RSHS-AJDO'],
            ['sku' => 'GIFT-ROBLOX-800', 'key_code' => 'BAKI-VT1X-Z5OL'],
        ];

        foreach ($keys as $key) {
            ProductKey::firstOrCreate(
                ['key_code' => $key['key_code']],
                ['sku' => $key['sku'], 'status' => 'available']
            );
        }

        // ===================== ПРОМОКОДЫ ИЗ ЗАДАНИЯ =====================
        $promocodes = [
            ['code' => 'WELCOME10', 'type' => 'percent', 'value' => 10,  'currency' => null,  'max_uses' => 100],
            ['code' => 'GG500',     'type' => 'amount',  'value' => 500, 'currency' => 'RUB', 'max_uses' => 20],
            ['code' => 'LIMIT3',    'type' => 'percent', 'value' => 25,  'currency' => null,  'max_uses' => 3],
            ['code' => 'ONCEONLY',  'type' => 'percent', 'value' => 50,  'currency' => null,  'max_uses' => 1],
        ];

        foreach ($promocodes as $promo) {
            Promocode::firstOrCreate(
                ['code' => $promo['code']],
                array_merge($promo, ['used' => 0])
            );
        }

        // Опциональная цепочка: command может быть null при вызове через HTTP (AdminController)
        $this->command?->info('✅ Seeded: 50 keys, 4 promocodes');
    }
}
