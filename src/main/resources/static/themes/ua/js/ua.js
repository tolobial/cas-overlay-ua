/* ============================================================
   CAS UA — Thème v1
   - Rotation cyclique des photos
     (slides générées côté serveur par Thymeleaf,
      la liste est mélangée à chaque login par UaPhotosInterceptor.java)
   - Respect de prefers-reduced-motion (pas de rotation si demandé)
   - Toggle œil pour afficher/masquer le mot de passe
   - Synchronisation du badge de pôle actif avec la slide affichée
   ============================================================ */
(function () {
  'use strict';

  // L'utilisateur a-t-il demandé "réduire les animations" dans son OS ?
  const REDUCED = window.matchMedia
    && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Durée entre deux photos (40 secondes)
  const INTERVAL_MS = 40000;

  /**
   * Met en lumière le badge du pôle correspondant à la slide active.
   * Lit l'attribut data-pole de la slide et active le .pole-badge associé.
   * Normalise la casse pour matcher "Guadeloupe" ↔ "guadeloupe".
   */
  function syncPoleBadge(slide) {
    const pole = (slide.dataset.pole || '').toLowerCase();
    if (!pole) return;

    document.querySelectorAll('.pole-badge').forEach(function (b) {
      b.classList.remove('is-active');
    });

    const badge = document.querySelector('.pole-badge[data-pole="' + pole + '"]');
    if (badge) badge.classList.add('is-active');
  }

  /**
   * Démarre la rotation d'un rotator (.rotator).
   * - Active immédiatement la première slide
   * - Cycle ensuite toutes les INTERVAL_MS millisecondes
   */
  function startRotator(rotator) {
    const slides = rotator.querySelectorAll('.slide');
    const dots = rotator.querySelectorAll('.dot');

    // Rien à faire s'il n'y a pas de slide (dossier photos vide)
    if (slides.length < 1) return;

    // Activer la première slide pour qu'elle apparaisse tout de suite
    slides[0].classList.add('active');
    if (dots[0]) dots[0].classList.add('active');
    syncPoleBadge(slides[0]);                      // ← AJOUT

    // S'il n'y a qu'une seule photo OU si l'utilisateur préfère moins
    // de mouvement, on s'arrête là.
    if (slides.length < 2 || REDUCED) return;

    // Boucle d'animation
    let current = 0;
    setInterval(function () {
      slides[current].classList.remove('active');
      if (dots[current]) dots[current].classList.remove('active');

      // Passe à la slide suivante (en boucle)
      current = (current + 1) % slides.length;

      slides[current].classList.add('active');
      if (dots[current]) dots[current].classList.add('active');
      syncPoleBadge(slides[current]);              // ← AJOUT
    }, INTERVAL_MS);
  }

  /**
   * Bascule un input password ↔ text (afficher/masquer le mot de passe).
   * Cherche l'input dans le même parent que le bouton qui a été cliqué.
   */
  function attachEyeToggle(btn) {
    btn.addEventListener('click', function () {
      const input = btn.parentElement.querySelector('input');
      if (!input) return;
      input.type = (input.type === 'password') ? 'text' : 'password';
    });
  }

  // Initialisation au chargement de la page
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.rotator').forEach(startRotator);
    document.querySelectorAll('.toggle-eye').forEach(attachEyeToggle);
  });
})();
