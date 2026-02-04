# Docs – Overview

## Obiettivo
Tradurre le richieste cliente (CRM odontoiatrico) in un modello OpenFGA:
- **RBAC** per macro-domini
- **ABAC** per vincoli dinamici (relazione di cura / contesto appuntamento / finestra temporale)
- isolamento del ruolo **AGENT** dal dominio paziente-centrico

## Tre domini dati
1) Sanitario (`clinical_record`)
2) Amministrativo (`admin_record`, `billing_record`)
3) Magazzino/Ordini (`inventory_item`, `purchase_order`)

## Oggetti principali
- `clinic:<id>` = tenant/studio
- `patient:<id>`
- `appointment:<id>`
- `clinical_record:<id>`
- `admin_record:<id>`
- `inventory_item:<id>`

## Principio operativo
Un endpoint applicativo deve chiamare OpenFGA con:
- `check(user, relation, object, context)`
- `list-objects(user, relation, type, context)` per costruire query sicure server-side

Il *context* include `current_time` perché le assegnazioni sono time-bound.

Vedi: `01-modeling.md` e `03-api-calls.md`.
