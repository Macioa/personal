-- Login credentials vault + application join

CREATE TABLE logins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL,
  password text NOT NULL,
  login_url text,
  oauth boolean NOT NULL DEFAULT false,
  oauth_email text
);

CREATE TABLE application_logins (
  application_id uuid NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  login_id uuid NOT NULL REFERENCES logins (id) ON DELETE CASCADE,
  PRIMARY KEY (application_id, login_id)
);

CREATE INDEX application_logins_login_id_idx
  ON application_logins (login_id);

-- MCP-only access (match existing public tables)
ALTER TABLE public.logins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_logins ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.logins FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_logins FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.logins FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_logins FROM anon, authenticated;
