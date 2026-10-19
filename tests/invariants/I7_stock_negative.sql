-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.stock SET qty_on_hand=-1 WHERE (location_type,location_bk,batch_bk)=(SELECT location_type,location_bk,batch_bk FROM app.stock LIMIT 1);
