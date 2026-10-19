-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.sku SET sku=sku||'-CHANGED' WHERE sku=(SELECT sku FROM app.sku LIMIT 1);
