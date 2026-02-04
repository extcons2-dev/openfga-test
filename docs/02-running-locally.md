# 02 – Running locally

## Opzione A: Docker (quick)
```bash
docker run --rm -p 8080:8080 -p 8081:8081 -p 3000:3000 openfga/openfga run
```

- HTTP API: `http://localhost:8080`
- gRPC: `localhost:8081`
- Playground: `http://localhost:3000/playground` (se abilitato)

## Opzione B: OpenFGA già disponibile (dev/stage)
Imposta:
- `FGA_API_URL`
- `FGA_API_TOKEN` (se richiesto)
- `FGA_STORE_ID` (se vuoi riusare uno store esistente)
