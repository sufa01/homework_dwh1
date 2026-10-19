CREATE SCHEMA IF NOT EXISTS app;

CREATE SCHEMA IF NOT EXISTS contract;


CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = clock_timestamp(); RETURN NEW; END $$;


CREATE TABLE IF NOT EXISTS app.pharmacy (
    pharmacy_bk text NOT NULL,
    pharmacy_name text NOT NULL,
    region text NOT NULL,
    city text NOT NULL,
    address text NOT NULL,
    opened_at date NOT NULL,
    closed_at date,
    is_active boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (pharmacy_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_pharmacy BEFORE UPDATE ON app.pharmacy FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_pharmacy AS SELECT pharmacy_bk, pharmacy_name, region, city, address, opened_at, closed_at, is_active, updated_at FROM app.pharmacy;

CREATE TABLE IF NOT EXISTS app.receipt (
    receipt_bk text NOT NULL,
    pharmacy_bk text NOT NULL,
    customer_bk text,
    cashier_bk text NOT NULL,
    shift_bk text NOT NULL,
    receipt_dt timestamptz NOT NULL,
    doc_type text NOT NULL,
    parent_receipt_bk text,
    total_amount numeric(18,4) NOT NULL,
    discount_amount numeric(18,4) NOT NULL,
    currency text NOT NULL,
    prescription_bk text,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (receipt_bk)
);

CREATE OR REPLACE TRIGGER trg_touch_receipt BEFORE UPDATE ON app.receipt FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_receipt AS SELECT receipt_bk, pharmacy_bk, customer_bk, cashier_bk, shift_bk, receipt_dt, doc_type, parent_receipt_bk, total_amount, discount_amount, currency, prescription_bk, updated_at FROM app.receipt;

CREATE TABLE IF NOT EXISTS app.receipt_line (
    receipt_bk text NOT NULL,
    line_no bigint NOT NULL,
    sku text NOT NULL,
    batch_bk text NOT NULL,
    quantity numeric(18,4) NOT NULL,
    unit_price numeric(18,4) NOT NULL,
    line_discount numeric(18,4) NOT NULL,
    line_amount numeric(18,4) NOT NULL,
    is_rx_snapshot boolean NOT NULL,
    sku_name_snapshot text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (receipt_bk, line_no)
);

CREATE OR REPLACE TRIGGER trg_touch_receipt_line BEFORE UPDATE ON app.receipt_line FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_receipt_line AS SELECT receipt_bk, line_no, sku, batch_bk, quantity, unit_price, line_discount, line_amount, is_rx_snapshot, sku_name_snapshot, updated_at FROM app.receipt_line;

CREATE TABLE IF NOT EXISTS app.payment (
    receipt_bk text NOT NULL,
    payment_no bigint NOT NULL,
    payment_method text NOT NULL,
    amount numeric(18,4) NOT NULL,
    currency text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (receipt_bk, payment_no)
);

CREATE OR REPLACE TRIGGER trg_touch_payment BEFORE UPDATE ON app.payment FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

CREATE OR REPLACE VIEW contract.v_payment AS SELECT receipt_bk, payment_no, payment_method, amount, currency, updated_at FROM app.payment;

CREATE TABLE IF NOT EXISTS app.batch_snapshot (batch_bk text PRIMARY KEY, sku text NOT NULL, expiry_date date NOT NULL, created_at timestamptz NOT NULL DEFAULT clock_timestamp(), updated_at timestamptz NOT NULL DEFAULT clock_timestamp());

CREATE OR REPLACE TRIGGER trg_touch_batch_snapshot BEFORE UPDATE ON app.batch_snapshot FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

ALTER TABLE app.receipt ADD CONSTRAINT fk_receipt_pharmacy FOREIGN KEY(pharmacy_bk) REFERENCES app.pharmacy(pharmacy_bk);

ALTER TABLE app.receipt ADD CONSTRAINT ck_receipt_kind CHECK((doc_type='sale' AND parent_receipt_bk IS NULL) OR (doc_type='refund' AND parent_receipt_bk IS NOT NULL));

ALTER TABLE app.receipt ADD CONSTRAINT fk_parent_receipt FOREIGN KEY(parent_receipt_bk) REFERENCES app.receipt(receipt_bk);

ALTER TABLE app.receipt_line ADD CONSTRAINT fk_line_receipt FOREIGN KEY(receipt_bk) REFERENCES app.receipt(receipt_bk);

ALTER TABLE app.payment ADD CONSTRAINT fk_payment_receipt FOREIGN KEY(receipt_bk) REFERENCES app.receipt(receipt_bk);

ALTER TABLE app.receipt_line ADD CONSTRAINT ck_line_math CHECK(quantity > 0 AND unit_price>=0 AND line_discount>=0 AND line_discount<=quantity*unit_price AND line_amount=quantity*unit_price-line_discount);

ALTER TABLE app.receipt_line ADD CONSTRAINT ck_rx_snapshot CHECK(is_rx_snapshot IN (true,false));

ALTER TABLE app.payment ADD CONSTRAINT ck_payment CHECK(amount>=0 AND payment_method IN ('cash','card','bonus','certificate'));

ALTER TABLE app.receipt ADD CONSTRAINT ck_receipt_amount CHECK(total_amount>=0 AND discount_amount>=0);

CREATE OR REPLACE FUNCTION app.check_receipt_balances() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE rid text; expected numeric; actual numeric; paid numeric;
BEGIN
 rid := CASE WHEN TG_OP='DELETE' THEN OLD.receipt_bk ELSE NEW.receipt_bk END;
 SELECT total_amount INTO expected FROM app.receipt WHERE receipt_bk=rid;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT COALESCE(sum(line_amount),0) INTO actual FROM app.receipt_line WHERE receipt_bk=rid;
 SELECT COALESCE(sum(amount),0) INTO paid FROM app.payment WHERE receipt_bk=rid;
 IF expected<>actual THEN RAISE EXCEPTION 'Receipt % total differs from lines', rid; END IF;
 IF expected<>paid THEN RAISE EXCEPTION 'Receipt % payment differs from total', rid; END IF;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER receipt_totals_from_receipt AFTER INSERT OR UPDATE ON app.receipt DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION app.check_receipt_balances();
CREATE CONSTRAINT TRIGGER receipt_totals_from_line AFTER INSERT OR UPDATE OR DELETE ON app.receipt_line DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION app.check_receipt_balances();
CREATE CONSTRAINT TRIGGER receipt_totals_from_payment AFTER INSERT OR UPDATE OR DELETE ON app.payment DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION app.check_receipt_balances();

CREATE OR REPLACE FUNCTION app.guard_line() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE dt timestamptz; rx text; parent_id text; sold numeric; returned numeric;
BEGIN
 SELECT receipt_dt, prescription_bk,parent_receipt_bk INTO dt,rx,parent_id FROM app.receipt WHERE receipt_bk=NEW.receipt_bk;
 IF NEW.is_rx_snapshot AND rx IS NULL THEN RAISE EXCEPTION 'Prescription required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM app.batch_snapshot b WHERE b.batch_bk=NEW.batch_bk AND b.sku=NEW.sku) THEN RAISE EXCEPTION 'Batch snapshot is missing or SKU does not match'; END IF;
 IF EXISTS(SELECT 1 FROM app.batch_snapshot b WHERE b.batch_bk=NEW.batch_bk AND b.expiry_date < dt::date) THEN RAISE EXCEPTION 'Expired batch cannot be sold'; END IF;
 IF parent_id IS NOT NULL THEN
  SELECT COALESCE(sum(quantity),0) INTO sold FROM app.receipt_line WHERE receipt_bk=parent_id AND sku=NEW.sku;
  SELECT COALESCE(sum(l.quantity),0) INTO returned FROM app.receipt_line l JOIN app.receipt r ON r.receipt_bk=l.receipt_bk WHERE r.parent_receipt_bk=parent_id AND l.sku=NEW.sku AND (l.receipt_bk<>NEW.receipt_bk OR l.line_no<>NEW.line_no);
  IF returned + NEW.quantity > sold THEN RAISE EXCEPTION 'Refund exceeds original sale'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_guard_line BEFORE INSERT OR UPDATE ON app.receipt_line FOR EACH ROW EXECUTE FUNCTION app.guard_line();
