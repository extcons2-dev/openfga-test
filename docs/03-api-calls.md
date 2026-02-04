# 03 – API calls: cosa fanno gli script

Gli script eseguono sempre lo stesso ordine:

1) `POST /stores` (se non hai `FGA_STORE_ID`)
2) `POST /stores/{store_id}/authorization-models` (carica `model/crm_model.json`)
3) `POST /stores/{store_id}/write` (scrive tuple demo; idempotente con `on_duplicate=ignore`)
4) `POST /stores/{store_id}/check` (test permessi)
5) `POST /stores/{store_id}/list-objects` (mostra oggetti accessibili)

## Check con context (ABAC)
Tutte le chiamate di check passano:
```json
{ "context": { "current_time": "2026-02-04T12:34:56Z" } }
```

Perché le tuple `care_internal` e `practitioner` hanno la condition `active_window`.

## Idempotenza
Gli script usano:
```json
"on_duplicate": "ignore"
```
così puoi rilanciarli senza errori anche se tuple già presenti.
