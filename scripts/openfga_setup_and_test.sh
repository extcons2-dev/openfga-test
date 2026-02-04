#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# OpenFGA demo: create store -> write model -> write tuples -> checks -> list-objects
#
# Requirements: bash, curl, jq
# ------------------------------------------------------------

# Load .env if present
if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need curl
need jq
need date

: "${FGA_API_URL:?Missing FGA_API_URL}"
: "${FGA_MODEL_FILE:?Missing FGA_MODEL_FILE}"

AUTH_ARGS=()
if [[ -n "${FGA_API_TOKEN:-}" ]]; then
  AUTH_ARGS=(-H "Authorization: Bearer ${FGA_API_TOKEN}")
fi

post() {
  local url="$1"
  local data="$2"
  curl -sS -X POST "$url" "${AUTH_ARGS[@]}" -H "content-type: application/json" -d "$data"
}

post_file() {
  local url="$1"
  local file="$2"
  curl -sS -X POST "$url" "${AUTH_ARGS[@]}" -H "content-type: application/json" --data-binary "@${file}"
}

hr() { echo; echo "==================== $* ===================="; }

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# 1) Create store (if missing)
if [[ -z "${FGA_STORE_ID:-}" ]]; then
  hr "CREATE STORE"
  name="${FGA_STORE_NAME:-crm-odontoiatrico-demo}"
  resp="$(post "${FGA_API_URL}/stores" "{"name":"${name}"}")"
  echo "$resp" | jq .
  FGA_STORE_ID="$(echo "$resp" | jq -r '.id // .store.id')"
  [[ -n "$FGA_STORE_ID" && "$FGA_STORE_ID" != "null" ]] || { echo "Could not parse store id" >&2; exit 1; }
else
  hr "USING EXISTING STORE"
  echo "FGA_STORE_ID=${FGA_STORE_ID}"
fi

# 2) Write authorization model
hr "WRITE AUTHORIZATION MODEL"
model_resp="$(post_file "${FGA_API_URL}/stores/${FGA_STORE_ID}/authorization-models" "${FGA_MODEL_FILE}")"
echo "$model_resp" | jq .
FGA_MODEL_ID="$(echo "$model_resp" | jq -r '.authorization_model_id // .authorizationModelId')"
[[ -n "$FGA_MODEL_ID" && "$FGA_MODEL_ID" != "null" ]] || { echo "Could not parse authorization_model_id" >&2; exit 1; }

cat > .openfga_state <<EOF
FGA_API_URL=${FGA_API_URL}
FGA_STORE_ID=${FGA_STORE_ID}
FGA_MODEL_ID=${FGA_MODEL_ID}
EOF
echo "Saved .openfga_state"

# IDs
CLINIC_ID="${CLINIC_ID:-clinicA}"
PATIENT_ID="${PATIENT_ID:-pat1}"
APPOINTMENT_ID="${APPOINTMENT_ID:-appt1}"
CLINICAL_RECORD_ID="${CLINICAL_RECORD_ID:-cr1}"
ADMIN_RECORD_ID="${ADMIN_RECORD_ID:-ar1}"
INVENTORY_ITEM_ID="${INVENTORY_ITEM_ID:-item1}"

# Users
USER_OWNER="${USER_OWNER:-owner1}"
USER_DENTIST_INT="${USER_DENTIST_INT:-dentistInt1}"
USER_DENTIST_EXT="${USER_DENTIST_EXT:-dentistExt1}"
USER_HYG_INT="${USER_HYG_INT:-hygInt1}"
USER_HYG_EXT="${USER_HYG_EXT:-hygExt1}"
USER_ASO="${USER_ASO:-aso1}"
USER_RECEPTION="${USER_RECEPTION:-reception1}"
USER_OFFICE_MANAGER="${USER_OFFICE_MANAGER:-officeMgr1}"
USER_AGENT="${USER_AGENT:-agent1}"
USER_TECH="${USER_TECH:-tech1}"

# Objects
CLINIC_OBJ="clinic:${CLINIC_ID}"
PATIENT_OBJ="patient:${PATIENT_ID}"
APPT_OBJ="appointment:${APPOINTMENT_ID}"
CR_OBJ="clinical_record:${CLINICAL_RECORD_ID}"
AR_OBJ="admin_record:${ADMIN_RECORD_ID}"
INV_OBJ="inventory_item:${INVENTORY_ITEM_ID}"

# ABAC windows: if not set, auto-generate around now
NOW="$(iso_now)"

INTERNAL_START_TIME="${INTERNAL_START_TIME:-}"
INTERNAL_END_TIME="${INTERNAL_END_TIME:-}"
APPT_START_TIME="${APPT_START_TIME:-}"
APPT_END_TIME="${APPT_END_TIME:-}"

if [[ -z "$INTERNAL_START_TIME" || -z "$INTERNAL_END_TIME" ]]; then
  # now - 30 days / now + 365 days (approx)
  INTERNAL_START_TIME="$(date -u -d "${NOW} - 30 days" +"%Y-%m-%dT%H:%M:%SZ")"
  INTERNAL_END_TIME="$(date -u -d "${NOW} + 365 days" +"%Y-%m-%dT%H:%M:%SZ")"
fi

if [[ -z "$APPT_START_TIME" || -z "$APPT_END_TIME" ]]; then
  # now - 1 hour / now + 2 hours
  APPT_START_TIME="$(date -u -d "${NOW} - 1 hour" +"%Y-%m-%dT%H:%M:%SZ")"
  APPT_END_TIME="$(date -u -d "${NOW} + 2 hours" +"%Y-%m-%dT%H:%M:%SZ")"
fi

hr "WRITE TUPLES (RBAC + LINKS + ABAC)"
write_body="$(jq -n   --arg model "$FGA_MODEL_ID"   --arg clinic "$CLINIC_OBJ"   --arg patient "$PATIENT_OBJ"   --arg appt "$APPT_OBJ"   --arg cr "$CR_OBJ"   --arg ar "$AR_OBJ"   --arg inv "$INV_OBJ"   --arg u_owner "user:${USER_OWNER}"   --arg u_di "user:${USER_DENTIST_INT}"   --arg u_de "user:${USER_DENTIST_EXT}"   --arg u_hi "user:${USER_HYG_INT}"   --arg u_he "user:${USER_HYG_EXT}"   --arg u_aso "user:${USER_ASO}"   --arg u_rec "user:${USER_RECEPTION}"   --arg u_mgr "user:${USER_OFFICE_MANAGER}"   --arg u_ag "user:${USER_AGENT}"   --arg u_tech "user:${USER_TECH}"   --arg now "$NOW"   --arg is "$INTERNAL_START_TIME"   --arg ie "$INTERNAL_END_TIME"   --arg as "$APPT_START_TIME"   --arg ae "$APPT_END_TIME" '{
  authorization_model_id: $model,
  writes: {
    on_duplicate: "ignore",
    tuple_keys: [
      # --- RBAC roles on clinic ---
      {user:$u_owner, relation:"owner_dentist", object:$clinic},
      {user:$u_di, relation:"dentist_internal", object:$clinic},
      {user:$u_de, relation:"dentist_external", object:$clinic},
      {user:$u_hi, relation:"hygienist_internal", object:$clinic},
      {user:$u_he, relation:"hygienist_external", object:$clinic},
      {user:$u_aso, relation:"aso", object:$clinic},
      {user:$u_rec, relation:"reception", object:$clinic},
      {user:$u_mgr, relation:"office_manager", object:$clinic},
      {user:$u_ag, relation:"agent", object:$clinic},
      {user:$u_tech, relation:"tech_support", object:$clinic},

      # --- Links ---
      {user:$clinic, relation:"clinic", object:$patient},

      {user:$clinic, relation:"clinic", object:$appt},
      {user:$patient, relation:"patient", object:$appt},

      {user:$clinic, relation:"clinic", object:$cr},
      {user:$patient, relation:"patient", object:$cr},
      {user:$appt, relation:"appointment", object:$cr},

      {user:$clinic, relation:"clinic", object:$ar},
      {user:$clinic, relation:"clinic", object:$inv},

      # --- ABAC internal: care assignment window ---
      {user:$u_di, relation:"care_internal", object:$patient,
        condition:{name:"active_window", context:{start_time:$is, end_time:$ie}}
      },
      {user:$u_aso, relation:"care_internal", object:$patient,
        condition:{name:"active_window", context:{start_time:$is, end_time:$ie}}
      },
      {user:$u_mgr, relation:"care_internal", object:$patient,
        condition:{name:"active_window", context:{start_time:$is, end_time:$ie}}
      },

      # --- ABAC external: appointment window ---
      {user:$u_de, relation:"practitioner", object:$appt,
        condition:{name:"active_window", context:{start_time:$as, end_time:$ae}}
      }
    ]
  }
}')"

write_resp="$(post "${FGA_API_URL}/stores/${FGA_STORE_ID}/write" "$write_body")"
echo "$write_resp" | jq .

ctx_now="$(jq -n --arg now "$NOW" '{current_time:$now}')"

check() {
  local user="$1" rel="$2" obj="$3"
  local body
  body="$(jq -n --arg model "$FGA_MODEL_ID" --arg u "$user" --arg r "$rel" --arg o "$obj" --argjson ctx "$ctx_now"     '{authorization_model_id:$model, tuple_key:{user:$u, relation:$r, object:$o}, context:$ctx}')"
  post "${FGA_API_URL}/stores/${FGA_STORE_ID}/check" "$body" | jq .
}

hr "CHECKS"
echo "# 1) dentist_internal can_read clinical_record (expected true)"
check "user:${USER_DENTIST_INT}" "can_read" "$CR_OBJ"

echo "# 2) ASO can_read clinical_record (expected true) but can_write (expected false)"
check "user:${USER_ASO}" "can_read" "$CR_OBJ"
check "user:${USER_ASO}" "can_write" "$CR_OBJ"

echo "# 3) dentist_external can_write clinical_record via appointment window (expected true)"
check "user:${USER_DENTIST_EXT}" "can_write" "$CR_OBJ"

echo "# 4) agent cannot read admin_record (expected false) but can_write inventory_item (expected true)"
check "user:${USER_AGENT}" "can_read" "$AR_OBJ"
check "user:${USER_AGENT}" "can_write" "$INV_OBJ"

hr "LIST OBJECTS"
echo "# 5) list clinical_records dentist_internal can_read (expected includes clinical_record:${CLINICAL_RECORD_ID})"
list_body="$(jq -n   --arg model "$FGA_MODEL_ID"   --arg type "clinical_record"   --arg rel "can_read"   --arg user "user:${USER_DENTIST_INT}"   --argjson ctx "$ctx_now"   '{authorization_model_id:$model, type:$type, relation:$rel, user:$user, context:$ctx}')"
post "${FGA_API_URL}/stores/${FGA_STORE_ID}/list-objects" "$list_body" | jq .

echo
echo "DONE. Store=${FGA_STORE_ID} Model=${FGA_MODEL_ID} Now=${NOW}"
