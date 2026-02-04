# Caricamento alternativo del modello (testuale/DSL)

Questo repo include:
- `model/crm_model.fga` (DSL)
- `model/crm_model.json` (JSON)

## Opzione 1: Playground
Se hai il Playground abilitato (es. in locale):
1) apri `http://localhost:3000/playground`
2) vai nella sezione “Model”
3) incolla il contenuto di `model/crm_model.fga` e salva

## Opzione 2: API diretta (curl)
Usa `model/crm_model.json` perché l’API accetta JSON:

```bash
curl -X POST "$FGA_API_URL/stores/$FGA_STORE_ID/authorization-models" \
  -H "content-type: application/json" \
  -d @model/crm_model.json
```

## Opzione 3: Rigenerare JSON a partire dal DSL
Se modifichi la DSL e vuoi rigenerare il JSON automaticamente:

```bash
cd tools
npm install
node dsl_to_json.js ../model/crm_model.fga ../model/crm_model.generated.json
```

Poi puoi usare `crm_model.generated.json` per caricare via API.
