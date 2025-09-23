<?php get_header(); ?>
<section class="site-container section">
    <article class="post-card">
        <span class="badge"><?php esc_html_e('404', 'myshop-modern'); ?></span>
        <h1 class="card__title"><?php esc_html_e('Seite nicht gefunden', 'myshop-modern'); ?></h1>
        <p class="card__excerpt"><?php esc_html_e('Vielleicht suchst du nach einem Produkt oder einem Beitrag, der verschoben wurde. Nutze die Suche oder springe zurück auf die Startseite.', 'myshop-modern'); ?></p>
        <a class="cta-button" href="<?php echo esc_url(home_url('/')); ?>"><?php esc_html_e('Zurück zur Startseite', 'myshop-modern'); ?></a>
    </article>
</section>
<?php get_footer(); ?>
