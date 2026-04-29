# Sentience Web Client

Static website that mirrors the Swift Sentience brokerage app and connects to the public FastAPI backend on Railway.

Live site:

```txt
https://alejandro4716.github.io/Sentience-BrokerageApp/
```

Backend:

```txt
https://sentience-brokerageapp-production.up.railway.app/
```

Market data is proxied through the backend. Quotes use Finnhub, while chart candles fall back to Yahoo Finance chart data when Finnhub candle access is unavailable.

## Run

Run the static site locally:

```sh
cd /Users/amorel/Desktop/Sentience-BrokerageApp
python3 -m http.server 8001 -d docs
```

Open:

```txt
http://127.0.0.1:8001/
```

## Backend

```sh
cd /Users/amorel/Desktop/Sentience-BrokerageApp/Sentience-backend
docker compose up --build
```

The production website expects the backend at:

```txt
https://sentience-brokerageapp-production.up.railway.app/
```
