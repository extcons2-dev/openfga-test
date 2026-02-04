# 01 – Modeling (RBAC + ABAC)

## RBAC (ruoli sul clinic)
Esempi di tuple:
- `user:u1#dentist_internal@clinic:c1`
- `user:u7#agent@clinic:c1`

Nel modello, queste membership alimentano:
- `clinic#clinical_readers_internal`
- `clinic#admin_writers`
- `clinic#inventory_readers`
ecc.

## ABAC (sanitario)
Per accedere a un `clinical_record` serve:
- Ruolo clinico sullo studio (RBAC)
- Contesto valido (ABAC)

### ABAC per interni
Relazione: `patient#care_internal` (condizionata da finestra temporale)

- Tuple con condition:
  - `patient:p1#care_internal@user:uDentist (start/end)`
- Check con context:
  - `{ "current_time": "..." }`

### ABAC per esterni
Relazione: `appointment#practitioner` o `appointment#aso` (condizionata)

- Tuple con condition:
  - `appointment:a1#practitioner@user:uExternal (start/end)`
- Il record sanitario è legato a un appointment:
  - `clinical_record:r1#appointment@appointment:a1`
- Quindi l’esterno accede **solo** quando è “in servizio” (window valida).

## Nota “LIMITATO” admin
Il cliente distingue “amministrativo” e “economico-contabile”.
In questo repo, `billing_record` segue le stesse policy di `admin_record`.
Se vuoi il “LIMITATO”, restringi `billing_record.can_read/can_write` eliminando alcuni ruoli.
