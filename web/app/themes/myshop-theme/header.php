<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script>
        (function () {
            try {
                var storageKey = 'myshop-theme';
                var stored = localStorage.getItem(storageKey);
                var mediaQuery = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
                var prefersDark = mediaQuery ? mediaQuery.matches : false;
                var theme = stored || (prefersDark ? 'dark' : 'light');
                document.documentElement.dataset.theme = theme;
            } catch (error) {
                // Ignore storage access issues (e.g. private mode).
            }
        })();
    </script>
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<header class="top-bar">
    <div class="site-container navigation">
        <div class="branding">
            <a class="branding__mark" href="<?php echo esc_url(home_url('/')); ?>">MS</a>
            <div>
                <p class="branding__name"><?php bloginfo('name'); ?></p>
                <p class="branding__tagline"><?php bloginfo('description'); ?></p>
            </div>
        </div>

        <?php
        $desktop_menu = '';
if (has_nav_menu('primary')) {
    $desktop_menu = wp_nav_menu([
        'theme_location' => 'primary',
        'container'      => false,
        'menu_class'     => 'primary-menu',
        'echo'           => false,
    ]);
} else {
    $desktop_menu = myshop_modern_fallback_menu([
        'menu_class' => 'primary-menu',
        'echo'       => false,
    ]);
}

echo $desktop_menu ? '<nav class="primary-nav" aria-label="Primary">' . $desktop_menu . '</nav>' : '';

$account_url = function_exists('wc_get_page_permalink') ? wc_get_page_permalink('myaccount') : wp_login_url();
$cart_url    = function_exists('wc_get_cart_url') ? wc_get_cart_url() : '#';
$cart_count  = function_exists('WC') && WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
?>

        <div class="nav-actions">
            <a class="nav-actions__link" href="<?php echo esc_url($account_url); ?>">
                <span class="nav-actions__icon" aria-hidden="true">👤</span>
                <span><?php esc_html_e('Account', 'myshop-modern'); ?></span>
            </a>
            <a class="nav-actions__link nav-actions__cart" href="<?php echo esc_url($cart_url); ?>">
                <span class="nav-actions__icon" aria-hidden="true">🛒</span>
                <span><?php esc_html_e('Cart', 'myshop-modern'); ?></span>
                <?php if ($cart_count) : ?>
                    <span class="nav-actions__badge"><?php echo (int) $cart_count; ?></span>
                <?php endif; ?>
            </a>
            <button
                class="theme-toggle"
                type="button"
                data-theme-toggle
                aria-pressed="false"
                aria-label="<?php esc_attr_e('Switch to dark mode', 'myshop-modern'); ?>"
                data-label-dark="<?php esc_attr_e('Switch to dark mode', 'myshop-modern'); ?>"
                data-label-light="<?php esc_attr_e('Switch to light mode', 'myshop-modern'); ?>"
                data-text-dark="<?php esc_attr_e('Dark', 'myshop-modern'); ?>"
                data-text-light="<?php esc_attr_e('Light', 'myshop-modern'); ?>"
            >
                <span class="theme-toggle__icon theme-toggle__icon--sun" aria-hidden="true">☀️</span>
                <span class="theme-toggle__icon theme-toggle__icon--moon" aria-hidden="true">🌙</span>
                <span class="theme-toggle__text"><?php esc_html_e('Theme', 'myshop-modern'); ?></span>
            </button>
            <button class="nav-toggle" data-nav-toggle aria-label="Toggle navigation" aria-expanded="false">
                <span>Menü</span>
            </button>
        </div>
    </div>

    <div class="mobile-nav" data-mobile-menu>
        <?php
if ($desktop_menu) {
    echo str_replace('primary-menu', 'mobile-menu', $desktop_menu); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
}
?>
        <div class="mobile-nav__actions">
            <a class="mobile-nav__link" href="<?php echo esc_url($account_url); ?>"><?php esc_html_e('Account', 'myshop-modern'); ?></a>
            <a class="mobile-nav__link" href="<?php echo esc_url($cart_url); ?>"><?php esc_html_e('Warenkorb', 'myshop-modern'); ?></a>
            <button
                class="theme-toggle"
                type="button"
                data-theme-toggle
                aria-pressed="false"
                aria-label="<?php esc_attr_e('Switch to dark mode', 'myshop-modern'); ?>"
                data-label-dark="<?php esc_attr_e('Switch to dark mode', 'myshop-modern'); ?>"
                data-label-light="<?php esc_attr_e('Switch to light mode', 'myshop-modern'); ?>"
                data-text-dark="<?php esc_attr_e('Dark', 'myshop-modern'); ?>"
                data-text-light="<?php esc_attr_e('Light', 'myshop-modern'); ?>"
            >
                <span class="theme-toggle__icon theme-toggle__icon--sun" aria-hidden="true">☀️</span>
                <span class="theme-toggle__icon theme-toggle__icon--moon" aria-hidden="true">🌙</span>
                <span class="theme-toggle__text"><?php esc_html_e('Theme', 'myshop-modern'); ?></span>
            </button>
        </div>
    </div>
</header>
<main>
