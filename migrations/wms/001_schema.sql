CREATE SCHEMA IF NOT EXISTS app;

CREATE SCHEMA IF NOT EXISTS contract;


CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = clock_timestamp(); RETURN NEW; END $$;


CREATE TABLE IF NOT EXISTS app.supplier (
    supplier_bk text NOT NULL,
    supplier_name text NOT NULL,
    country text NOT NULL,
    is_active boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (supplier_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_supplier BEFORE UPDATE ON app.supplier FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_supplier AS SELECT supplier_bk, supplier_name, country, is_active, updated_at FROM app.supplier;

CREATE TABLE IF NOT EXISTS app.distribution_center (
    dc_bk text NOT NULL,
    dc_name text NOT NULL,
    region text NOT NULL,
    city text NOT NULL,
    is_active boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (dc_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_distribution_center BEFORE UPDATE ON app.distribution_center FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_distribution_center AS SELECT dc_bk, dc_name, region, city, is_active, updated_at FROM app.distribution_center;

CREATE TABLE IF NOT EXISTS app.batch (
    batch_bk text NOT NULL,
    sku text NOT NULL,
    series_no text NOT NULL,
    manufactured_date date NOT NULL,
    expiry_date date NOT NULL,
    received_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (batch_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_batch BEFORE UPDATE ON app.batch FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_batch AS SELECT batch_bk, sku, series_no, manufactured_date, expiry_date, received_at, updated_at FROM app.batch;

CREATE TABLE IF NOT EXISTS app.purchase_line (
    purchase_bk text NOT NULL,
    line_no bigint NOT NULL,
    supplier_bk text NOT NULL,
    dc_bk text NOT NULL,
    sku text NOT NULL,
    batch_bk text,
    ordered_at timestamptz NOT NULL,
    received_at timestamptz,
    quantity numeric(18,4) NOT NULL,
    unit_cost numeric(18,4) NOT NULL,
    line_cost numeric(18,4) NOT NULL,
    currency text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (purchase_bk, line_no)
);

CREATE OR REPLACE TRIGGER trg_touch_purchase_line BEFORE UPDATE ON app.purchase_line FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_purchase_line AS SELECT purchase_bk, line_no, supplier_bk, dc_bk, sku, batch_bk, ordered_at, received_at, quantity, unit_cost, line_cost, currency, updated_at FROM app.purchase_line;

CREATE TABLE IF NOT EXISTS app.movement (
    movement_bk text NOT NULL,
    batch_bk text NOT NULL,
    sku text NOT NULL,
    movement_type text NOT NULL,
    src_type text,
    src_bk text,
    dst_type text,
    dst_bk text,
    qty numeric(18,4) NOT NULL,
    dispatched_at timestamptz,
    moved_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (movement_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_movement BEFORE UPDATE ON app.movement FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_movement AS SELECT movement_bk, batch_bk, sku, movement_type, src_type, src_bk, dst_type, dst_bk, qty, dispatched_at, moved_at, updated_at FROM app.movement;

CREATE TABLE IF NOT EXISTS app.stock (
    location_type text NOT NULL,
    location_bk text NOT NULL,
    sku text NOT NULL,
    batch_bk text NOT NULL,
    qty_on_hand numeric(18,4) NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (location_type, location_bk, batch_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_stock BEFORE UPDATE ON app.stock FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_stock AS SELECT location_type, location_bk, sku, batch_bk, qty_on_hand, updated_at FROM app.stock;

ALTER TABLE app.batch ADD CONSTRAINT uq_batch_series UNIQUE(sku,series_no);

ALTER TABLE app.batch ADD CONSTRAINT ck_batch_dates CHECK(expiry_date>manufactured_date);

ALTER TABLE app.purchase_line ADD CONSTRAINT fk_purchase_supplier FOREIGN KEY(supplier_bk) REFERENCES app.supplier(supplier_bk);

ALTER TABLE app.purchase_line ADD CONSTRAINT fk_purchase_dc FOREIGN KEY(dc_bk) REFERENCES app.distribution_center(dc_bk);

ALTER TABLE app.purchase_line ADD CONSTRAINT fk_purchase_batch FOREIGN KEY(batch_bk) REFERENCES app.batch(batch_bk);

ALTER TABLE app.purchase_line ADD CONSTRAINT ck_purchase_math CHECK(quantity>0 AND unit_cost>=0 AND line_cost=quantity*unit_cost);

ALTER TABLE app.stock ADD CONSTRAINT fk_stock_batch FOREIGN KEY(batch_bk) REFERENCES app.batch(batch_bk);

ALTER TABLE app.stock ADD CONSTRAINT ck_stock_nonnegative CHECK(qty_on_hand>=0);

ALTER TABLE app.movement ADD CONSTRAINT fk_movement_batch FOREIGN KEY(batch_bk) REFERENCES app.batch(batch_bk);

ALTER TABLE app.movement ADD CONSTRAINT ck_movement_qty CHECK(qty>0);

CREATE OR REPLACE FUNCTION app.guard_receipt_expiry() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE exp date;
BEGIN
 SELECT expiry_date INTO exp FROM app.batch WHERE batch_bk=NEW.batch_bk;
 IF NEW.received_at IS NOT NULL AND NEW.received_at::date>exp THEN RAISE EXCEPTION 'Expired batch cannot be received'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_guard_receipt_expiry BEFORE INSERT OR UPDATE ON app.purchase_line FOR EACH ROW EXECUTE FUNCTION app.guard_receipt_expiry();
