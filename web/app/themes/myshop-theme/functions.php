<?php

if (! defined('MYSHOP_THEME_VERSION')) {
    $theme = wp_get_theme('myshop-theme');
    define('MYSHOP_THEME_VERSION', $theme->get('Version') ?: '1.0.0');
}

add_action('after_setup_theme', function () {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('editor-styles');
    add_theme_support('woocommerce');
    add_theme_support('html5', ['search-form', 'comment-form', 'comment-list', 'gallery', 'caption']);

    register_nav_menus([
        'primary' => __('Primary Menu', 'myshop-modern'),
        'footer'  => __('Footer Menu', 'myshop-modern'),
    ]);
});

function myshop_modern_fallback_menu($args = [])
{
    $defaults = [
        'menu_class' => 'primary-menu',
        'items_wrap' => '<ul class="%2$s">%3$s</ul>',
        'echo'       => true,
    ];

    $args = wp_parse_args($args, $defaults);

    $fallback_pages = [
        'shop'           => __('Shop', 'myshop-modern'),
        'sample-page'    => __('Stories', 'myshop-modern'),
        'my-account'     => __('Account', 'myshop-modern'),
        'contact'        => __('Kontakt', 'myshop-modern'),
        'cart'           => __('Warenkorb', 'myshop-modern'),
    ];

    $links = [];
    foreach ($fallback_pages as $slug => $label) {
        $page = get_page_by_path($slug);
        if ($page) {
            $links[] = sprintf('<li class="menu-item"><a href="%s">%s</a></li>', esc_url(get_permalink($page)), esc_html($label));
        }
    }

    if (empty($links) && function_exists('wc_get_page_permalink')) {
        $links[] = sprintf('<li class="menu-item"><a href="%s">%s</a></li>', esc_url(wc_get_page_permalink('shop')), esc_html__('Shop', 'myshop-modern'));
    }

    if (empty($links)) {
        $pages = wp_list_pages([
            'title_li' => '',
            'echo'     => false,
            'depth'    => 1,
        ]);
        if ($pages) {
            $links[] = $pages;
        }
    }

    if (empty($links)) {
        return '';
    }

    $markup = sprintf($args['items_wrap'], '', esc_attr($args['menu_class']), implode('', $links));

    if (! $args['echo']) {
        return $markup;
    }

    echo $markup; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
}

add_action('wp_enqueue_scripts', function () {
    $theme_uri = get_template_directory_uri();

    wp_enqueue_style(
        'myshop-modern-fonts',
        'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Playfair+Display:wght@500;600&display=swap',
        [],
        null,
    );

    wp_enqueue_style(
        'myshop-modern-main',
        $theme_uri . '/assets/css/main.css',
        ['myshop-modern-fonts'],
        MYSHOP_THEME_VERSION,
    );

    wp_enqueue_script(
        'myshop-modern-interactions',
        $theme_uri . '/assets/js/interactions.js',
        [],
        MYSHOP_THEME_VERSION,
        true,
    );
});

add_filter('body_class', function (array $classes) {
    $classes[] = 'myshop-theme';
    return $classes;
});

add_action('widgets_init', function () {
    register_sidebar([
        'name'          => __('Footer Column 1', 'myshop-modern'),
        'id'            => 'footer-1',
        'before_widget' => '<div class="footer-widget">',
        'after_widget'  => '</div>',
        'before_title'  => '<h3 class="footer-widget__title">',
        'after_title'   => '</h3>',
    ]);

    register_sidebar([
        'name'          => __('Footer Column 2', 'myshop-modern'),
        'id'            => 'footer-2',
        'before_widget' => '<div class="footer-widget">',
        'after_widget'  => '</div>',
        'before_title'  => '<h3 class="footer-widget__title">',
        'after_title'   => '</h3>',
    ]);
});
