-- @catamorphic-product work
-- Catch-up for hosts that first migrated with product=core (ADR 0310).
-- Mixed files 024, 027, and 050 were recorded without their Work
-- statements, so enabling Work later cannot recreate those objects from
-- the original files. Create the latest Work control-plane tables and the
-- work_accounts.administrator column if they are missing.

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
    revoked_at timestamp with time zone,
    pool boolean DEFAULT false NOT NULL,
    machine_member text,
    machine_slot integer,
    released_at timestamp with time zone,
    retain_days integer,
    credential_issued_at timestamp with time zone DEFAULT now() NOT NULL,
    pending_credential_hash text,
    pending_public_key text,
    pending_issued_at timestamp with time zone,
    rotation_requested_at timestamp with time zone,
    pending_rotation text,
    machine_destroyed_at timestamp with time zone
);

ALTER TABLE work_workers
    ADD COLUMN IF NOT EXISTS pool boolean DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS machine_member text,
    ADD COLUMN IF NOT EXISTS machine_slot integer,
    ADD COLUMN IF NOT EXISTS released_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS retain_days integer,
    ADD COLUMN IF NOT EXISTS credential_issued_at timestamp with time zone DEFAULT now() NOT NULL,
    ADD COLUMN IF NOT EXISTS pending_credential_hash text,
    ADD COLUMN IF NOT EXISTS pending_public_key text,
    ADD COLUMN IF NOT EXISTS pending_issued_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS rotation_requested_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS pending_rotation text,
    ADD COLUMN IF NOT EXISTS machine_destroyed_at timestamp with time zone;

CREATE UNIQUE INDEX IF NOT EXISTS uq_work_workers_name
    ON work_workers USING btree (tenant_id, name);

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
    used_at timestamp with time zone,
    pool boolean DEFAULT false NOT NULL
);

ALTER TABLE work_worker_enrollments
    ADD COLUMN IF NOT EXISTS pool boolean DEFAULT false NOT NULL;

CREATE TABLE IF NOT EXISTS work_machine_rules (
    name text NOT NULL,
    tenant_id uuid NOT NULL REFERENCES tenants(id),
    definition jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_failure text,
    last_failure_at timestamp with time zone,
    PRIMARY KEY (tenant_id, name)
);

ALTER TABLE work_machine_rules
    ADD COLUMN IF NOT EXISTS last_failure text,
    ADD COLUMN IF NOT EXISTS last_failure_at timestamp with time zone;

ALTER TABLE work_accounts
    ADD COLUMN IF NOT EXISTS administrator boolean DEFAULT false NOT NULL;
