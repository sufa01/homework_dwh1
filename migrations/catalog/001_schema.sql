CREATE SCHEMA IF NOT EXISTS app;

CREATE SCHEMA IF NOT EXISTS contract;


CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = clock_timestamp(); RETURN NEW; END $$;


CREATE TABLE IF NOT EXISTS app.sku (
    sku text NOT NULL,
    sku_name text NOT NULL,
    inn_name text,
    manufacturer_name text NOT NULL,
    drug_form text,
    category text NOT NULL,
    is_rx boolean NOT NULL,
    is_vital boolean NOT NULL,
    pack_qty numeric(18,4) NOT NULL,
    is_active boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(), deleted_at timestamptz,
    PRIMARY KEY (sku)
);

CREATE OR REPLACE TRIGGER trg_touch_sku BEFORE UPDATE ON app.sku FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_sku AS SELECT sku, sku_name, inn_name, manufacturer_name, drug_form, category, is_rx, is_vital, pack_qty, is_active, updated_at FROM app.sku;

CREATE TABLE IF NOT EXISTS app.price (
    sku text NOT NULL,
    price_scope text NOT NULL,
    scope_bk text NOT NULL,
    price numeric(18,4) NOT NULL,
    currency text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    is_current boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    price_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE TRIGGER trg_touch_price BEFORE UPDATE ON app.price FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_price AS SELECT sku, price_scope, scope_bk, price, currency, valid_from, valid_to, is_current, updated_at FROM app.price;

CREATE TABLE IF NOT EXISTS app.sku_history (history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, sku text NOT NULL REFERENCES app.sku(sku), sku_name text NOT NULL, category text NOT NULL, is_rx boolean NOT NULL, changed_at timestamptz NOT NULL DEFAULT clock_timestamp(), created_at timestamptz NOT NULL DEFAULT clock_timestamp(), updated_at timestamptz NOT NULL DEFAULT clock_timestamp());

CREATE OR REPLACE TRIGGER trg_touch_sku_history BEFORE UPDATE ON app.sku_history FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE app.price ADD CONSTRAINT fk_price_sku FOREIGN KEY(sku) REFERENCES app.sku(sku);

ALTER TABLE app.price ADD CONSTRAINT ck_price_interval CHECK(valid_to IS NULL OR valid_to > valid_from);

ALTER TABLE app.price ADD CONSTRAINT ck_price_positive CHECK(price >= 0);

ALTER TABLE app.price ADD CONSTRAINT ck_price_current CHECK(is_current = (valid_to IS NULL));

ALTER TABLE app.price ADD CONSTRAINT ex_price_interval EXCLUDE USING gist (sku WITH =, price_scope WITH =, scope_bk WITH =, tstzrange(valid_from,valid_to,'[)') WITH &&);

CREATE UNIQUE INDEX ux_current_price ON app.price(sku, price_scope, scope_bk) WHERE is_current;

ALTER TABLE app.sku ADD CONSTRAINT ck_sku_category CHECK(category IN ('rx','otc','supplement','device','cosmetics'));

ALTER TABLE app.sku ADD CONSTRAINT ck_sku_pack CHECK(pack_qty>0);

CREATE OR REPLACE FUNCTION app.guard_sku_bk() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN IF OLD.sku IS DISTINCT FROM NEW.sku THEN RAISE EXCEPTION 'SKU business key is immutable'; END IF; RETURN NEW; END $$;
CREATE OR REPLACE TRIGGER trg_guard_sku BEFORE UPDATE ON app.sku FOR EACH ROW EXECUTE FUNCTION app.guard_sku_bk();
