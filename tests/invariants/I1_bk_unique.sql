-- Требует данных генератора; запускается в транзакции чекера.
INSERT INTO app.sku SELECT sku,sku_name,inn_name,manufacturer_name,drug_form,category,is_rx,is_vital,pack_qty,is_active,updated_at,clock_timestamp(),NULL FROM app.sku LIMIT 1;
