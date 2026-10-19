CREATE SCHEMA IF NOT EXISTS app;

CREATE SCHEMA IF NOT EXISTS contract;


CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = clock_timestamp(); RETURN NEW; END $$;


CREATE TABLE IF NOT EXISTS app.customer (
    customer_bk text NOT NULL,
    birth_year bigint,
    sex text,
    city text,
    region text,
    loyalty_level text,
    marketing_opt_in boolean NOT NULL,
    registered_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    deleted_at timestamptz, email text, phone text, created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (customer_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_customer BEFORE UPDATE ON app.customer FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_customer AS SELECT customer_bk, birth_year, sex, city, region, loyalty_level, marketing_opt_in, registered_at, updated_at FROM app.customer WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS app.loyalty_card (
    card_bk text NOT NULL,
    customer_bk text NOT NULL,
    issued_at timestamptz NOT NULL,
    closed_at timestamptz,
    status text NOT NULL,
    bonus_balance numeric(18,4) NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (card_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_loyalty_card BEFORE UPDATE ON app.loyalty_card FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_loyalty_card AS SELECT card_bk, customer_bk, issued_at, closed_at, status, bonus_balance, updated_at FROM app.loyalty_card;

CREATE TABLE IF NOT EXISTS app.consent (consent_bk text PRIMARY KEY, customer_bk text NOT NULL REFERENCES app.customer(customer_bk), consent_type text NOT NULL, granted_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT clock_timestamp(), updated_at timestamptz NOT NULL DEFAULT clock_timestamp());

CREATE OR REPLACE TRIGGER trg_touch_consent BEFORE UPDATE ON app.consent FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

ALTER TABLE app.loyalty_card ADD CONSTRAINT fk_card_customer FOREIGN KEY(customer_bk) REFERENCES app.customer(customer_bk);

CREATE UNIQUE INDEX ux_active_card ON app.loyalty_card(customer_bk) WHERE status='active';

CREATE UNIQUE INDEX ux_active_consent ON app.consent(customer_bk, consent_type) WHERE revoked_at IS NULL;

ALTER TABLE app.loyalty_card ADD CONSTRAINT ck_card_status CHECK(status IN ('active','blocked','closed'));

CREATE OR REPLACE FUNCTION app.anon_customer() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN IF NEW.deleted_at IS NOT NULL THEN NEW.email=NULL; NEW.phone=NULL; END IF; RETURN NEW; END $$;
CREATE OR REPLACE TRIGGER trg_anon BEFORE INSERT OR UPDATE ON app.customer FOR EACH ROW EXECUTE FUNCTION app.anon_customer();
