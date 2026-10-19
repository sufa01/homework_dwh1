-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.purchase_line SET received_at=timestamptz '2099-01-01 00:00:00+00' WHERE (purchase_bk,line_no)=(SELECT purchase_bk,line_no FROM app.purchase_line LIMIT 1);
