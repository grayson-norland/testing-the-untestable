-- Schema, roles and grants. Runs once, on first start of an empty database.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE accounts (
    account_code  VARCHAR(10)   PRIMARY KEY,
    name          VARCHAR(60)   NOT NULL,
    status        CHAR(2)       NOT NULL,
    balance       NUMERIC(12,2) NOT NULL,
    date_opened   DATE          NOT NULL,
    branch        CHAR(3)       NOT NULL,
    CONSTRAINT accounts_code_format CHECK (account_code ~ '^ACC[0-9]{3}$'),
    CONSTRAINT accounts_branch_format CHECK (branch ~ '^[0-9]{3}$')
);

CREATE TABLE app_users (
    username       VARCHAR(50) PRIMARY KEY,
    password_hash  TEXT        NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Least privilege: each service gets its own role.
--   cobol_reader : read-only access to accounts
--   auth_service : read-only access to app_users
CREATE ROLE cobol_reader LOGIN PASSWORD 'ledger_read_only';
CREATE ROLE auth_service LOGIN PASSWORD 'auth_read_only';

GRANT CONNECT ON DATABASE accounts_db TO cobol_reader, auth_service;
GRANT USAGE ON SCHEMA public TO cobol_reader, auth_service;
GRANT SELECT ON accounts  TO cobol_reader;
GRANT SELECT ON app_users TO auth_service;
