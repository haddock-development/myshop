<?php
if (post_password_required()) {
    return;
}
?>
<section id="comments" class="site-container section">
    <?php if (have_comments()) : ?>
        <h2 class="section__title"><?php printf(_nx('Ein Kommentar', '%1$s Kommentare', get_comments_number(), 'comments title', 'myshop-modern'), number_format_i18n(get_comments_number())); ?></h2>
        <ol class="comment-list">
            <?php
            wp_list_comments([
                'style'      => 'ol',
                'short_ping' => true,
            ]);
        ?>
        </ol>
        <?php the_comments_pagination(); ?>
    <?php endif; ?>

    <?php if (! comments_open()) : ?>
        <p class="card__excerpt"><?php esc_html_e('Die Kommentarfunktion ist deaktiviert.', 'myshop-modern'); ?></p>
    <?php endif; ?>

    <?php comment_form([
        'class_submit' => 'cta-button',
        'comment_field' => '<p class="comment-form-comment"><label for="comment">' . __('Kommentar', 'myshop-modern') . '</label><textarea id="comment" name="comment" cols="45" rows="6" required></textarea></p>',
    ]); ?>
</section>
