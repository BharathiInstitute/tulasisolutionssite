// Tulasi Solutions — shared site scripts
(function () {
  // Mobile nav toggle
  var toggle = document.querySelector('.nav-toggle');
  var links = document.querySelector('.nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function () {
      links.classList.toggle('open');
      toggle.setAttribute('aria-expanded', links.classList.contains('open'));
    });
  }

  // Accordion
  document.querySelectorAll('.accordion-header').forEach(function (header) {
    header.addEventListener('click', function () {
      var item = header.closest('.accordion-item');
      if (item) item.classList.toggle('open');
    });
  });

  // Fade-in on scroll
  var revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && revealEls.length) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });
    revealEls.forEach(function (el) { observer.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('visible'); });
  }

  // Pricing tab switching
  document.querySelectorAll('.tab-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var tabId = btn.dataset.tab;
      document.querySelectorAll('.tab-btn').forEach(function (b) {
        b.classList.remove('active');
        b.setAttribute('aria-selected', 'false');
      });
      document.querySelectorAll('.tab-panel').forEach(function (p) {
        p.hidden = true;
      });
      btn.classList.add('active');
      btn.setAttribute('aria-selected', 'true');
      var panel = document.getElementById('tab-' + tabId);
      if (panel) panel.hidden = false;
      window.scrollTo({ top: btn.closest('.pricing-tabs').getBoundingClientRect().top + window.scrollY - 80, behavior: 'smooth' });
    });
  });

  // Submit website enquiries to the Sales leads panel.
  document.querySelectorAll('form[data-lead-form]').forEach(function (form) {
    form.noValidate = true;

    function clearFieldError(field) {
      if (!field) return;
      field.removeAttribute('aria-invalid');
      field.removeAttribute('aria-describedby');
      var error = form.querySelector('#' + field.id + '-error');
      if (error) error.remove();
    }

    function showFieldError(name, message) {
      var field = form.elements.namedItem(name);
      if (!field || !field.id) return;
      clearFieldError(field);
      var error = document.createElement('span');
      error.id = field.id + '-error';
      error.className = 'field-error';
      error.textContent = message;
      field.setAttribute('aria-invalid', 'true');
      field.setAttribute('aria-describedby', error.id);
      field.insertAdjacentElement('afterend', error);
    }

    function validate(payload) {
      var errors = {};
      if (!String(payload.name || '').trim()) errors.name = 'Please enter your name.';
      if (!String(payload.business || '').trim()) errors.business = 'Please enter your business name.';
      if (!String(payload.category || '').trim()) errors.category = 'Please select a business category.';

      var phone = String(payload.phone || '').trim();
      if (!phone) {
        errors.phone = 'Please enter your phone or WhatsApp number.';
      } else if (phone.replace(/\D/g, '').length < 10) {
        errors.phone = 'Please enter a phone number with at least 10 digits.';
      }

      var email = String(payload.email || '').trim();
      if (!email) {
        errors.email = 'Please enter your email address.';
      } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        errors.email = 'Please enter a valid email address.';
      }
      if (!String(payload.message || '').trim()) errors.message = 'Please enter a message.';
      return errors;
    }

    form.querySelectorAll('input, select, textarea').forEach(function (field) {
      field.addEventListener(field.tagName === 'SELECT' ? 'change' : 'input', function () {
        clearFieldError(field);
      });
    });

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      var note = form.querySelector('.form-note');
      var button = form.querySelector('button[type="submit"]');
      var originalLabel = button ? button.textContent : '';
      var payload = Object.fromEntries(new FormData(form).entries());
      var fieldErrors = validate(payload);

      if (note) note.hidden = true;
      form.querySelectorAll('[aria-invalid="true"]').forEach(clearFieldError);

      if (Object.keys(fieldErrors).length) {
        Object.keys(fieldErrors).forEach(function (name) {
          showFieldError(name, fieldErrors[name]);
        });
        var firstInvalidField = form.querySelector('[aria-invalid="true"]');
        if (firstInvalidField) firstInvalidField.focus();
        return;
      }

      if (button) {
        button.disabled = true;
        button.textContent = 'Sending...';
      }

      try {
        var response = await fetch(form.dataset.endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        var result = await response.json().catch(function () { return {}; });
        if (!response.ok) {
          if (result.fieldErrors) {
            Object.keys(result.fieldErrors).forEach(function (name) {
              showFieldError(name, result.fieldErrors[name]);
            });
            var firstServerInvalidField = form.querySelector('[aria-invalid="true"]');
            if (firstServerInvalidField) firstServerInvalidField.focus();
          }
          throw new Error(result.error || 'Could not send your message.');
        }

        if (note) {
          note.classList.remove('form-note-error');
          note.textContent = 'Thank you! Your details were received. We will contact you shortly.';
          note.hidden = false;
        }
        form.reset();
      } catch (error) {
        if (note) {
          note.classList.add('form-note-error');
          note.textContent = error.message || 'Could not send your message. Please try again.';
          note.hidden = false;
        }
      } finally {
        if (button) {
          button.disabled = false;
          button.textContent = originalLabel;
        }
      }
    });
  });
})();
