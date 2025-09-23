(function () {
  const toggle = document.querySelector('[data-nav-toggle]');
  const mobileMenu = document.querySelector('[data-mobile-menu]');

  if (!toggle || !mobileMenu) {
    return;
  }

  const body = document.body;

  toggle.addEventListener('click', function () {
    const isOpen = mobileMenu.classList.toggle('is-open');
    toggle.setAttribute('aria-expanded', isOpen);
    body.classList.toggle('has-mobile-menu-open', isOpen);
  });

  mobileMenu.addEventListener('click', function (event) {
    if (event.target.closest('a')) {
      mobileMenu.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
      body.classList.remove('has-mobile-menu-open');
    }
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && mobileMenu.classList.contains('is-open')) {
      mobileMenu.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
      body.classList.remove('has-mobile-menu-open');
    }
  });
})();
