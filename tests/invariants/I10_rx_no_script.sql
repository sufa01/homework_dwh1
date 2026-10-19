-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.receipt SET prescription_bk=NULL WHERE receipt_bk=(SELECT l.receipt_bk FROM app.receipt_line l WHERE l.is_rx_snapshot LIMIT 1); UPDATE app.receipt_line SET quantity=quantity WHERE (receipt_bk,line_no)=(SELECT receipt_bk,line_no FROM app.receipt_line WHERE is_rx_snapshot LIMIT 1);
