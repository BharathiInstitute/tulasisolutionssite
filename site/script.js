// Tulasi Solutions — shared site scripts
(function () {
  var whatsappButton = document.createElement('a');
  whatsappButton.className = 'whatsapp-float';
  whatsappButton.href = 'https://wa.me/919966705550?text=Hi%20Tulasi%20Solutions%2C%20I%20want%20to%20book%20a%20consultation.';
  whatsappButton.target = '_blank';
  whatsappButton.rel = 'noopener noreferrer';
  whatsappButton.setAttribute('aria-label', 'Message Tulasi Solutions on WhatsApp');
  whatsappButton.innerHTML = '<svg viewBox="0 0 448 512" aria-hidden="true" focusable="false"><path fill="currentColor" d="M380.9 97.1C339 55.1 283.2 32 223.9 32 101.5 32 1.9 131.6 1.9 254c0 39.1 10.2 77.3 29.6 111L0 480l117.7-30.9c32.4 17.7 68.9 27 106.1 27h.1c122.3 0 224.1-99.6 224.1-222 0-59.3-25.2-115-67.1-157zm-157 341.6c-33.2 0-65.7-8.9-94-25.8l-6.7-4-69.8 18.3 18.6-68-4.4-7c-18.5-29.4-28.2-63.4-28.2-98.2 0-101.7 82.8-184.5 184.6-184.5 49.3 0 95.6 19.2 130.4 54.1 34.8 34.9 56.2 81.2 56.1 130.5 0 101.8-84.9 184.6-186.6 184.6zm101.2-138.1c-5.5-2.8-32.8-16.1-37.9-18-5.1-1.9-8.8-2.8-12.5 2.8-3.7 5.6-14.3 18-17.6 21.8-3.2 3.7-6.5 4.2-12 1.4-32.6-16.3-54-29.1-75.5-66-5.7-9.8 5.7-9.1 16.3-30.3 1.8-3.7.9-6.9-.5-9.7-1.4-2.8-12.5-30.1-17.1-41.2-4.5-10.8-9.1-9.3-12.5-9.5-3.2-.2-6.9-.2-10.6-.2-3.7 0-9.7 1.4-14.8 6.9-5.1 5.6-19.4 19-19.4 46.3s19.9 53.7 22.6 57.4c2.8 3.7 39.1 59.7 94.8 83.8 35.2 15.2 49 16.5 66.6 13.9 10.7-1.6 32.8-13.4 37.4-26.4 4.6-13 4.6-24.1 3.2-26.4-1.3-2.5-5-3.9-10.5-6.6z"/></svg>';
  document.body.appendChild(whatsappButton);

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
      if (item) {
        item.classList.toggle('open');
        header.setAttribute('aria-expanded', item.classList.contains('open'));
      }
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
      if (panel) {
        panel.hidden = false;
        panel.querySelectorAll('.reveal').forEach(function (element) {
          element.classList.add('visible');
        });
      }
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
