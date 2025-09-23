<?php

/**
 * Plugin Name: MyShop Payment Configuration
 * Description: Synchronises Stripe Gateway Einstellungen aus Environment-Variablen und aktiviert Google Pay via Payment Request Buttons.
 */

declare(strict_types=1);

use function Env\env;

if (! defined('ABSPATH')) {
    exit;
}

if (! function_exists('myshop_env_to_yesno')) {
    function myshop_env_to_yesno($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = strtolower(trim((string) $value));
        if ($normalized === '') {
            return null;
        }

        $truthy = ['1', 'true', 'yes', 'on', 'enabled', 'enable'];
        $falsy  = ['0', 'false', 'no', 'off', 'disabled', 'disable'];

        if (in_array($normalized, $truthy, true)) {
            return 'yes';
        }

        if (in_array($normalized, $falsy, true)) {
            return 'no';
        }

        return null;
    }
}

if (! function_exists('myshop_apply_env_setting')) {
    /**
     * Apply an environment value to the Stripe settings array.
     */
    function myshop_apply_env_setting(array &$settings, string $optionKey, string $envKey, ?callable $transform = null, ?array $allowedValues = null): bool
    {
        $value = env($envKey);
        if ($value === null || $value === '') {
            return false;
        }

        if ($transform) {
            $value = $transform($value);
            if ($value === null) {
                return false;
            }
        }

        if ($allowedValues !== null) {
            $value = strtolower((string) $value);
            if (! in_array($value, $allowedValues, true)) {
                return false;
            }
        }

        $current = $settings[$optionKey] ?? null;
        if ($current === $value) {
            return false;
        }

        $settings[$optionKey] = $value;
        return true;
    }
}

add_action('init', static function (): void {
    if (! function_exists('get_option') || ! function_exists('update_option')) {
        return;
    }

    if (! function_exists('WC')) {
        // WooCommerce ist nicht aktiv.
        return;
    }

    $settings = get_option('woocommerce_stripe_settings', []);
    if (! is_array($settings)) {
        $settings = [];
    }

    $dirty = false;

    $dirty = myshop_apply_env_setting($settings, 'enabled', 'STRIPE_ENABLED', 'myshop_env_to_yesno') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'testmode', 'STRIPE_TESTMODE', 'myshop_env_to_yesno') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'test_publishable_key', 'STRIPE_TEST_PUBLISHABLE_KEY') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'test_secret_key', 'STRIPE_TEST_SECRET_KEY') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'publishable_key', 'STRIPE_LIVE_PUBLISHABLE_KEY') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'secret_key', 'STRIPE_LIVE_SECRET_KEY') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'test_webhook_secret', 'STRIPE_TEST_WEBHOOK_SECRET') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'webhook_secret', 'STRIPE_WEBHOOK_SECRET') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'payment_request', 'STRIPE_ENABLE_GOOGLE_PAY', 'myshop_env_to_yesno') || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'payment_request_button_type', 'STRIPE_PAYMENT_REQUEST_BUTTON_TYPE', null, ['default', 'buy', 'donate', 'branded', 'custom']) || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'payment_request_button_theme', 'STRIPE_PAYMENT_REQUEST_BUTTON_THEME', null, ['dark', 'light', 'light-outline']) || $dirty;
    $dirty = myshop_apply_env_setting($settings, 'payment_request_button_label', 'STRIPE_PAYMENT_REQUEST_BUTTON_LABEL') || $dirty;

    if ($dirty) {
        update_option('woocommerce_stripe_settings', $settings);
    }
}, 20);
