<?php
get_header();
?>
<section class="site-container hero">
    <span class="hero__badge">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 3L20 9L12 15L4 9L12 3Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
            <path d="M4 15L12 21L20 15" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        curated commerce
    </span>
    <h1 class="hero__title">
        <?php echo esc_html(get_bloginfo('name')); ?>, neu gedacht.
        <strong>Digital, immersiv, konversionsstark.</strong>
    </h1>
    <p class="hero__lead">
        Wir kombinieren Headless Performance mit einem hochexpressiven UI. Dein Sortiment wird zum Erlebnis –
        vom Storytelling bis zum Checkout.
    </p>
    <div class="hero__actions">
        <a class="cta-button" href="<?php echo esc_url(get_permalink(get_option('woocommerce_shop_page_id'))); ?>">Shop entdecken</a>
        <a class="hero__secondary" href="#insights">
            <span>Insights erkunden</span>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M5 12H19" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M12 5L19 12L12 19" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
        </a>
    </div>
</section>

<section class="site-container section" id="insights">
    <div class="section__head">
        <h2 class="section__title">Warum Kunden sich bei dir verlieben</h2>
        <p class="section__description">Progressive Microinteractions, Storytelling-first Layouts und intelligente Produktmodule – ready to ship.</p>
    </div>
    <div class="card-grid">
        <?php
        $selling_points = [
            [
                'title'   => __('Narratives Shopping', 'myshop-modern'),
                'excerpt' => __('Hero Storytelling, modulare Content-Blocks und Produktwelten, die nach App aussehen und sich auch so anfühlen.', 'myshop-modern'),
            ],
            [
                'title'   => __('Conversion Intelligence', 'myshop-modern'),
                'excerpt' => __('Live-bestand, smarte Badges, Dynamic Bundles und Micro Copy für mehr Warenkorbabdeckung.', 'myshop-modern'),
            ],
            [
                'title'   => __('Composable Design System', 'myshop-modern'),
                'excerpt' => __('ShadCN-inspirierte Komponenten, dunkle UI, helle Typografie und vollständig anpassbare Tokens.', 'myshop-modern'),
            ],
        ];

foreach ($selling_points as $point) : ?>
            <article class="card">
                <span class="card__eyebrow"><?php esc_html_e('Feature', 'myshop-modern'); ?></span>
                <h3 class="card__title"><?php echo esc_html($point['title']); ?></h3>
                <p class="card__excerpt"><?php echo esc_html($point['excerpt']); ?></p>
            </article>
        <?php endforeach; ?>
    </div>
</section>

<?php
$products = [];
if (function_exists('wc_get_products')) {
    $products = wc_get_products([
        'status'  => 'publish',
        'limit'   => 6,
        'orderby' => 'date',
        'order'   => 'DESC',
    ]);
}

if (! empty($products)) :
    ?>
<section class="site-container section">
    <div class="section__head">
        <h2 class="section__title"><?php esc_html_e('Neu im Shop', 'myshop-modern'); ?></h2>
        <p class="section__description"><?php esc_html_e('Frisch eingetroffene Highlights – fokussiert, schnell, auf allen Devices.', 'myshop-modern'); ?></p>
    </div>
    <div class="card-grid">
        <?php foreach ($products as $product) : ?>
            <article class="card product-card">
                <div class="product-card__thumb">
                    <?php echo $product->get_image('woocommerce_single'); ?>
                </div>
                <div>
                    <span class="badge"><?php esc_html_e('Neu', 'myshop-modern'); ?></span>
                    <h3 class="card__title">
                        <a href="<?php echo esc_url($product->get_permalink()); ?>"><?php echo esc_html($product->get_name()); ?></a>
                    </h3>
                    <p class="card__excerpt"><?php echo wp_trim_words(wp_strip_all_tags($product->get_short_description() ?: $product->get_description()), 24); ?></p>
                </div>
                <div class="product-card__meta">
                    <span class="product-card__price"><?php echo wp_kses_post($product->get_price_html()); ?></span>
                    <a class="cta-button" href="<?php echo esc_url($product->add_to_cart_url()); ?>"><?php esc_html_e('In den Warenkorb', 'myshop-modern'); ?></a>
                </div>
            </article>
        <?php endforeach; ?>
    </div>
</section>
<?php else :
    // Fallback: letzte Beiträge.
    $posts = get_posts([
        'numberposts' => 3,
    ]);

    if ($posts) : ?>
    <section class="site-container section">
        <div class="section__head">
            <h2 class="section__title"><?php esc_html_e('Aktuelle Stories', 'myshop-modern'); ?></h2>
            <p class="section__description"><?php esc_html_e('Deep Dives, Launches und Behind the Scenes direkt aus deinem CMS.', 'myshop-modern'); ?></p>
        </div>
        <div class="card-grid">
            <?php foreach ($posts as $post) : setup_postdata($post); ?>
                <article class="post-card">
                    <div class="post-card__meta"><?php echo esc_html(get_the_date()); ?> • <?php echo esc_html(get_the_author()); ?></div>
                    <h3 class="card__title"><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
                    <p class="card__excerpt"><?php echo wp_trim_words(get_the_excerpt(), 24); ?></p>
                </article>
            <?php endforeach;
        wp_reset_postdata(); ?>
        </div>
    </section>
    <?php endif;
endif;
?>

<?php
get_footer();
