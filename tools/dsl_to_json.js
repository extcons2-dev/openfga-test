/**
 * Convert OpenFGA DSL (.fga) to JSON authorization model using @openfga/syntax-transformer.
 *
 * Usage:
 *   npm i
 *   node tools/dsl_to_json.js model/crm_model.fga model/crm_model.generated.json
 */
import fs from "node:fs";
import { transformer } from "@openfga/syntax-transformer";

const [,, inFile, outFile] = process.argv;
if (!inFile || !outFile) {
  console.error("Usage: node tools/dsl_to_json.js <input.fga> <output.json>");
  process.exit(2);
}

const dsl = fs.readFileSync(inFile, "utf8");
const jsonObj = transformer.transformDSLToJSONObject(dsl);
fs.writeFileSync(outFile, JSON.stringify(jsonObj, null, 2), "utf8");
console.log(`Wrote ${outFile}`);
