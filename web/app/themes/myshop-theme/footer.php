</main>
<footer class="site-footer">
    <div class="site-container footer-top">
        <div>
            <div class="branding">
                <div class="branding__mark">MS</div>
                <div>
                    <p class="branding__name"><?php bloginfo('name'); ?></p>
                    <p class="branding__tagline"><?php bloginfo('description'); ?></p>
                </div>
            </div>
            <p class="footer-intro">
                Premium Produkte, kuratierte Inhalte und eine Experience wie in deiner Lieblings-App –
                responsiv, leicht und blitzschnell.
            </p>
            <a class="cta-button" href="<?php echo esc_url(get_permalink(get_option('woocommerce_shop_page_id'))); ?>">Shop entdecken</a>
        </div>

        <div>
            <?php if (is_active_sidebar('footer-1')) : ?>
                <?php dynamic_sidebar('footer-1'); ?>
            <?php else : ?>
                <h3 class="footer-widget__title">Kontakt</h3>
                <ul class="footer-menu">
                    <li><a href="mailto:hello@myshop.dev">hello@myshop.dev</a></li>
                    <li><a href="tel:+490301234567">+49 30 123 4567</a></li>
                </ul>
            <?php endif; ?>
        </div>

        <div>
            <?php if (is_active_sidebar('footer-2')) : ?>
                <?php dynamic_sidebar('footer-2'); ?>
            <?php else : ?>
                <h3 class="footer-widget__title">Schnellzugriff</h3>
                <?php
                wp_nav_menu([
                    'theme_location' => 'footer',
                    'container'      => false,
                    'menu_class'     => 'footer-menu',
                ]);
                ?>
            <?php endif; ?>
        </div>
    </div>
    <p class="footer-note">© <?php echo date('Y'); ?> <?php bloginfo('name'); ?> · Crafted with performance & accessibility at heart.</p>
</footer>
<?php wp_footer(); ?>
</body>
</html>
