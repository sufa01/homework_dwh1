-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.payment SET amount=amount+1 WHERE (receipt_bk,payment_no)=(SELECT receipt_bk,payment_no FROM app.payment LIMIT 1);
