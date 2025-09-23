<?php get_header(); ?>
<section class="site-container section">
    <?php while (have_posts()) : the_post(); ?>
        <article <?php post_class('post-card'); ?>>
            <h1 class="card__title"><?php the_title(); ?></h1>
            <div class="page-content">
                <?php the_content(); ?>
            </div>
        </article>
    <?php endwhile; ?>
</section>
<?php get_footer(); ?>
