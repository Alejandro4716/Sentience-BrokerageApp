# Sentience Brokerage

Sentience Brokerage is a simulated trading app with three connected surfaces:

- A Swift/iOS app in `Sentience/`
- A FastAPI backend in `Sentience-backend/`
- A static web version in `docs/`, published with GitHub Pages

The Swift app and the website both use the same public backend on Railway, so account data, linked bank accounts, transactions, holdings, quotes, and chart data stay on one backend API.

## Live Links

- Web app: https://alejandro4716.github.io/Sentience-BrokerageApp/
- Backend: https://sentience-brokerageapp-production.up.railway.app/

## Data Sources

Market data is proxied through the backend:

- Live quotes use Finnhub through `/market/quote`.
- Chart candles try Finnhub through `/market/candles`, then fall back to Yahoo Finance chart data when Finnhub candle access is blocked.

The frontend never exposes API keys.

## Project Structure

```txt
Sentience-BrokerageApp/
├── Sentience/              # Swift/iOS app
├── Sentience-backend/      # FastAPI backend and Docker/Railway config
├── docs/                   # Static GitHub Pages web client
└── README.md
```

## Backend

Run locally:

```sh
cd Sentience-backend
docker compose up --build
```

Useful endpoints:

```txt
GET  /
POST /auth/signup
POST /auth/login
GET  /account
GET  /bank-accounts
POST /bank-accounts
POST /deposit
POST /withdraw
POST /trade/buy
POST /trade/sell
GET  /transactions
GET  /market/quote?symbol=AAPL
GET  /market/candles?symbol=AAPL&resolution=D&from_time=...&to=...
```

Railway environment variables:

```txt
DATABASE_URL
FINNHUB_API_KEY
FRONTEND_ORIGINS=https://alejandro4716.github.io
PORT=8000
```

## Web App

The static web app lives in `docs/` and is served by GitHub Pages from the `main` branch.

Run locally:

```sh
python3 -m http.server 8001 -d docs
```

Open:

```txt
http://127.0.0.1:8001/
```

The web app is configured to use the public Railway backend.

## Swift App

Open the Xcode project:

```txt
Sentience/Sentience.xcodeproj
```

The Swift app now points to the public Railway backend for:

- Auth/account/trading calls in `BackendAPI.swift`
- Quote/chart calls in `APIClient.swift`

If Xcode Previews time out, try running the app with the Xcode Play button first. Preview launch timeouts can come from simulator state even when the app builds successfully.

## Deploy

Deploy backend changes:

```sh
cd Sentience-backend
railway up --detach
```

Deploy web changes:

```sh
git push origin main
```

GitHub Pages publishes from `docs/`.
