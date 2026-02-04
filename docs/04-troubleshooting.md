# 04 – Troubleshooting

## 1) Errori di connessione
- Verifica `FGA_API_URL`
- Se usi Docker: controlla che la porta 8080 sia esposta
- Prova: `curl -sS http://localhost:8080/healthz` (se configurato)

## 2) Errori di autenticazione
Se l’istanza richiede auth, imposta `FGA_API_TOKEN`.

## 3) Errori su conditions / context
Se una relazione ha un condition, il `context` deve includere i parametri richiesti.
In questo repo, serve `current_time` nelle request di check/list-objects.

## 4) “expected true” ma ritorna false
Tipico: la finestra temporale non include `current_time`.
- controlla `INTERNAL_START_TIME/INTERNAL_END_TIME`
- controlla `APPT_START_TIME/APPT_END_TIME`

Gli script se non trovano tali variabili, generano automaticamente finestre attorno a “now”.

## 5) Tech support e “dati in chiaro”
La richiesta cliente è: “tech support non accede ai dati applicativi in chiaro”.
OpenFGA governa *autorizzazioni*; per “mascheramento”:
- esponi endpoint dedicati per tech support (log/metriche, operazioni tecniche)
- evita endpoint che ritornano dettagli paziente/contabilità al tech support
