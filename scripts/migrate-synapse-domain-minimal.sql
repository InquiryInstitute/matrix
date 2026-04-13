-- Minimal MXID domain rename (PostgreSQL) — stop Synapse first.
-- Only safe on lightly populated servers; backup DB before use.
-- After: set server_name + public_baseurl in homeserver.yaml to the NEW domain, then start Synapse.
-- Example: inquiry → castalia (applied on production 2026-04 when DB had 2 users, 0 rooms)

BEGIN;

UPDATE access_tokens SET user_id = replace(user_id, 'matrix.inquiry.institute', 'matrix.castalia.institute')
  WHERE user_id LIKE '%matrix.inquiry.institute%';
UPDATE devices SET user_id = replace(user_id, 'matrix.inquiry.institute', 'matrix.castalia.institute')
  WHERE user_id LIKE '%matrix.inquiry.institute%';
UPDATE users SET name = replace(name, 'matrix.inquiry.institute', 'matrix.castalia.institute')
  WHERE name LIKE '%matrix.inquiry.institute%';

-- Add more UPDATEs for any table with user_id rows (see information_schema) if your DB is larger.

COMMIT;
