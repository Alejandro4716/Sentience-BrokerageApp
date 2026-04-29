# Deploy Sentience Backend

This backend is ready for Railway or another Docker-based host.

## Railway

1. Create a new Railway project from the GitHub repo:
   `Alejandro4716/Sentience-BrokerageApp`
2. Set the service root directory to:
   `/Sentience-backend`
3. Add a PostgreSQL database service.
4. Set these variables on the backend service:

```txt
DATABASE_URL=${{Postgres.DATABASE_URL}}
FINNHUB_API_KEY=your_finnhub_key
JWT_SECRET=generate_a_long_random_secret
FRONTEND_ORIGINS=https://alejandro4716.github.io
```

5. Generate a public Railway domain for the backend service.
6. Confirm the backend responds at:
   `https://your-backend-domain/`

After the backend is public, update `docs/app.js` in the repo:

```js
const BACKEND_BASE = "https://your-backend-domain";
```

Then commit and push so GitHub Pages talks to the public backend.
