<?php get_header(); ?>
<section class="site-container section">
    <?php while (have_posts()) : the_post(); ?>
        <article <?php post_class('post-card'); ?>>
            <div class="post-card__meta"><?php echo esc_html(get_the_date()); ?> • <?php echo esc_html(get_the_author()); ?></div>
            <h1 class="card__title"><?php the_title(); ?></h1>
            <div class="page-content">
                <?php the_content(); ?>
            </div>
        </article>
        <?php
        if (comments_open() || get_comments_number()) {
            comments_template();
        }
        ?>
    <?php endwhile; ?>
</section>
<?php get_footer(); ?>
