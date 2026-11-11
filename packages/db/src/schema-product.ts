export const SCHEMA_PRODUCTS = ["core", "all"] as const;
export type SchemaProduct = (typeof SCHEMA_PRODUCTS)[number];
export const DEFAULT_SCHEMA_PRODUCT: SchemaProduct = "all";

/** Product a migration file or block belongs to. Untagged SQL is core. */
export type MigrationProduct = "core" | "work";

const FILE_PRODUCT = /^--\s*@catamorphic-product\s+(core|work)\s*$/;
const BLOCK_BEGIN = /^--\s*@catamorphic-product-begin\s+(core|work)\s*$/;
const BLOCK_END = /^--\s*@catamorphic-product-end\s*$/;

export function isSchemaProduct(value: string): value is SchemaProduct {
  return value === "core" || value === "all";
}

export function parseSchemaProduct(value: string | undefined): SchemaProduct {
  const raw = value ?? DEFAULT_SCHEMA_PRODUCT;
  if (isSchemaProduct(raw)) return raw;
  throw new Error(`Invalid schema product "${raw}". Use "core" or "all".`);
}

export function resolveSchemaProduct(): SchemaProduct {
  return parseSchemaProduct(process.env.CATAMORPHIC_DB_PRODUCT);
}

/**
 * File-level product marker. The first `-- @catamorphic-product <name>` line
 * wins. Block markers are ignored here.
 */
export function fileSchemaProduct(sqlText: string): MigrationProduct | null {
  for (const line of sqlText.split("\n")) {
    const match = FILE_PRODUCT.exec(line);
    if (match?.[1] === "core" || match?.[1] === "work") return match[1];
  }
  return null;
}

/**
 * Work-only files are skipped entirely when `product` is `"core"` so a later
 * migrate with `"all"` can still apply them. Mixed files always apply.
 */
export function shouldApplyMigrationFile(
  sqlText: string,
  product: SchemaProduct,
): boolean {
  if (product === "all") return true;
  return fileSchemaProduct(sqlText) !== "work";
}

/**
 * For `"core"`, drop Work product blocks. `"all"` returns the file unchanged
 * so markers stay comments.
 */
export function sqlForSchemaProduct(
  sqlText: string,
  product: SchemaProduct,
): string {
  if (product === "all") return sqlText;
  return stripProductBlocks(sqlText, "work");
}

function stripProductBlocks(sqlText: string, omit: MigrationProduct): string {
  const lines = sqlText.split("\n");
  const out: string[] = [];
  let skipping: MigrationProduct | null = null;
  let lineNumber = 0;
  for (const line of lines) {
    lineNumber += 1;
    const begin = BLOCK_BEGIN.exec(line);
    if (begin) {
      if (skipping) {
        throw new Error(
          `Nested @catamorphic-product-begin on line ${lineNumber} while already in a ${skipping} block`,
        );
      }
      const block = begin[1];
      if (block !== "core" && block !== "work") {
        throw new Error(
          `Unknown @catamorphic-product-begin product on line ${lineNumber}`,
        );
      }
      if (block === omit) skipping = block;
      continue;
    }
    if (BLOCK_END.test(line)) {
      skipping = null;
      continue;
    }
    if (skipping) continue;
    out.push(line);
  }
  if (skipping) {
    throw new Error(`Unclosed @catamorphic-product-begin ${skipping} block`);
  }
  return out.join("\n");
}
