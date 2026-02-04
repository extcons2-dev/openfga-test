#!/usr/bin/env python3
"""OpenFGA demo: create store -> write model -> write tuples -> checks -> list-objects.

This script performs the same sequence of API calls as scripts/openfga_setup_and_test.sh,
but implemented in Python (requests).

Requirements:
  pip install -r requirements.txt
"""

import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone, timedelta

import requests


def load_dotenv(path: str = ".env") -> None:
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            os.environ.setdefault(k, v)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def iso_now() -> str:
    return iso_utc(datetime.now(timezone.utc))


@dataclass
class OpenFGA:
    api_url: str
    token: str | None = None

    def __post_init__(self) -> None:
        self.api_url = self.api_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"content-type": "application/json"})
        if self.token:
            self.session.headers.update({"Authorization": f"Bearer {self.token}"})

    def post(self, path: str, body: dict) -> dict:
        url = f"{self.api_url}{path}"
        r = self.session.post(url, data=json.dumps(body))
        if r.status_code >= 400:
            raise RuntimeError(f"POST {path} -> {r.status_code}\n{r.text}")
        return r.json() if r.text else {}


def must_get(key: str) -> str:
    v = os.getenv(key)
    if not v:
        raise RuntimeError(f"Missing env var: {key}")
    return v


def main() -> int:
    load_dotenv()

    api_url = must_get("FGA_API_URL")
    model_file = must_get("FGA_MODEL_FILE")
    token = os.getenv("FGA_API_TOKEN") or None

    fga = OpenFGA(api_url, token)

    store_id = os.getenv("FGA_STORE_ID") or ""
    store_name = os.getenv("FGA_STORE_NAME") or "crm-odontoiatrico-demo"

    # 1) Create store if needed
    if not store_id:
        print("== CREATE STORE ==")
        resp = fga.post("/stores", {"name": store_name})
        print(json.dumps(resp, indent=2))
        store_id = resp.get("id") or (resp.get("store") or {}).get("id")
        if not store_id:
            raise RuntimeError("Could not parse store id")
    else:
        print(f"== USING EXISTING STORE: {store_id} ==")

    # 2) Write model
    print("\n== WRITE AUTHORIZATION MODEL ==")
    with open(model_file, "r", encoding="utf-8") as f:
        model_json = json.load(f)

    model_resp = fga.post(f"/stores/{store_id}/authorization-models", model_json)
    print(json.dumps(model_resp, indent=2))
    model_id = model_resp.get("authorization_model_id") or model_resp.get("authorizationModelId")
    if not model_id:
        raise RuntimeError("Could not parse authorization_model_id")

    with open(".openfga_state", "w", encoding="utf-8") as f:
        f.write(f"FGA_API_URL={api_url}\nFGA_STORE_ID={store_id}\nFGA_MODEL_ID={model_id}\n")
    print("Saved .openfga_state")

    # IDs
    clinic_id = os.getenv("CLINIC_ID", "clinicA")
    patient_id = os.getenv("PATIENT_ID", "pat1")
    appt_id = os.getenv("APPOINTMENT_ID", "appt1")
    cr_id = os.getenv("CLINICAL_RECORD_ID", "cr1")
    ar_id = os.getenv("ADMIN_RECORD_ID", "ar1")
    inv_id = os.getenv("INVENTORY_ITEM_ID", "item1")

    # users
    users = {
        "owner": os.getenv("USER_OWNER", "owner1"),
        "dentist_int": os.getenv("USER_DENTIST_INT", "dentistInt1"),
        "dentist_ext": os.getenv("USER_DENTIST_EXT", "dentistExt1"),
        "hyg_int": os.getenv("USER_HYG_INT", "hygInt1"),
        "hyg_ext": os.getenv("USER_HYG_EXT", "hygExt1"),
        "aso": os.getenv("USER_ASO", "aso1"),
        "reception": os.getenv("USER_RECEPTION", "reception1"),
        "office_manager": os.getenv("USER_OFFICE_MANAGER", "officeMgr1"),
        "agent": os.getenv("USER_AGENT", "agent1"),
        "tech": os.getenv("USER_TECH", "tech1"),
    }

    clinic_obj = f"clinic:{clinic_id}"
    patient_obj = f"patient:{patient_id}"
    appt_obj = f"appointment:{appt_id}"
    cr_obj = f"clinical_record:{cr_id}"
    ar_obj = f"admin_record:{ar_id}"
    inv_obj = f"inventory_item:{inv_id}"

    now_dt = datetime.now(timezone.utc)
    now = iso_utc(now_dt)

    # windows: read from env or generate
    internal_start = os.getenv("INTERNAL_START_TIME") or iso_utc(now_dt - timedelta(days=30))
    internal_end = os.getenv("INTERNAL_END_TIME") or iso_utc(now_dt + timedelta(days=365))
    appt_start = os.getenv("APPT_START_TIME") or iso_utc(now_dt - timedelta(hours=1))
    appt_end = os.getenv("APPT_END_TIME") or iso_utc(now_dt + timedelta(hours=2))

    # 3) Write tuples
    print("\n== WRITE TUPLES ==")
    tuples = [
        # roles on clinic
        {"user": f"user:{users['owner']}", "relation": "owner_dentist", "object": clinic_obj},
        {"user": f"user:{users['dentist_int']}", "relation": "dentist_internal", "object": clinic_obj},
        {"user": f"user:{users['dentist_ext']}", "relation": "dentist_external", "object": clinic_obj},
        {"user": f"user:{users['hyg_int']}", "relation": "hygienist_internal", "object": clinic_obj},
        {"user": f"user:{users['hyg_ext']}", "relation": "hygienist_external", "object": clinic_obj},
        {"user": f"user:{users['aso']}", "relation": "aso", "object": clinic_obj},
        {"user": f"user:{users['reception']}", "relation": "reception", "object": clinic_obj},
        {"user": f"user:{users['office_manager']}", "relation": "office_manager", "object": clinic_obj},
        {"user": f"user:{users['agent']}", "relation": "agent", "object": clinic_obj},
        {"user": f"user:{users['tech']}", "relation": "tech_support", "object": clinic_obj},

        # links
        {"user": clinic_obj, "relation": "clinic", "object": patient_obj},

        {"user": clinic_obj, "relation": "clinic", "object": appt_obj},
        {"user": patient_obj, "relation": "patient", "object": appt_obj},

        {"user": clinic_obj, "relation": "clinic", "object": cr_obj},
        {"user": patient_obj, "relation": "patient", "object": cr_obj},
        {"user": appt_obj, "relation": "appointment", "object": cr_obj},

        {"user": clinic_obj, "relation": "clinic", "object": ar_obj},
        {"user": clinic_obj, "relation": "clinic", "object": inv_obj},

        # ABAC internal assignment window
        {
            "user": f"user:{users['dentist_int']}",
            "relation": "care_internal",
            "object": patient_obj,
            "condition": {"name": "active_window", "context": {"start_time": internal_start, "end_time": internal_end}},
        },
        {
            "user": f"user:{users['aso']}",
            "relation": "care_internal",
            "object": patient_obj,
            "condition": {"name": "active_window", "context": {"start_time": internal_start, "end_time": internal_end}},
        },
        {
            "user": f"user:{users['office_manager']}",
            "relation": "care_internal",
            "object": patient_obj,
            "condition": {"name": "active_window", "context": {"start_time": internal_start, "end_time": internal_end}},
        },

        # ABAC external appointment window
        {
            "user": f"user:{users['dentist_ext']}",
            "relation": "practitioner",
            "object": appt_obj,
            "condition": {"name": "active_window", "context": {"start_time": appt_start, "end_time": appt_end}},
        },
    ]

    write_body = {
        "authorization_model_id": model_id,
        "writes": {"on_duplicate": "ignore", "tuple_keys": tuples},
    }
    write_resp = fga.post(f"/stores/{store_id}/write", write_body)
    print(json.dumps(write_resp, indent=2))

    ctx = {"current_time": now}

    # 4) Checks
    def check(user: str, relation: str, obj: str) -> bool:
        body = {
            "authorization_model_id": model_id,
            "tuple_key": {"user": user, "relation": relation, "object": obj},
            "context": ctx,
        }
        resp = fga.post(f"/stores/{store_id}/check", body)
        print(json.dumps(resp, indent=2))
        return bool(resp.get("allowed"))

    print("\n== CHECKS ==")
    print("# 1) dentist_internal can_read clinical_record (expected true)")
    check(f"user:{users['dentist_int']}", "can_read", cr_obj)

    print("# 2) ASO can_read clinical_record (true) but can_write (false)")
    check(f"user:{users['aso']}", "can_read", cr_obj)
    check(f"user:{users['aso']}", "can_write", cr_obj)

    print("# 3) dentist_external can_write clinical_record via appointment window (expected true)")
    check(f"user:{users['dentist_ext']}", "can_write", cr_obj)

    print("# 4) agent cannot read admin_record (false) but can_write inventory_item (true)")
    check(f"user:{users['agent']}", "can_read", ar_obj)
    check(f"user:{users['agent']}", "can_write", inv_obj)

    # 5) list-objects
    print("\n== LIST OBJECTS ==")
    lo_body = {
        "authorization_model_id": model_id,
        "type": "clinical_record",
        "relation": "can_read",
        "user": f"user:{users['dentist_int']}",
        "context": ctx,
    }
    lo_resp = fga.post(f"/stores/{store_id}/list-objects", lo_body)
    print(json.dumps(lo_resp, indent=2))

    print(f"\nDONE. Store={store_id} Model={model_id} Now={now}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        raise
