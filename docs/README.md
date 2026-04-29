# Sentience Web Client

Static website that mirrors the Swift Sentience brokerage app and connects to the existing FastAPI backend.

## Run

Backend:

```sh
cd /Users/amorel/Desktop/Sentience-BrokerageApp/Sentience-backend
docker compose up --build
```

Website:

```sh
cd /Users/amorel/Documents/Codex/2026-04-29/files-mentioned-by-the-user-creator
python3 -m http.server 8001
```

Open:

```txt
http://127.0.0.1:8001/
```

The website expects the backend at `http://127.0.0.1:8000`.
