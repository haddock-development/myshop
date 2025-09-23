<?php

/**
 * Plugin Name: MyShop AP2 Gateway
 * Description: Exposes an AP2-compatible endpoint to ingest agent mandates and create WooCommerce orders with Stripe PaymentIntents.
 */

declare(strict_types=1);

use Stripe\StripeClient;
use WC_Order;
use WC_Order_Item_Fee;
use WC_Product;
use WP_Error;
use WP_REST_Request;
use WP_REST_Response;

use function Env\env;

if (! defined('ABSPATH')) {
    exit;
}

/**
 * Convert truthy env values to boolean.
 */
function myshop_ap2_env_bool(?string $value): bool
{
    if ($value === null) {
        return false;
    }

    return in_array(strtolower(trim($value)), ['1', 'true', 'yes', 'on', 'enabled'], true);
}

/**
 * Resolve an array key safely.
 *
 * @param array<string,mixed> $source
 * @param string              $key
 */
function myshop_ap2_array_get(array $source, string $key, $default = null)
{
    return array_key_exists($key, $source) ? $source[$key] : $default;
}

add_action('rest_api_init', static function (): void {
    register_rest_route(
        'myshop/ap2/v1',
        '/mandates',
        [
            'methods'             => 'POST',
            'callback'            => 'myshop_ap2_handle_mandate',
            'permission_callback' => 'myshop_ap2_permission_check',
            'args'                => [],
        ],
    );
});

/**
 * Guard the endpoint with a shared secret token.
 */
function myshop_ap2_permission_check(WP_REST_Request $request)
{
    $token = $request->get_header('x-ap2-token');
    $expected = env('AP2_API_TOKEN');

    if (! $expected) {
        return new WP_Error('ap2_misconfigured', 'AP2 endpoint is not configured. Missing AP2_API_TOKEN.', ['status' => 500]);
    }

    if (! myshop_ap2_env_bool(env('AP2_ENABLED'))) {
        return new WP_Error('ap2_disabled', 'AP2 endpoint disabled.', ['status' => 403]);
    }

    if (! hash_equals($expected, (string) $token)) {
        return new WP_Error('ap2_forbidden', 'Invalid AP2 token.', ['status' => 403]);
    }

    return true;
}

/**
 * Handle mandate ingestion.
 */
function myshop_ap2_handle_mandate(WP_REST_Request $request)
{
    if (! class_exists('WooCommerce')) {
        return new WP_Error('ap2_woocommerce_missing', 'WooCommerce is not available.', ['status' => 500]);
    }

    $payload = $request->get_json_params();
    if (! is_array($payload)) {
        return new WP_Error('ap2_invalid_json', 'Expected JSON body.', ['status' => 400]);
    }

    $cartMandate = myshop_ap2_array_get($payload, 'cart_mandate', []);
    if (! is_array($cartMandate)) {
        return new WP_Error('ap2_missing_cart_mandate', 'cart_mandate is required.', ['status' => 400]);
    }

    $mandateId = (string) myshop_ap2_array_get($cartMandate, 'id', '');
    if ($mandateId === '') {
        return new WP_Error('ap2_missing_mandate_id', 'cart_mandate.id is required.', ['status' => 400]);
    }

    $totalNode = myshop_ap2_array_get($cartMandate, 'total', []);
    if (! is_array($totalNode)) {
        return new WP_Error('ap2_missing_total', 'cart_mandate.total is required.', ['status' => 400]);
    }

    $amountMinor   = (int) myshop_ap2_array_get($totalNode, 'amount_minor', 0);
    $currency      = strtoupper((string) myshop_ap2_array_get($totalNode, 'currency', ''));
    $decimalPlaces = wc_get_price_decimals();

    if ($amountMinor <= 0) {
        return new WP_Error('ap2_invalid_amount', 'cart_mandate.total.amount_minor must be > 0.', ['status' => 400]);
    }

    if ($currency === '') {
        return new WP_Error('ap2_invalid_currency', 'cart_mandate.total.currency is required.', ['status' => 400]);
    }

    $storeCurrency = strtoupper(get_woocommerce_currency());

    if ($currency !== $storeCurrency) {
        return new WP_Error('ap2_currency_mismatch', sprintf('Currency mismatch. Expected %s, got %s.', $storeCurrency, $currency), ['status' => 400]);
    }

    $amountMajor = $amountMinor / (10 ** $decimalPlaces);

    $items = myshop_ap2_array_get($cartMandate, 'items', []);
    if (! is_array($items) || empty($items)) {
        return new WP_Error('ap2_missing_items', 'cart_mandate.items must contain at least one item.', ['status' => 400]);
    }

    try {
        $order = wc_create_order([
            'status' => 'pending',
        ]);
    } catch (Throwable $throwable) {
        return new WP_Error('ap2_order_failed', 'Unable to create WooCommerce order: ' . $throwable->getMessage(), ['status' => 500]);
    }

    $orderNotes = [];

    foreach ($items as $item) {
        if (! is_array($item)) {
            continue;
        }

        $name      = (string) myshop_ap2_array_get($item, 'name', 'AP2 Item');
        $quantity  = max(1, (int) myshop_ap2_array_get($item, 'quantity', 1));
        $unitMinor = (int) myshop_ap2_array_get($item, 'unit_amount_minor', 0);
        $sku       = (string) myshop_ap2_array_get($item, 'sku', '');
        $productId = (int) myshop_ap2_array_get($item, 'product_id', 0);

        $product = null;

        if ($productId > 0) {
            $product = wc_get_product($productId);
        } elseif ($sku !== '') {
            $id = wc_get_product_id_by_sku($sku);
            if ($id) {
                $product = wc_get_product($id);
            }
        }

        $lineTotal = $unitMinor * $quantity / (10 ** $decimalPlaces);

        if ($product instanceof WC_Product) {
            $order->add_product($product, $quantity, [
                'subtotal' => $lineTotal,
                'total'    => $lineTotal,
            ]);
        } else {
            $fee = new WC_Order_Item_Fee();
            $fee->set_name($name);
            $fee->set_amount($lineTotal);
            $fee->set_total($lineTotal);
            $order->add_item($fee);
        }

        $orderNotes[] = sprintf('%s x %d (%.2f %s)', $name, $quantity, $lineTotal, $currency);
    }

    $order->set_currency($currency);
    $order->set_customer_ip_address($request->get_param('ip_address') ?: $request->get_header('x-forwarded-for'));
    $order->update_meta_data('_ap2_mandate_id', $mandateId);

    $additionalMeta = myshop_ap2_array_get($payload, 'metadata', []);
    if (is_array($additionalMeta)) {
        $order->update_meta_data('_ap2_metadata', wp_json_encode($additionalMeta));
    }

    $order->add_order_note('AP2 mandate processed: ' . implode('; ', $orderNotes));
    $order->calculate_totals();

    $calculatedMinor = (int) round($order->get_total() * (10 ** $decimalPlaces));
    if ($calculatedMinor !== $amountMinor) {
        // Force total to match mandate amount to avoid rounding drift.
        $order->set_total($amountMajor);
        $order->calculate_totals(false);
    }

    try {
        $paymentIntent = myshop_ap2_create_payment_intent($order, $amountMinor, strtolower($currency), $mandateId);
        $order->update_meta_data('_stripe_payment_intent', $paymentIntent['id']);
        $order->update_status('on-hold', 'Awaiting Stripe PaymentIntent confirmation (AP2).');
    } catch (Throwable $throwable) {
        $order->update_status('failed', 'Failed to create Stripe PaymentIntent: ' . $throwable->getMessage());

        return new WP_Error('ap2_stripe_error', 'Stripe error: ' . $throwable->getMessage(), ['status' => 500]);
    }

    $order->save();

    $response = [
        'order_id'        => $order->get_id(),
        'order_key'       => $order->get_order_key(),
        'mandate_id'      => $mandateId,
        'payment_intent'  => $paymentIntent['id'],
        'client_secret'   => $paymentIntent['client_secret'] ?? null,
        'status'          => 'created',
        'currency'        => $currency,
        'amount_minor'    => $amountMinor,
        'amount_major'    => $amountMajor,
    ];

    return new WP_REST_Response($response, 201);
}

/**
 * Create a Stripe PaymentIntent for the order.
 *
 * @param WC_Order $order
 * @param int      $amountMinor
 */
function myshop_ap2_create_payment_intent(WC_Order $order, int $amountMinor, string $currency, string $mandateId): array
{
    $useTestMode = myshop_ap2_env_bool(env('STRIPE_TESTMODE'));
    $secretKey   = $useTestMode ? env('STRIPE_TEST_SECRET_KEY') : env('STRIPE_LIVE_SECRET_KEY');

    if (! $secretKey) {
        throw new RuntimeException('Stripe secret key not configured.');
    }

    if (! class_exists(StripeClient::class)) {
        throw new RuntimeException('Stripe PHP SDK not available.');
    }

    $stripe = new StripeClient($secretKey);

    $metadata = [
        'order_id'    => (string) $order->get_id(),
        'mandate_id'  => $mandateId,
        'environment' => $useTestMode ? 'test' : 'live',
    ];

    $description = sprintf('MyShop Order #%d (AP2)', $order->get_id());

    $intent = $stripe->paymentIntents->create([
        'amount'               => $amountMinor,
        'currency'             => $currency,
        'confirmation_method'  => 'automatic',
        'confirm'              => false,
        'description'          => $description,
        'metadata'             => $metadata,
        'statement_descriptor' => env('AP2_STATEMENT_DESCRIPTOR') ?: 'MYSHOP AP2',
    ]);

    return $intent->toArray();
}
