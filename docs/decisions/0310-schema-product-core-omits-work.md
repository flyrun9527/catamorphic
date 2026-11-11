# 0310 — Schema product core omits Work tables

- **Status:** Accepted
- **Date:** 2026-11-11
- **Amends:** 0003, 0160

## Context

`@catamorphic/db` applies one SQL stream. Embedders that compose
`@catamorphic/server-sdk` without `@catamorphic/work-server` still receive
every `work_*` table: company identity, shares, GitHub App registration, and
the Work control plane. Runtime already treats Work as optional. The schema
did not.

Hosts that later enable Work must reach the same tables as a host that
migrated with the full product from the first boot.

## Decision

`migrateToLatest` and `catamorphic.migrate()` take a schema product,
`"core"` or `"all"`. The default is `"all"`, so existing hosts keep today's
full schema. `"core"` omits Work tables.

Work-only files start with `-- @catamorphic-product work`. Mixed files wrap
Work statements in `-- @catamorphic-product-begin work` /
`-- @catamorphic-product-end`. Untagged SQL is core.

When the product is `"core"`, Work-only files are skipped and not recorded, so
a later migrate with `"all"` still applies them. Mixed files run with Work
blocks stripped and are recorded.

`021`, `048`, `057`, and `058` use `IF EXISTS` / `IF NOT EXISTS` so those
Work-only files are safe after a core migrate, when mixed predecessors were
recorded without their Work statements. `078_work_control_plane_if_missing.sql`
creates the latest `work_workers`, `work_worker_enrollments`, and
`work_machine_rules` shapes and `work_accounts.administrator` when those
objects are missing.

CLI: `CATAMORPHIC_DB_PRODUCT=core` or `catamorphic-db migrate --product=core`.
SDK: `createCatamorphic({ schemaProduct: "core" })`.

Considered: a second migration directory, or recording skipped Work files and
squashing the Work schema into one catch-up file. The first splits the stream
hosts already run. The second hides the original Work migrations from a later
enable. Markers plus skip-without-recording keep one stream and leave Work
files as the source of truth.

## Consequences

Kernel embeds no longer create empty Work tables. Enabling Work later applies
the skipped files and the mixed-file catch-up. Default migrate behavior is
unchanged. Generated Kysely types still describe the full schema; a core host
must not query `work_*` tables. Future Work DDL belongs in a Work-only file or
a marked block, and mixed files that later hosts may enable against need
`IF EXISTS` safety or a follow-up catch-up file.
