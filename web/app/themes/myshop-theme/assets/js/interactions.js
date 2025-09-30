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

(function () {
  const storageKey = 'myshop-theme';
  const root = document.documentElement;
  const toggles = document.querySelectorAll('[data-theme-toggle]');

  if (!toggles.length) {
    return;
  }

  const updateButton = (button, theme) => {
    button.dataset.theme = theme;
    button.setAttribute('aria-pressed', theme === 'dark' ? 'true' : 'false');

    const labelAttr = theme === 'dark' ? 'data-label-light' : 'data-label-dark';
    const nextLabel = button.getAttribute(labelAttr);
    if (nextLabel) {
      button.setAttribute('aria-label', nextLabel);
    }

    const textAttr = theme === 'dark' ? 'data-text-dark' : 'data-text-light';
    const nextText = button.getAttribute(textAttr);
    const textNode = button.querySelector('.theme-toggle__text');
    if (nextText && textNode) {
      textNode.textContent = nextText;
    }
  };

  const applyTheme = (theme, persist = true) => {
    root.dataset.theme = theme;

    if (persist) {
      try {
        localStorage.setItem(storageKey, theme);
      } catch (error) {
        // Ignore write errors (e.g. private browsing).
      }
    }

    toggles.forEach((button) => updateButton(button, theme));
  };

  const getStoredTheme = () => {
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored === 'light' || stored === 'dark') {
        return stored;
      }
    } catch (error) {
      // Ignore read errors (e.g. disabled storage).
    }

    return null;
  };

  const initialTheme = getStoredTheme() || (root.dataset.theme === 'dark' ? 'dark' : 'light');
  applyTheme(initialTheme, false);

  toggles.forEach((button) => {
    button.addEventListener('click', () => {
      const newTheme = root.dataset.theme === 'dark' ? 'light' : 'dark';
      applyTheme(newTheme);
    });
  });

  const mediaQuery = typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  if (mediaQuery) {
    const handleMediaChange = (event) => {
      if (getStoredTheme()) {
        return;
      }

      applyTheme(event.matches ? 'dark' : 'light', false);
    };

    if (typeof mediaQuery.addEventListener === 'function') {
      mediaQuery.addEventListener('change', handleMediaChange);
    } else if (typeof mediaQuery.addListener === 'function') {
      mediaQuery.addListener(handleMediaChange);
    }
  }
})();
