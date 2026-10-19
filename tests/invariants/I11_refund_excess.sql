-- Требует данных генератора; запускается в транзакции чекера.
UPDATE app.receipt_line SET quantity=quantity+100000, line_amount=(quantity+100000)*unit_price-line_discount WHERE (receipt_bk,line_no)=(SELECT l.receipt_bk,l.line_no FROM app.receipt_line l JOIN app.receipt r USING(receipt_bk) WHERE r.doc_type='refund' LIMIT 1);
