-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.batch_snapshot SET expiry_date=date '2000-01-01' WHERE batch_bk=(SELECT batch_bk FROM app.receipt_line LIMIT 1); UPDATE app.receipt_line SET quantity=quantity WHERE (receipt_bk,line_no)=(SELECT receipt_bk,line_no FROM app.receipt_line LIMIT 1);
