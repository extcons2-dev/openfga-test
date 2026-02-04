# OpenFGA – CRM Odontoiatrico (RBAC + ABAC) – Demo Repo

Questo repo è un **pacchetto “pronto-da-eseguire”** per:
- caricare un **authorization model** OpenFGA che implementa **RBAC + ABAC** (sanitario / amministrativo / magazzino-ordini)
- scrivere tuple demo (ruoli, relazioni, assegnazioni temporali)
- eseguire chiamate di test (check + list-objects)

## Cosa c’è dentro

- `model/crm_model.fga` → modello **testuale (DSL)**, leggibile e versionabile
- `model/crm_model.json` → lo stesso modello in **JSON** (formato che l’API accetta)
- `scripts/openfga_setup_and_test.sh` → demo **Bash + curl + jq**
- `scripts/openfga_setup_and_test.py` → demo **Python + requests**
- `.env.example` → variabili di configurazione
- `docs/` → documentazione dettagliata
- `tools/dsl_to_json.js` → conversione DSL→JSON con `@openfga/syntax-transformer` (opzionale)

---

## Quickstart (locale)

### 1) Avvia OpenFGA in locale (Docker)
Esempio minimale:

```bash
docker run --rm -p 8080:8080 -p 8081:8081 -p 3000:3000 openfga/openfga run
```

> L’HTTP API è su `http://localhost:8080`.
> Playground (se abilitato) su `http://localhost:3000/playground`.

### 2) Configura le variabili
```bash
cp .env.example .env
# opzionale: modifica FGA_API_URL, token, id, ecc.
```

### 3A) Esegui la demo Bash
```bash
./scripts/openfga_setup_and_test.sh
```

### 3B) Esegui la demo Python
```bash
python3 -m pip install -r requirements.txt
python3 ./scripts/openfga_setup_and_test.py
```

Alla fine entrambi gli script stampano:
- lo **store_id** creato/usato
- l’**authorization_model_id**
- l’esito dei **check**
- l’output di **list-objects**

---

## Come funziona (in 30 secondi)

- **RBAC**: i ruoli sono tuple sullo studio (`clinic:<id>`).
- **ABAC**: per vedere/scrivere un record sanitario (`clinical_record`) serve:
  - ruolo clinico (interno o esterno) sullo studio **e**
  - una relazione **time-bound**:
    - interni: `patient.care_internal` con window valida
    - esterni: `appointment.practitioner` (o `appointment.aso`) con window valida
- **Separazione AGENT**: l’AGENT vive solo in `inventory_*` e non compare nelle relazioni admin/sanitarie.

Dettagli completi in `docs/`.

---

## Note importanti (privacy)
- Non mettere **PII/PHI** nei tuple (`patient:rossi-mario` NO).
- Usa solo ID interni / UUID.

---

## Licenza
Repo demo/boilerplate: usa come base interna e adatta alle tue necessità.
