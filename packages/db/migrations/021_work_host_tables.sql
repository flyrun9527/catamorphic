-- @catamorphic-product work
-- The Work server's host tables carry its product prefix (ADR 0160).
-- IF EXISTS / IF NOT EXISTS keep this file safe when a host first migrated
-- with product=core: 001 recorded without creating the stock_ tables, so
-- enabling Work later has nothing to rename (ADR 0310).
ALTER TABLE IF EXISTS stock_project_access_requests RENAME TO work_project_access_requests;
ALTER TABLE IF EXISTS work_project_access_requests RENAME CONSTRAINT stock_project_access_requests_status_check TO work_project_access_requests_status_check;
ALTER TABLE IF EXISTS work_project_access_requests RENAME CONSTRAINT stock_project_access_requests_pkey TO work_project_access_requests_pkey;
ALTER TABLE IF EXISTS work_project_access_requests RENAME CONSTRAINT stock_project_access_requests_project_id_fkey TO work_project_access_requests_project_id_fkey;
ALTER INDEX IF EXISTS idx_stock_project_access_requests_project_status RENAME TO idx_work_project_access_requests_project_status;
ALTER INDEX IF EXISTS uq_stock_project_access_requests_pending RENAME TO uq_work_project_access_requests_pending;

ALTER TABLE IF EXISTS stock_project_admission_policies RENAME TO work_project_admission_policies;
ALTER TABLE IF EXISTS work_project_admission_policies RENAME CONSTRAINT stock_project_admission_policies_mode_check TO work_project_admission_policies_mode_check;
ALTER TABLE IF EXISTS work_project_admission_policies RENAME CONSTRAINT stock_project_admission_policies_pkey TO work_project_admission_policies_pkey;
ALTER TABLE IF EXISTS work_project_admission_policies RENAME CONSTRAINT stock_project_admission_policies_project_id_fkey TO work_project_admission_policies_project_id_fkey;

ALTER TABLE IF EXISTS stock_project_invitations RENAME TO work_project_invitations;
ALTER TABLE IF EXISTS work_project_invitations RENAME CONSTRAINT stock_project_invitations_pkey TO work_project_invitations_pkey;
ALTER TABLE IF EXISTS work_project_invitations RENAME CONSTRAINT stock_project_invitations_project_id_fkey TO work_project_invitations_project_id_fkey;
ALTER INDEX IF EXISTS idx_stock_project_invitations_project RENAME TO idx_work_project_invitations_project;

CREATE TABLE IF NOT EXISTS work_project_access_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    external_user_id text NOT NULL,
    email text NOT NULL,
    email_verified boolean NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    decided_by_external_user_id text,
    decided_at timestamp with time zone,
    CONSTRAINT work_project_access_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'denied'::text]))),
    CONSTRAINT work_project_access_requests_pkey PRIMARY KEY (id),
    CONSTRAINT work_project_access_requests_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_work_project_access_requests_project_status ON work_project_access_requests USING btree (project_id, status, requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_work_project_access_requests_pending ON work_project_access_requests USING btree (project_id, external_user_id) WHERE (status = 'pending'::text);

CREATE TABLE IF NOT EXISTS work_project_admission_policies (
    project_id uuid NOT NULL,
    mode text NOT NULL,
    default_role text NOT NULL,
    approved_domains jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_by_external_user_id text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT work_project_admission_policies_mode_check CHECK ((mode = ANY (ARRAY['invitation_only'::text, 'approved_domain'::text, 'request'::text, 'open'::text]))),
    CONSTRAINT work_project_admission_policies_pkey PRIMARY KEY (project_id),
    CONSTRAINT work_project_admission_policies_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS work_project_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    invited_email text,
    roles jsonb NOT NULL,
    grants jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_external_user_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    redeemed_by_external_user_id text,
    redeemed_at timestamp with time zone,
    CONSTRAINT work_project_invitations_pkey PRIMARY KEY (id),
    CONSTRAINT work_project_invitations_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_work_project_invitations_project ON work_project_invitations USING btree (project_id, created_at DESC);
