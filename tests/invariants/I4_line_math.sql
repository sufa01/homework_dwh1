-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.receipt_line SET line_amount=-1 WHERE (receipt_bk,line_no)=(SELECT receipt_bk,line_no FROM app.receipt_line LIMIT 1);
