<?php get_header(); ?>
<section class="site-container section">
    <div class="section__head">
        <h1 class="section__title"><?php echo esc_html(get_the_archive_title() ?: __('Stories', 'myshop-modern')); ?></h1>
        <?php if ($desc = get_the_archive_description()) : ?>
            <p class="section__description"><?php echo wp_kses_post($desc); ?></p>
        <?php endif; ?>
    </div>

    <?php if (have_posts()) : ?>
        <div class="card-grid">
            <?php while (have_posts()) : the_post(); ?>
                <article <?php post_class('post-card'); ?>>
                    <div class="post-card__meta"><?php echo esc_html(get_the_date()); ?> • <?php echo esc_html(get_the_author()); ?></div>
                    <h2 class="card__title"><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2>
                    <p class="card__excerpt"><?php echo wp_trim_words(get_the_excerpt(), 30); ?></p>
                    <a class="hero__secondary" href="<?php the_permalink(); ?>"><?php esc_html_e('Weiterlesen', 'myshop-modern'); ?></a>
                </article>
            <?php endwhile; ?>
        </div>
        <?php the_posts_pagination(['mid_size' => 2]); ?>
    <?php else : ?>
        <p><?php esc_html_e('Noch keine Inhalte verfügbar – starte mit deinem ersten Beitrag!', 'myshop-modern'); ?></p>
    <?php endif; ?>
</section>
<?php get_footer(); ?>
