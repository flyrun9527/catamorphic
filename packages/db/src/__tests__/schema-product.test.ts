import { describe, expect, it } from "vitest";
import {
  fileSchemaProduct,
  parseSchemaProduct,
  shouldApplyMigrationFile,
  sqlForSchemaProduct,
} from "../schema-product.js";

const mixed = `
CREATE TABLE worker_node_jobs (id uuid PRIMARY KEY);
-- @catamorphic-product-begin work
CREATE TABLE work_workers (node_id text PRIMARY KEY);
-- @catamorphic-product-end
CREATE TABLE connections (id uuid PRIMARY KEY);
`;

const workFile = `-- @catamorphic-product work
-- Company identity
CREATE TABLE work_accounts (user_id text PRIMARY KEY);
`;

describe("parseSchemaProduct", () => {
  it("defaults to all", () => {
    expect(parseSchemaProduct(undefined)).toBe("all");
  });

  it("accepts core and all", () => {
    expect(parseSchemaProduct("core")).toBe("core");
    expect(parseSchemaProduct("all")).toBe("all");
  });

  it("rejects unknown values", () => {
    expect(() => parseSchemaProduct("desktop")).toThrow(
      /Invalid schema product/,
    );
  });
});

describe("fileSchemaProduct", () => {
  it("reads the file-level marker", () => {
    expect(fileSchemaProduct(workFile)).toBe("work");
  });

  it("ignores block markers", () => {
    expect(fileSchemaProduct(mixed)).toBeNull();
  });

  it("returns null when untagged", () => {
    expect(fileSchemaProduct("CREATE TABLE projects (id uuid);")).toBeNull();
  });
});

describe("shouldApplyMigrationFile", () => {
  it("applies every file for product all", () => {
    expect(shouldApplyMigrationFile(workFile, "all")).toBe(true);
    expect(shouldApplyMigrationFile(mixed, "all")).toBe(true);
  });

  it("skips work-only files for product core", () => {
    expect(shouldApplyMigrationFile(workFile, "core")).toBe(false);
    expect(shouldApplyMigrationFile(mixed, "core")).toBe(true);
  });
});

describe("sqlForSchemaProduct", () => {
  it("leaves SQL unchanged for product all", () => {
    expect(sqlForSchemaProduct(mixed, "all")).toBe(mixed);
    expect(sqlForSchemaProduct(workFile, "all")).toBe(workFile);
  });

  it("strips work blocks for product core", () => {
    const coreSql = sqlForSchemaProduct(mixed, "core");
    expect(coreSql).toContain("CREATE TABLE worker_node_jobs");
    expect(coreSql).toContain("CREATE TABLE connections");
    expect(coreSql).not.toContain("CREATE TABLE work_workers");
    expect(coreSql).not.toContain("@catamorphic-product-begin");
    expect(coreSql).not.toContain("@catamorphic-product-end");
  });

  it("rejects nested product blocks", () => {
    expect(() =>
      sqlForSchemaProduct(
        `-- @catamorphic-product-begin work
CREATE TABLE a (id int);
-- @catamorphic-product-begin work
CREATE TABLE b (id int);
-- @catamorphic-product-end
-- @catamorphic-product-end
`,
        "core",
      ),
    ).toThrow(/Nested @catamorphic-product-begin/);
  });

  it("rejects an unclosed product block", () => {
    expect(() =>
      sqlForSchemaProduct(
        `-- @catamorphic-product-begin work
CREATE TABLE work_accounts (user_id text);
`,
        "core",
      ),
    ).toThrow(/Unclosed @catamorphic-product-begin work/);
  });
});
