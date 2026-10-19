-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.receipt SET total_amount=total_amount+1 WHERE receipt_bk=(SELECT receipt_bk FROM app.receipt LIMIT 1);
