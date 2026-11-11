-- @catamorphic-product work
-- Machine classes, pools and retention (ADR 0205).

-- The machine reconciler runs under a replica claim (ADR 0193) named for
-- its tenant; its own lease table goes.
DROP TABLE IF EXISTS work_machine_reconciler;

-- Hosts that first migrated with product=core recorded 024 without its Work
-- tables. Recreate the 024 shape so the rest of this file can add pool
-- columns (ADR 0310).
CREATE TABLE IF NOT EXISTS work_workers (
    node_id text PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenants(id),
    name text NOT NULL,
    credential_hash text NOT NULL,
    labels jsonb DEFAULT '{}'::jsonb NOT NULL,
    access jsonb DEFAULT '{"everyone": true}'::jsonb NOT NULL,
    trusted boolean DEFAULT false NOT NULL,
    machine_rule text,
    machine_ref text,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone,
    revoked_at timestamp with time zone
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_work_workers_name ON work_workers USING btree (tenant_id, name);

CREATE TABLE IF NOT EXISTS work_worker_enrollments (
    code_hash text PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenants(id),
    name text NOT NULL,
    labels jsonb DEFAULT '{}'::jsonb NOT NULL,
    access jsonb DEFAULT '{"everyone": true}'::jsonb NOT NULL,
    trusted boolean DEFAULT false NOT NULL,
    machine_rule text,
    machine_ref text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS work_machine_rules (
    name text NOT NULL,
    tenant_id uuid NOT NULL REFERENCES tenants(id),
    definition jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (tenant_id, name)
);

-- A pooled machine is one the operator enrolled with "pool": true. It
-- takes no work until a machine rule assigns it, recorded as the rule
-- (`machine_rule`) and either the member it serves (`machine_member`, a
-- user id) or its place among the group's shared machines (`machine_slot`).
ALTER TABLE IF EXISTS work_worker_enrollments
    ADD COLUMN pool boolean DEFAULT false NOT NULL;

ALTER TABLE IF EXISTS work_workers
    ADD COLUMN pool boolean DEFAULT false NOT NULL,
    ADD COLUMN machine_member text,
    ADD COLUMN machine_slot integer,
    -- A released machine serves nobody at once and keeps its disk for its
    -- rule's retention (`retain_days`, recorded so it outlives the rule);
    -- then it is destroyed, or reset and returned to its pool.
    ADD COLUMN released_at timestamp with time zone,
    ADD COLUMN retain_days integer;

-- One machine per member or shared place of a rule at a time.
CREATE UNIQUE INDEX IF NOT EXISTS uq_work_workers_machine_member
    ON work_workers (tenant_id, machine_rule, machine_member)
    WHERE machine_member IS NOT NULL
      AND released_at IS NULL
      AND revoked_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_work_workers_machine_slot
    ON work_workers (tenant_id, machine_rule, machine_slot)
    WHERE machine_slot IS NOT NULL
      AND released_at IS NULL
      AND revoked_at IS NULL;
