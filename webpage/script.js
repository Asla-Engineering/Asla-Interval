(function () {
  'use strict';

  var root = document.documentElement;
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ---------- Appearance: System → Light → Dark ---------- */
  var toggle = document.getElementById('theme-toggle');
  var modes = ['system', 'light', 'dark'];
  var labels = { system: 'System', light: 'Light', dark: 'Dark' };

  function currentMode() {
    return root.dataset.theme === 'light' || root.dataset.theme === 'dark' ? root.dataset.theme : 'system';
  }
  function applyMode(mode) {
    if (mode === 'system') delete root.dataset.theme; else root.dataset.theme = mode;
    try {
      if (mode === 'system') localStorage.removeItem('theme'); else localStorage.setItem('theme', mode);
    } catch (e) { /* storage unavailable – appearance still works for this visit */ }
    if (toggle) {
      toggle.dataset.mode = mode;
      toggle.setAttribute('aria-label', 'Appearance: ' + labels[mode] + '. Tap to change.');
    }
  }
  if (toggle) {
    applyMode(currentMode());
    toggle.addEventListener('click', function () {
      var next = modes[(modes.indexOf(currentMode()) + 1) % modes.length];
      applyMode(next);
    });
  }

  /* ---------- Footer year ---------- */
  var year = document.getElementById('year');
  if (year) year.textContent = String(new Date().getFullYear());

  /* ---------- Reveal on scroll ---------- */
  var reveals = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('is-visible'); });
  }

  /* ---------- Open a FAQ group from a topic link ---------- */
  function openFromHash() {
    var id = location.hash.slice(1);
    if (!id) return;
    var target = document.getElementById(id);
    if (target && target.classList.contains('faq-group')) {
      var first = target.querySelector('details');
      if (first) first.open = true;
    }
  }
  window.addEventListener('hashchange', openFromHash);
  openFromHash();

  /* ---------- Live workout preview (mirrors the app) ---------- */
  var hero = document.getElementById('hero');
  if (!hero) return;

  // Same values as WorkoutColor.swift: active (work) and dimmed (get ready / rest).
  var COLORS = {
    green: { active: ['#00e25b', '#000'], dimmed: ['#005f26', '#fff'] },
    blue:  { active: ['#0a6cff', '#fff'], dimmed: ['#042d6b', '#fff'] },
    pink:  { active: ['#ff2e93', '#000'], dimmed: ['#6b133e', '#fff'] },
    red:   { active: ['#ff1a2d', '#000'], dimmed: ['#6b0b13', '#fff'] },
    white: { active: ['#ffffff', '#000'], dimmed: ['#bdbdbd', '#000'] },
    black: { active: ['#000000', '#fff'], dimmed: ['#2e2e30', '#fff'] }
  };
  var CYCLE = ['green', 'blue', 'pink', 'red'];

  // A short Simple timer: 4 exercises × 2 rounds, with get ready and a round cooldown.
  var EXERCISES = 4, ROUNDS = 2, WORK = 15, GET_READY = 5, REST = 8;
  var TOTAL = EXERCISES * ROUNDS;

  function buildPhases() {
    var list = [{ kind: 'getReady', duration: GET_READY, interval: 1, round: 1, exercise: 1 }];
    var n = 0;
    for (var r = 1; r <= ROUNDS; r++) {
      for (var e = 1; e <= EXERCISES; e++) {
        n++;
        list.push({ kind: 'work', duration: WORK, interval: n, round: r, exercise: e });
      }
      if (r < ROUNDS) list.push({ kind: 'rest', duration: REST, interval: n + 1, round: r + 1, exercise: 1 });
    }
    return list;
  }
  var phases = buildPhases();

  var el = {
    phase: document.getElementById('phase'),
    count: document.getElementById('count'),
    exercise: document.getElementById('exercise'),
    tally: document.getElementById('tally'),
    round: document.getElementById('round'),
    progress: document.getElementById('progress'),
    play: document.getElementById('play'),
    swatches: hero.querySelectorAll('.swatch'),
    theme: document.querySelector('meta[name="theme-color"]')
  };

  var state = {
    index: 1,            // start on the first WORK phase so the page opens in color
    remaining: 12,
    running: !reduceMotion.matches,
    picked: null,        // color chosen by the visitor; otherwise we cycle
    cycleAt: 0,
    timer: null
  };

  function colorName() {
    return state.picked || CYCLE[state.cycleAt % CYCLE.length];
  }

  function paint() {
    var p = phases[state.index];
    var tone = p.kind === 'work' ? 'active' : 'dimmed';
    var pair = COLORS[colorName()][tone];
    root.style.setProperty('--stage', pair[0]);
    root.style.setProperty('--on-stage', pair[1]);
    if (el.theme) el.theme.setAttribute('content', pair[0]);

    el.phase.textContent = p.kind === 'work' ? 'WORK' : p.kind === 'rest' ? 'REST' : 'GET READY';
    el.exercise.textContent = (p.kind === 'work' ? 'Exercise ' : 'Next: Exercise ') + p.exercise;
    el.count.textContent = String(state.remaining);
    el.tally.textContent = p.interval + ' / ' + TOTAL;
    el.round.textContent = 'Round ' + p.round + ' of ' + ROUNDS;
    // The ring empties as the interval runs out.
    el.progress.style.strokeDashoffset = String(100 - (state.remaining / p.duration) * 100);

    el.swatches.forEach(function (s) {
      s.setAttribute('aria-pressed', String(s.dataset.color === state.picked));
    });
  }

  function beep() {
    el.count.classList.remove('beep');
    void el.count.offsetWidth; // restart the animation
    el.count.classList.add('beep');
  }

  function tick() {
    state.remaining -= 1;
    if (state.remaining <= 0) {
      state.index = (state.index + 1) % phases.length;
      var p = phases[state.index];
      state.remaining = p.duration;
      if (p.kind === 'work') state.cycleAt += 1;
      // Jump the ring back to full without animating backwards.
      el.progress.style.transition = 'none';
      paint();
      void el.progress.getBoundingClientRect();
      el.progress.style.transition = '';
      return;
    }
    if (state.remaining <= 3) beep();
    paint();
  }

  function setRunning(run) {
    state.running = run;
    clearInterval(state.timer);
    if (run) state.timer = setInterval(tick, 1000);
    el.play.setAttribute('aria-pressed', String(!run));
    el.play.setAttribute('aria-label', run ? 'Pause preview' : 'Play preview');
    el.play.querySelector('.i-pause').toggleAttribute('hidden', !run);
    el.play.querySelector('.i-play').toggleAttribute('hidden', run);
  }

  el.play.addEventListener('click', function () { setRunning(!state.running); });

  el.swatches.forEach(function (s) {
    s.addEventListener('click', function () {
      state.picked = state.picked === s.dataset.color ? null : s.dataset.color;
      paint();
    });
  });

  // Save battery: stop when the tab is hidden, resume if it was running.
  var wasRunning = state.running;
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { wasRunning = state.running; setRunning(false); }
    else if (wasRunning) setRunning(true);
  });

  reduceMotion.addEventListener && reduceMotion.addEventListener('change', function (e) {
    if (e.matches) setRunning(false);
  });

  paint();
  setRunning(state.running);
})();
