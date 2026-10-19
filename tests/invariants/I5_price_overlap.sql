-- Требует данных генератора; запускается в транзакции чекера.
INSERT INTO app.price(sku,price_scope,scope_bk,price,currency,valid_from,valid_to,is_current,updated_at) SELECT sku,price_scope,scope_bk,price,currency,valid_from,valid_to,is_current,updated_at FROM app.price LIMIT 1;
