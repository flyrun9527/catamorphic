#!/usr/bin/env node
import { runMigrate } from "./migrate.js";
import { runReset } from "./reset.js";
import { parseSchemaProduct } from "./schema-product.js";
import { runStatus } from "./status.js";

const command = process.argv[2] ?? "migrate";
const productFlag = readFlag("--product");
if (productFlag !== undefined) {
  process.env.CATAMORPHIC_DB_PRODUCT = parseSchemaProduct(productFlag);
}

switch (command) {
  case "migrate":
    await runMigrate();
    break;
  case "status":
    await runStatus();
    break;
  case "reset":
    await runReset();
    break;
  default:
    console.error(
      "Usage: catamorphic-db <migrate|status|reset> [--product=core|all]",
    );
    process.exit(1);
}

function readFlag(name: string): string | undefined {
  const prefix = `${name}=`;
  const args = process.argv.slice(3);
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === undefined) continue;
    if (arg.startsWith(prefix)) return arg.slice(prefix.length);
    if (arg === name) return args[i + 1];
  }
  return undefined;
}
