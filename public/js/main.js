// ===================== DATA =====================
const PRODUCTS = [
  { sku:'STEAM-TOPUP-500',  name:'Пополнение Steam 500 ₽',         type:'topup', price:500,  old:550,  img:'https://cdn.cloudflare.steamstatic.com/steam/apps/593110/header.jpg',  fallback:'linear-gradient(135deg,#1b90c5,#0d5a80)' },
  { sku:'STEAM-TOPUP-1000', name:'Пополнение Steam 1000 ₽',        type:'topup', price:1000, old:1100, img:'https://cdn.cloudflare.steamstatic.com/steam/apps/593110/header.jpg',  fallback:'linear-gradient(135deg,#1b90c5,#0d5a80)' },
  { sku:'STEAM-TOPUP-2500', name:'Пополнение Steam 2500 ₽',        type:'topup', price:2500, old:2800, img:'https://cdn.cloudflare.steamstatic.com/steam/apps/593110/header.jpg',  fallback:'linear-gradient(135deg,#1b90c5,#0d5a80)' },
  { sku:'KEY-CS2-PRIME',    name:'CS2 Prime Status ключ',          type:'key',   price:1290, old:1990, img:'https://cdn.cloudflare.steamstatic.com/steam/apps/730/header.jpg',      fallback:'linear-gradient(135deg,#e65c00,#891f00)' },
  { sku:'KEY-GTA5',         name:'GTA V ключ активации',           type:'key',   price:1990, old:2490, img:'https://cdn.cloudflare.steamstatic.com/steam/apps/271590/header.jpg',   fallback:'linear-gradient(135deg,#4a1942,#c0392b)' },
  { sku:'KEY-EFT',          name:'Escape from Tarkov ключ',        type:'key',   price:3490, old:4500, img:'https://cdn.cloudflare.steamstatic.com/steam/apps/2056080/header.jpg',  fallback:'linear-gradient(135deg,#2d4a22,#1a2e13)' },
  { sku:'SUB-DISCORD-1M',   name:'Discord Nitro 1 месяц',          type:'sub',   price:399,  old:569,  img:'',                                                                      fallback:'linear-gradient(135deg,#5865F2,#3f4bbf)' },
  { sku:'SUB-YT-3M',        name:'YouTube Premium 3 месяца',       type:'sub',   price:1490, old:1990, img:'',                                                                      fallback:'linear-gradient(135deg,#FF0000,#8B0000)' },
  { sku:'SUB-SPOTIFY-1M',   name:'Spotify Premium 1 месяц',        type:'sub',   price:299,  old:399,  img:'',                                                                      fallback:'linear-gradient(135deg,#1DB954,#0a5c26)' },
  { sku:'GIFT-PSN-1000',    name:'PlayStation Store карта 1000 ₽', type:'gift',  price:1000, old:1200, img:'',                                                                      fallback:'linear-gradient(135deg,#003087,#00439c)' },
  { sku:'GIFT-XBOX-1500',   name:'Xbox Gift Card 1500 ₽',          type:'gift',  price:1500, old:1800, img:'',                                                                      fallback:'linear-gradient(135deg,#107C10,#0a5a0a)' },
  { sku:'GIFT-ROBLOX-800',  name:'Roblox 800 Robux',               type:'gift',  price:890,  old:1100, img:'',                                                                      fallback:'linear-gradient(135deg,#E31414,#7a0000)' },
];

const REVIEWS = [
  { name:'Bizidin', score:5, date:'Сегодня в 11:48', text:'Отзывчивый и приятный продавец, помог не только с товаром, но и с другим вопросом. Рекомендую!', product:'FunTime | Полностью готовый сервер под ключ', price:'139₽', icon:'🎮', avatarColor:'#667eea' },
  { name:'MaxGamer', score:5, date:'Вчера в 18:22', text:'Купил ключ CS2, всё пришло мгновенно. Очень доволен сервисом, буду возвращаться снова!', product:'CS2 Prime Status ключ', price:'1290₽', icon:'🔫', avatarColor:'#f093fb' },
  { name:'ProPlayer', score:5, date:'31 авг в 09:15', text:'Быстрая доставка, честные цены. Купил Discord Nitro — активировался сразу. 10/10', product:'Discord Nitro 1 месяц', price:'399₽', icon:'💬', avatarColor:'#4facfe' },
];

const TAB_MAP = { donats:'topup', subs:'sub', keys:'key', gift:'gift', accounts:'gift', items:'key', currency:'topup', other:null };

// ===================== CAROUSEL =====================
let currentSlide = 0;
const TOTAL_SLIDES = 3;
let autoTimer;

function goToSlide(n) {
  currentSlide = (n + TOTAL_SLIDES) % TOTAL_SLIDES;
  document.getElementById('carouselSlides').style.transform = `translateX(-${currentSlide * 100}%)`;
  document.querySelectorAll('.carousel-dot').forEach((d,i) => d.classList.toggle('active', i === currentSlide));
}

function startAuto() {
  clearInterval(autoTimer);
  autoTimer = setInterval(() => goToSlide(currentSlide + 1), 3500);
}

document.getElementById('carouselPrev').addEventListener('click', () => { goToSlide(currentSlide - 1); startAuto(); });
document.getElementById('carouselNext').addEventListener('click', () => { goToSlide(currentSlide + 1); startAuto(); });
document.querySelectorAll('.carousel-dot').forEach(d => d.addEventListener('click', () => { goToSlide(+d.dataset.index); startAuto(); }));
startAuto();

// ===================== CATALOG DROPDOWN =====================
const catalogBtn = document.getElementById('catalogBtn');
const catalogDropdown = document.getElementById('catalogDropdown');

catalogBtn.addEventListener('click', e => {
  e.stopPropagation();
  const open = catalogDropdown.classList.toggle('open');
  catalogBtn.classList.toggle('active', open);
  catalogBtn.setAttribute('aria-expanded', open);
});

document.addEventListener('click', e => {
  if (!catalogDropdown.contains(e.target) && !catalogBtn.contains(e.target)) {
    catalogDropdown.classList.remove('open');
    catalogBtn.classList.remove('active');
    catalogBtn.setAttribute('aria-expanded', 'false');
  }
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    catalogDropdown.classList.remove('open');
    catalogBtn.classList.remove('active');
  }
});

// ===================== CURRENCY SWITCHER =====================
document.querySelectorAll('.currency-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.currency-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const sym = btn.dataset.currency;
    document.getElementById('steamPayBtn').textContent = `Оплатить 500${sym}`;
  });
});

// ===================== PRODUCT CARDS =====================
function createCard(p) {
  const card = document.createElement('div');
  card.className = 'product-card';
  card.id = `card-${p.sku}`;

  const imgStyle = p.img
    ? `background-image: url('${p.img}'); background-size: cover; background-position: center;`
    : `background: ${p.fallback};`;

  card.innerHTML = `
    <div class="product-img" style="${imgStyle}">
      ${!p.img ? `<span style="position:relative;z-index:1;font-size:11px;color:rgba(255,255,255,0.9);font-weight:600;padding:4px 8px;background:rgba(0,0,0,0.3);border-radius:4px">${p.name}</span>` : ''}
    </div>
    <div class="product-body">
      <div class="product-name">${p.name}</div>
      <div class="product-prices">
        <span class="product-price-new">${p.price} ₽</span>
        <span class="product-price-old">${p.old} ₽</span>
      </div>
      <button class="product-buy-btn" data-sku="${p.sku}">Купить</button>
    </div>`;
  card.querySelector('.product-buy-btn').addEventListener('click', (e) => {
    e.stopPropagation();
    openModal(p);
  });
  // Also keep the card clickable as a fallback
  card.addEventListener('click', () => {
    openModal(p);
  });
  return card;
}

function renderGrid(containerId, items) {
  const grid = document.getElementById(containerId);
  grid.innerHTML = '';
  items.slice(0, 5).forEach(p => grid.appendChild(createCard(p)));
}

// Initial render
renderGrid('popularGrid', PRODUCTS.filter(p => p.type === 'topup').concat(PRODUCTS.filter(p => p.type !== 'topup')));
renderGrid('recommendedGrid', [...PRODUCTS].sort(() => Math.random() - 0.5));
renderGrid('otherGrid', [...PRODUCTS].reverse());

// Tabs
document.querySelectorAll('#popularTabs .tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('#popularTabs .tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const typeKey = TAB_MAP[btn.dataset.tab];
    const filtered = typeKey ? PRODUCTS.filter(p => p.type === typeKey) : PRODUCTS;
    renderGrid('popularGrid', filtered.length ? filtered : PRODUCTS);
  });
});

// ===================== REVIEWS =====================
function renderReviews() {
  const grid = document.getElementById('reviewsGrid');
  if (!grid) return; // Защита от ошибки, если блок отзывов закомментирован

  REVIEWS.forEach(r => {
    const card = document.createElement('div');
    card.className = 'review-card';
    const stars = Array(5).fill('<svg viewBox="0 0 24 24"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>').join('');
    card.innerHTML = `
      <div class="review-header">
        <div class="review-avatar" style="background:${r.avatarColor}">${r.name[0]}</div>
        <div class="review-meta">
          <div class="review-name">${r.name}</div>
          <div class="review-stars">${stars}<span class="review-score">${r.score}.0</span></div>
        </div>
        <span class="review-date">${r.date}</span>
      </div>
      <p class="review-text">${r.text}</p>
      <div class="review-product">
        <div class="review-product-img">${r.icon}</div>
        <div class="review-product-name">${r.product}</div>
        <div class="review-product-price">${r.price}</div>
      </div>`;
    grid.appendChild(card);
  });
}
renderReviews();

// ===================== ORDER MODAL =====================
let selectedProduct = null;

function openModal(p) {
  selectedProduct = p;
  document.getElementById('modalProductName').textContent = p.name;
  document.getElementById('modalPrice').textContent = `${p.price} ₽`;
  document.getElementById('modalEmail').value = '';
  document.getElementById('modalOverlay').classList.add('open');
}

document.getElementById('modalCancel').addEventListener('click', () => {
  document.getElementById('modalOverlay').classList.remove('open');
});

document.getElementById('modalOverlay').addEventListener('click', e => {
  if (e.target === document.getElementById('modalOverlay'))
    document.getElementById('modalOverlay').classList.remove('open');
});

document.getElementById('modalConfirm').addEventListener('click', async () => {
  const email = document.getElementById('modalEmail').value.trim();
  if (!email || !email.includes('@')) {
    document.getElementById('modalEmail').style.borderColor = '#e53e3e';
    return;
  }
  document.getElementById('modalEmail').style.borderColor = '';

  const btn = document.getElementById('modalConfirm');
  btn.textContent = 'Создаём заказ...';
  btn.disabled = true;

  try {
    const res = await fetch('/api/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sku: selectedProduct.sku, email, amount: selectedProduct.price })
    });
    const order = await res.json();
    document.getElementById('modalOverlay').classList.remove('open');
    window.location.href = `/order-status.html?id=${order.id}`;
  } catch {
    btn.textContent = 'Ошибка, повторите';
    btn.disabled = false;
    setTimeout(() => { btn.textContent = 'Оплатить'; }, 2000);
  }
});
