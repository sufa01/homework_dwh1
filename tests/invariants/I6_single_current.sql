-- Требует данных генератора; запускается в транзакции чекера.
INSERT INTO app.price(sku,price_scope,scope_bk,price,currency,valid_from,valid_to,is_current,updated_at) SELECT sku,price_scope,scope_bk,price,currency,valid_from+interval '1 day',NULL,true,updated_at FROM app.price WHERE is_current LIMIT 1;
