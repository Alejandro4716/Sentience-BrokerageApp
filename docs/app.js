const BACKEND_BASE = "http://127.0.0.1:8000";

const COMPANY_NAMES = {
  AAPL: "Apple Inc.", TSLA: "Tesla Inc.", NVDA: "Nvidia Corp.", MSFT: "Microsoft Corp.",
  AMZN: "Amazon.com Inc.", GOOGL: "Alphabet Inc.", GOOG: "Alphabet Inc.", META: "Meta Platforms",
  NFLX: "Netflix Inc.", AMD: "AMD Inc.", JPM: "JPMorgan Chase", V: "Visa Inc.",
  MA: "Mastercard", UNH: "UnitedHealth Group", "BRK.B": "Berkshire Hathaway", DIS: "Walt Disney Co.",
  PYPL: "PayPal Holdings", INTC: "Intel Corp.", CRM: "Salesforce Inc.", BABA: "Alibaba Group"
};

const state = {
  token: localStorage.getItem("sentience.token") || "",
  email: localStorage.getItem("sentience.email") || "",
  account: { cash_balance: 0, holdings: [] },
  banks: [],
  txns: [],
  quotes: {},
  indexQuotes: {},
  watchlist: JSON.parse(localStorage.getItem("sentience.watchlist") || '["AAPL","NVDA","TSLA"]'),
  selectedSymbol: "",
  selectedPeriod: "1M",
  authMode: "login",
  activeView: "portfolio"
};

const $ = (id) => document.getElementById(id);
const money = (value) => (Number(value) || 0).toLocaleString("en-US", { style: "currency", currency: "USD" });
const pct = (value) => `${Number(value) >= 0 ? "+" : ""}${(Number(value) || 0).toFixed(2)}%`;
const companyName = (symbol) => COMPANY_NAMES[symbol] || symbol;
const initials = (email) => {
  if (!email) return "AM";
  const base = email.split("@")[0].split(/[._-]/).filter(Boolean);
  const chars = base.map((part) => part[0]?.toUpperCase()).filter(Boolean);
  return (chars.length >= 2 ? chars.slice(0, 2).join("") : email.slice(0, 2).toUpperCase());
};

function toast(message) {
  const node = $("toast");
  node.textContent = message;
  node.classList.add("show");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => node.classList.remove("show"), 3200);
}

async function api(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  const res = await fetch(`${BACKEND_BASE}${path}`, { ...options, headers });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const detail = data?.detail || text || `HTTP ${res.status}`;
    throw new Error(Array.isArray(detail) ? detail.map((d) => d.msg).join(", ") : detail);
  }
  return data;
}

async function fetchQuote(symbol) {
  const sym = symbol.trim().toUpperCase();
  if (!sym) return null;
  if (state.quotes[sym]) return state.quotes[sym];
  const q = await api(`/market/quote?symbol=${encodeURIComponent(sym)}`);
  state.quotes[sym] = q;
  return q;
}

async function fetchCandles(symbol, period) {
  if (!symbol) return [];
  const now = Math.floor(Date.now() / 1000);
  const days = { "1D": 1, "1W": 7, "1M": 30, "3M": 90, "1Y": 365, ALL: 1825 }[period] || 30;
  const resolution = period === "1D" ? "60" : period === "1Y" ? "W" : period === "ALL" ? "M" : "D";
  const from = now - days * 86400;
  const data = await api(`/market/candles?symbol=${encodeURIComponent(symbol)}&resolution=${resolution}&from_time=${from}&to=${now}`);
  return data.s === "ok" && Array.isArray(data.c) ? data.c : [];
}

async function refreshBackend() {
  if (!state.token) {
    state.account = { cash_balance: 0, holdings: [] };
    state.banks = [];
    state.txns = [];
    render();
    return;
  }
  try {
    const [account, banks, txns] = await Promise.all([
      api("/account"),
      api("/bank-accounts"),
      api("/transactions").catch(() => [])
    ]);
    state.account = account;
    state.banks = banks;
    state.txns = txns;
    await refreshHoldingQuotes();
    if (!state.selectedSymbol && account.holdings[0]) state.selectedSymbol = account.holdings[0].symbol;
    render();
    await renderChart();
  } catch (error) {
    if (/401|invalid token|not authenticated/i.test(error.message)) logout(false);
    toast(error.message);
    render();
  }
}

async function refreshHoldingQuotes() {
  const symbols = state.account.holdings.map((h) => h.symbol);
  await Promise.all(symbols.map((symbol) => fetchQuote(symbol).catch(() => null)));
}

async function refreshMarkets() {
  const indices = ["SPY", "QQQ", "DIA", "IVV"];
  const symbols = [...new Set([...indices, ...state.watchlist])];
  await Promise.all(symbols.map((symbol) => fetchQuote(symbol).catch(() => null)));
  renderMarkets();
}

function render() {
  renderSession();
  renderView();
  renderPortfolio();
  renderMarkets();
  renderAccount();
}

function renderSession() {
  const loggedIn = Boolean(state.token);
  $("sessionPill").innerHTML = `<span class="dot ${loggedIn ? "" : "off"}"></span><span>${loggedIn ? "Backend connected" : "Logged out"}</span>`;
  $("authButton").textContent = initials(state.email);
  $("accountAvatar").textContent = initials(state.email);
  $("logoutButton").classList.toggle("hidden", !loggedIn);
  renderMarketState();
}

function renderMarketState() {
  const now = new Date();
  const eastern = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York", weekday: "short", hour: "numeric", minute: "numeric", hour12: false
  }).formatToParts(now);
  const value = Object.fromEntries(eastern.map((p) => [p.type, p.value]));
  const dayOpen = !["Sat", "Sun"].includes(value.weekday);
  const mins = Number(value.hour) * 60 + Number(value.minute);
  const open = dayOpen && mins >= 570 && mins < 960;
  $("marketState").innerHTML = `<span class="dot ${open ? "" : "off"}"></span><span>${open ? "NYSE OPEN" : "NYSE CLOSED"}</span>`;
}

function renderView() {
  document.querySelectorAll(".nav-tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.view === state.activeView));
  document.querySelectorAll(".view").forEach((view) => view.classList.toggle("active", view.id === `${state.activeView}View`));
  const label = state.activeView.toUpperCase();
  $("viewEyebrow").textContent = label;
  $("viewTitle").textContent = state.activeView === "portfolio" ? "Sentience" : label[0] + label.slice(1).toLowerCase();
}

function renderPortfolio() {
  const holdings = state.account.holdings || [];
  const liveValue = holdings.reduce((sum, h) => sum + ((state.quotes[h.symbol]?.c || h.avg_price) * h.shares), 0);
  const dayPnl = holdings.reduce((sum, h) => sum + ((state.quotes[h.symbol]?.d || 0) * h.shares), 0);
  const total = liveValue + (state.account.cash_balance || 0);
  $("portfolioValue").textContent = money(total);
  $("cashBalance").textContent = money(state.account.cash_balance);
  $("dayPnl").textContent = money(dayPnl);
  $("dayPnl").className = dayPnl >= 0 ? "positive" : "negative";
  $("positionCount").textContent = holdings.length;
  $("holdingsMeta").textContent = `${holdings.length} positions`;

  const select = $("featuredSelect");
  select.innerHTML = holdings.length
    ? holdings.map((h) => `<option value="${h.symbol}" ${h.symbol === state.selectedSymbol ? "selected" : ""}>${h.symbol}</option>`).join("")
    : `<option>No holdings</option>`;
  select.disabled = !holdings.length;

  const selected = state.selectedSymbol || holdings[0]?.symbol || "";
  const q = state.quotes[selected];
  $("featuredName").textContent = selected ? companyName(selected) : "No position selected";
  $("featuredPrice").textContent = selected ? money(q?.c || holdings.find((h) => h.symbol === selected)?.avg_price || 0) : "$0.00";
  $("featuredChange").textContent = pct(q?.dp || 0);
  $("featuredChange").className = `change-badge ${(q?.dp || 0) >= 0 ? "up" : "down"}`;

  $("holdingsRows").innerHTML = holdings.length ? holdings.map((h) => holdingRow(h, liveValue)).join("") :
    `<div class="row"><div><strong>No holdings yet</strong><small>Use Trade to buy your first stock.</small></div></div>`;
}

function holdingRow(h, liveValue) {
  const q = state.quotes[h.symbol] || {};
  const price = q.c || h.avg_price;
  const value = price * h.shares;
  const weight = liveValue ? `${Math.round((value / liveValue) * 100)}%` : "0%";
  const klass = (q.dp || 0) >= 0 ? "positive" : "negative";
  return `<button class="row holding-row" data-symbol="${h.symbol}">
    <div><strong>${h.symbol}</strong><small>${companyName(h.symbol)} · ${h.shares} shares · avg ${money(h.avg_price)}</small></div>
    <div class="hide-mobile"><small>Weight</small><strong>${weight}</strong></div>
    <div class="right"><strong>${money(value)}</strong><small class="${klass}">${pct(q.dp || 0)}</small></div>
  </button>`;
}

function renderMarkets() {
  const indices = ["SPY", "QQQ", "DIA", "IVV"];
  $("indexRows").innerHTML = indices.map(marketRow).join("");
  $("watchlistRows").innerHTML = state.watchlist.length ? state.watchlist.map(marketRow).join("") :
    `<div class="row"><div><strong>No symbols</strong><small>Add a ticker to start watching.</small></div></div>`;
}

function marketRow(symbol) {
  const q = state.quotes[symbol] || {};
  const klass = (q.dp || 0) >= 0 ? "positive" : "negative";
  return `<button class="row market-row" data-symbol="${symbol}">
    <div><strong>${symbol}</strong><small>${companyName(symbol)}</small></div>
    <div class="right"><strong>${q.c ? money(q.c) : "-"}</strong><small class="${klass}">${q.c ? pct(q.dp) : ""}</small></div>
  </button>`;
}

function renderAccount() {
  const loggedIn = Boolean(state.token);
  $("accountEmail").textContent = loggedIn ? state.email : "Not signed in";
  $("accountStatus").textContent = loggedIn ? "Session active with the local Sentience backend." : "Connect to the backend to manage your brokerage account.";
  $("accountAuthButton").textContent = loggedIn ? "Manage session" : "Log in / Sign up";
  $("bankRows").innerHTML = state.banks.length ? state.banks.map((b) => `<div class="row">
    <div><strong>Routing •••• ${b.routing_last4}</strong><small>Account •••• ${b.account_last4}</small></div>
    <div class="right"><small>Linked</small><strong>Bank</strong></div>
  </div>`).join("") : `<div class="row"><div><strong>No bank accounts linked</strong><small>A bank is required for deposits and trades.</small></div></div>`;
  $("txnMeta").textContent = state.txns.length;
  $("transactionRows").innerHTML = state.txns.length ? state.txns.map((t) => `<div class="row">
    <div><strong>${t.type}${t.symbol ? ` · ${t.symbol}` : ""}</strong><small>${new Date(t.created_at).toLocaleString()}</small></div>
    <div class="hide-mobile"><small>${t.shares ? `${t.shares} shares` : ""}</small><strong>${t.price ? money(t.price) : ""}</strong></div>
    <div class="right"><strong class="${t.amount >= 0 ? "positive" : "negative"}">${money(t.amount)}</strong></div>
  </div>`).join("") : `<div class="row"><div><strong>No transactions yet</strong><small>Activity will appear here.</small></div></div>`;
}

async function renderChart() {
  const canvas = $("chartCanvas");
  const ctx = canvas.getContext("2d");
  const symbol = state.selectedSymbol || state.account.holdings?.[0]?.symbol;
  const rect = canvas.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.floor(rect.width * ratio);
  canvas.height = Math.floor(rect.height * ratio);
  ctx.scale(ratio, ratio);
  ctx.clearRect(0, 0, rect.width, rect.height);
  if (!symbol) return drawEmptyChart(ctx, rect.width, rect.height, "No chart data");
  const prices = await fetchCandles(symbol, state.selectedPeriod).catch(() => []);
  if (prices.length < 2) return drawEmptyChart(ctx, rect.width, rect.height, "No chart data");
  drawChart(ctx, rect.width, rect.height, prices);
}

function drawEmptyChart(ctx, width, height, label) {
  ctx.fillStyle = "#4a4a4a";
  ctx.font = "13px system-ui";
  ctx.textAlign = "center";
  ctx.fillText(label, width / 2, height / 2);
}

function drawChart(ctx, width, height, prices) {
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const range = max - min || 1;
  const pad = 18;
  const points = prices.map((p, i) => ({
    x: (i / (prices.length - 1)) * width,
    y: pad + (1 - ((p - min) / range)) * (height - pad * 2)
  }));
  const gradient = ctx.createLinearGradient(0, 0, 0, height);
  gradient.addColorStop(0, "rgba(182,232,82,.32)");
  gradient.addColorStop(1, "rgba(182,232,82,0)");
  ctx.beginPath();
  points.forEach((point, i) => i ? ctx.lineTo(point.x, point.y) : ctx.moveTo(point.x, point.y));
  ctx.lineTo(width, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.fillStyle = gradient;
  ctx.fill();
  ctx.beginPath();
  points.forEach((point, i) => i ? ctx.lineTo(point.x, point.y) : ctx.moveTo(point.x, point.y));
  ctx.strokeStyle = "#b6e852";
  ctx.lineWidth = 2;
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.stroke();
}

async function authSubmit(event) {
  event.preventDefault();
  const email = $("emailInput").value.trim();
  const password = $("passwordInput").value;
  try {
    const auth = await api(state.authMode === "login" ? "/auth/login" : "/auth/signup", {
      method: "POST",
      body: JSON.stringify({ email, password })
    });
    state.token = auth.token;
    state.email = email;
    localStorage.setItem("sentience.token", state.token);
    localStorage.setItem("sentience.email", state.email);
    $("authDialog").close();
    toast("Backend session connected.");
    await refreshBackend();
  } catch (error) {
    toast(error.message);
  }
}

function logout(showToast = true) {
  state.token = "";
  state.email = "";
  state.account = { cash_balance: 0, holdings: [] };
  state.banks = [];
  state.txns = [];
  localStorage.removeItem("sentience.token");
  localStorage.removeItem("sentience.email");
  if (showToast) toast("Signed out.");
  render();
  renderChart();
}

async function trade(event, side) {
  event.preventDefault();
  const symbol = $("tradeActionSymbol").value;
  const shares = Number($("tradeShares").value);
  const quote = await fetchQuote(symbol);
  if (!shares || shares <= 0) return toast("Enter a share quantity.");
  try {
    await api(`/trade/${side}`, {
      method: "POST",
      body: JSON.stringify({ symbol, shares, price: quote.c })
    });
    toast(`${side === "buy" ? "Bought" : "Sold"} ${shares} ${symbol}.`);
    await refreshBackend();
  } catch (error) {
    toast(error.message);
  }
}

function wireEvents() {
  $("navTabs").addEventListener("click", (event) => {
    const tab = event.target.closest(".nav-tab");
    if (!tab) return;
    state.activeView = tab.dataset.view;
    renderView();
  });
  $("refreshButton").addEventListener("click", () => Promise.all([refreshBackend(), refreshMarkets()]));
  $("refreshMarkets").addEventListener("click", refreshMarkets);
  $("authButton").addEventListener("click", openAuth);
  $("accountAuthButton").addEventListener("click", openAuth);
  $("authForm").addEventListener("submit", authSubmit);
  $("logoutButton").addEventListener("click", () => {
    $("authDialog").close();
    logout();
  });
  $("modeToggle").addEventListener("click", () => {
    state.authMode = state.authMode === "login" ? "signup" : "login";
    $("authHeading").textContent = state.authMode === "login" ? "Log in" : "Sign up";
    $("authSubmit").textContent = state.authMode === "login" ? "Log in" : "Create account";
    $("modeToggle").textContent = state.authMode === "login" ? "Need an account? Sign up" : "Already have an account? Log in";
  });
  $("watchlistForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const symbol = $("watchlistInput").value.trim().toUpperCase();
    if (!symbol || state.watchlist.includes(symbol)) return;
    state.watchlist.push(symbol);
    localStorage.setItem("sentience.watchlist", JSON.stringify(state.watchlist));
    $("watchlistInput").value = "";
    await refreshMarkets();
  });
  document.body.addEventListener("click", async (event) => {
    const holding = event.target.closest(".holding-row");
    const market = event.target.closest(".market-row");
    if (holding) {
      state.selectedSymbol = holding.dataset.symbol;
      renderPortfolio();
      await renderChart();
    }
    if (market) {
      state.activeView = "trade";
      $("tradeSymbol").value = market.dataset.symbol;
      renderView();
      await showTradeQuote(market.dataset.symbol);
    }
  });
  $("featuredSelect").addEventListener("change", async (event) => {
    state.selectedSymbol = event.target.value;
    renderPortfolio();
    await renderChart();
  });
  $("periodButtons").addEventListener("click", async (event) => {
    const button = event.target.closest("button");
    if (!button) return;
    state.selectedPeriod = button.dataset.period;
    document.querySelectorAll("#periodButtons button").forEach((b) => b.classList.toggle("active", b === button));
    await renderChart();
  });
  $("tradeSearch").addEventListener("submit", async (event) => {
    event.preventDefault();
    await showTradeQuote($("tradeSymbol").value.trim().toUpperCase());
  });
  $("bankToggle").addEventListener("click", () => $("bankForm").classList.toggle("hidden"));
  $("bankForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await api("/bank-accounts", {
        method: "POST",
        body: JSON.stringify({ routing_number: $("routingInput").value, account_number: $("accountInput").value })
      });
      $("bankForm").reset();
      toast("Bank account linked.");
      await refreshBackend();
    } catch (error) {
      toast(error.message);
    }
  });
  $("depositForm").addEventListener("submit", (event) => moneyMove(event, "deposit"));
  $("withdrawForm").addEventListener("submit", (event) => moneyMove(event, "withdraw"));
  window.addEventListener("resize", () => renderChart());
}

function openAuth() {
  $("emailInput").value = state.email;
  $("passwordInput").value = "";
  $("authDialog").showModal();
}

async function showTradeQuote(symbol) {
  if (!symbol) return;
  try {
    const q = await fetchQuote(symbol);
    $("tradeCard").innerHTML = `<form class="trade-quote" id="tradeActionForm">
      <input type="hidden" id="tradeActionSymbol" value="${symbol}" />
      <div>
        <p class="muted">${companyName(symbol)}</p>
        <strong>${money(q.c)}</strong>
        <span class="change-badge ${q.dp >= 0 ? "up" : "down"}">${pct(q.dp)}</span>
      </div>
      <p class="muted">H ${money(q.h)} · L ${money(q.l)} · Open ${money(q.o)} · Prev close ${money(q.pc)}</p>
      <div class="trade-actions">
        <input id="tradeShares" type="number" min="1" step="1" placeholder="Shares" />
        <button class="primary-button" id="buyButton" type="button">Buy</button>
        <button class="sell-button" id="sellButton" type="button">Sell</button>
      </div>
    </form>`;
    $("buyButton").addEventListener("click", (event) => trade(event, "buy"));
    $("sellButton").addEventListener("click", (event) => trade(event, "sell"));
  } catch (error) {
    toast(error.message);
  }
}

async function moneyMove(event, type) {
  event.preventDefault();
  const input = type === "deposit" ? $("depositAmount") : $("withdrawAmount");
  const amount = Number(input.value);
  if (!amount || amount <= 0) return toast("Enter a valid amount.");
  try {
    await api(`/${type}`, { method: "POST", body: JSON.stringify({ amount }) });
    input.value = "";
    toast(`${type === "deposit" ? "Deposit" : "Withdrawal"} complete.`);
    await refreshBackend();
  } catch (error) {
    toast(error.message);
  }
}

wireEvents();
render();
refreshBackend();
refreshMarkets();
renderChart();
