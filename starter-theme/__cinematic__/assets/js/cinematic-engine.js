/* Cinematic Scroll Kit — adaptive controller
   --------------------------------------------------------
   DESKTOP  → smooth-scroll + frame-perfect video scrub (GSAP + Lenis)
   MOBILE   → native scroll + autoplay-loop videos with IO crossfade
   REDUCED  → motion respects prefers-reduced-motion (instant reveals)
*/
(() => {
  const yr = document.getElementById('yr'); if (yr) yr.textContent = new Date().getFullYear();

  const mqMobile  = window.matchMedia('(max-width: 900px), (pointer: coarse) and (max-width: 1024px)');
  const mqReduced = window.matchMedia('(prefers-reduced-motion: reduce)');

  const stage   = document.querySelector('.stage');
  const videos  = Array.from(document.querySelectorAll('.stage__v'));
  const scenes  = Array.from(document.querySelectorAll('.scene'));
  const curtain = document.querySelector('.curtain');
  const isMobile = mqMobile.matches;
  console.info('[Kit] mode:', isMobile ? 'MOBILE (portrait videos, autoplay-loop)' : 'DESKTOP (landscape videos, scroll-scrub)');

  // Re-init when crossing the breakpoint (e.g. resizing browser or rotating tablet)
  mqMobile.addEventListener('change', () => location.reload());

  // Choose video source set
  videos.forEach(v => {
    v.dataset.activeSrc = (isMobile && v.dataset.srcMobile) ? v.dataset.srcMobile : v.dataset.src;
  });

  // shared video ready helper
  function readyVideo(v) {
    return new Promise(resolve => {
      const ok = () => { if (v.duration && !isNaN(v.duration)) resolve(); };
      if (v.readyState >= 2 && v.duration) return resolve();
      v.addEventListener('loadedmetadata', ok, { once: true });
      v.addEventListener('loadeddata', ok, { once: true });
      v.addEventListener('canplay', ok, { once: true });
      if (!v.src) { v.src = v.dataset.activeSrc; v.load(); }
    });
  }

  // anchor scrolling (works in both modes)
  function scrollToEl(el, dur) {
    if (window.lenis) return window.lenis.scrollTo(el, { duration: dur || 1.6 });
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', e => {
      const id = a.getAttribute('href');
      if (id.length < 2) return;
      const el = document.querySelector(id);
      if (!el) return;
      e.preventDefault();
      scrollToEl(el, 1.6);
    });
  });

  // ================================================================
  //                          MOBILE PATH
  // ================================================================
  if (isMobile) {
    // mark body so CSS can apply the lighter mobile layout
    document.body.classList.add('is-mobile');
    // set loop+muted on every video; play when active
    videos.forEach(v => { v.loop = true; v.muted = true; v.playsInline = true; });

    // Reveal copy when scene has 25% visibility — fades the words in early
    const ioReveal = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) e.target.classList.add('in');
        else if (e.boundingClientRect.top > 0) e.target.classList.remove('in');
      });
    }, { threshold: 0.25 });
    scenes.forEach(s => ioReveal.observe(s));

    // Activate scene's video only when the scene is well-centered in the viewport.
    // rootMargin shrinks the viewport from top + bottom so only the middle band counts.
    const ioActive = new IntersectionObserver(entries => {
      // pick the entry with the largest intersection ratio
      let best = null;
      entries.forEach(e => {
        if (e.isIntersecting && (!best || e.intersectionRatio > best.intersectionRatio)) best = e;
      });
      if (!best) return;
      const scene = best.target;
      const idx = scenes.indexOf(scene);
      const v = videos[idx];
      readyVideo(v).then(() => {
        videos.forEach((other,i) => {
          if (i === idx) {
            other.classList.add('active');
            other.play?.().catch(()=>{});
          } else {
            other.classList.remove('active');
            if (!other.paused) other.pause();
          }
        });
        stage.setAttribute('data-veil', scene.dataset.veil || 'left');
      });
    }, { rootMargin: '-35% 0% -35% 0%', threshold: 0 });
    scenes.forEach(s => ioActive.observe(s));

    // method articles stagger
    const ioMethod = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          e.target.querySelectorAll('.method article').forEach((c,i)=>setTimeout(()=>c.classList.add('in'), 180*i));
          ioMethod.unobserve(e.target);
        }
      });
    }, { threshold: 0.35 });
    const s7 = document.getElementById('s7'); if (s7) ioMethod.observe(s7);

    // pricing fade-in
    const ioPricing = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          document.body.classList.add('no-stage');
          document.getElementById('pricing').classList.add('in');
        } else if (e.boundingClientRect.top > 0) {
          document.body.classList.remove('no-stage');
          document.getElementById('pricing').classList.remove('in');
        }
      });
    }, { threshold: 0.15 });
    const pricing = document.getElementById('pricing'); if (pricing) ioPricing.observe(pricing);

    // progress bar
    const prog = document.getElementById('progress');
    const onScroll = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      prog.style.width = max > 0 ? ((window.scrollY/max)*100).toFixed(2)+'%' : '0%';
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    // pre-warm first 2 videos
    readyVideo(videos[0]).then(()=>{ videos[0].classList.add('active'); videos[0].play?.().catch(()=>{}); });
    readyVideo(videos[1]);
    return;
  }

  // ================================================================
  //                         DESKTOP PATH
  // ================================================================
  gsap.registerPlugin(ScrollTrigger);

  const lenis = new Lenis({
    duration: 2.0,
    easing: t => 1 - Math.pow(1 - t, 4),
    smoothWheel: true,
    smoothTouch: false,
    wheelMultiplier: 0.68,
    touchMultiplier: 1.3,
    lerp: 0.075,
  });
  window.lenis = lenis;
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add(time => lenis.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);

  // progress bar
  const prog = document.getElementById('progress');
  ScrollTrigger.create({
    start: 0, end: 'max',
    onUpdate: self => { prog.style.width = (self.progress * 100).toFixed(2) + '%'; }
  });

  scenes.forEach(scene => {
    const mult = parseFloat(scene.dataset.scrub || 4);
    scene.style.setProperty('--scene-h', (mult * 100) + 'vh');
  });

  const DOLLY = [
    { sx:1.16, x:-2,  y:-1 },{ sx:1.14, x: 3,  y: 1 },
    { sx:1.20, x: 0,  y:-2 },{ sx:1.14, x:-3,  y: 1 },
    { sx:1.16, x: 2,  y:-2 },{ sx:1.16, x:-2,  y: 2 },
    { sx:1.18, x: 0,  y: 0 },{ sx:1.12, x: 0,  y: 2 },
    { sx:1.20, x: 0,  y:-3 },
  ];

  (async () => {
    await Promise.all(videos.slice(0, 3).map(readyVideo));
    videos[0].classList.add('active');
    stage.setAttribute('data-veil', scenes[0].dataset.veil || 'left');
  })();
  videos.slice(3).forEach((v, i) => {
    const idx = i + 3;
    const trigger = scenes[Math.max(0, idx - 1)] || scenes[idx];
    ScrollTrigger.create({ trigger, start: 'top bottom', once: true, onEnter: () => readyVideo(v) });
  });

  const localProgress = new Array(videos.length).fill(0);
  const displayed     = new Array(videos.length).fill(0);

  function paintLoop() {
    for (let i = 0; i < videos.length; i++) {
      const v = videos[i];
      if (!v.duration) continue;
      displayed[i] += (localProgress[i] - displayed[i]) * 0.12;
      if (Math.abs(localProgress[i] - displayed[i]) < 0.0004) displayed[i] = localProgress[i];
      const t = displayed[i] * Math.max(0, v.duration - 1 / 60);
      if (Math.abs(v.currentTime - t) > 1 / 60) { try { v.currentTime = t; } catch (_) {} }
      const d = DOLLY[i] || DOLLY[0];
      const k = displayed[i];
      v.style.transform = `scale(${d.sx - k*0.05}) translate3d(${d.x*(k-0.5)*2}%, ${d.y*(k-0.5)*2}%, 0)`;
    }
    requestAnimationFrame(paintLoop);
  }
  requestAnimationFrame(paintLoop);

  let lastActive = 0;
  function activate(idx, scene) {
    if (idx === lastActive) return;
    const out = videos[lastActive], inV = videos[idx];
    inV.classList.add('active');
    setTimeout(() => { if (out !== inV) out.classList.remove('active'); }, 700);
    lastActive = idx;
    stage.setAttribute('data-veil', scene.dataset.veil || 'left');
  }

  scenes.forEach((scene, idx) => {
    ScrollTrigger.create({
      trigger: scene, start: 'top top', end: 'bottom bottom', scrub: true,
      onUpdate: self => { localProgress[idx] = self.progress; }
    });
    ScrollTrigger.create({
      trigger: scene, start: 'top 75%', end: 'bottom 25%',
      onEnter: () => activate(idx, scene), onEnterBack: () => activate(idx, scene),
    });
    ScrollTrigger.create({
      trigger: scene, start: 'top 65%', end: 'top top',
      onEnter: () => scene.classList.add('in'), onLeaveBack: () => scene.classList.remove('in'),
    });
    ScrollTrigger.create({
      trigger: scene, start: 'bottom 40%', end: 'bottom top',
      onEnter: () => scene.classList.add('out'), onLeaveBack: () => scene.classList.remove('out'),
    });
    if (scene.id === 's7') {
      ScrollTrigger.create({
        trigger: scene, start: 'top 60%',
        onEnter: () => scene.querySelectorAll('.method article').forEach((c,i)=>setTimeout(()=>c.classList.add('in'), 260*i))
      });
    }
  });

  // story → pricing crossfade
  ScrollTrigger.create({
    trigger: '#s9', start: 'bottom 110%', end: 'bottom 30%', scrub: true,
    onUpdate: self => { curtain.style.opacity = self.progress.toFixed(3); }
  });
  ScrollTrigger.create({
    trigger: '#pricing', start: 'top 70%', end: 'top 20%', scrub: true,
    onUpdate: self => { curtain.style.opacity = (1 - self.progress).toFixed(3); }
  });
  ScrollTrigger.create({
    trigger: '#pricing', start: 'top 60%',
    onEnter:    () => { document.body.classList.add('no-stage'); document.getElementById('pricing').classList.add('in'); },
    onLeaveBack:() => { document.body.classList.remove('no-stage'); document.getElementById('pricing').classList.remove('in'); },
  });

  // reduced motion: kill heavy transforms / scrubs
  if (mqReduced.matches) {
    document.body.classList.add('reduced-motion');
  }

  window.addEventListener('resize', () => ScrollTrigger.refresh(), { passive: true });
})();
