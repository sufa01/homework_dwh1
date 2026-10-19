# Передача участнику 2

## Порядок действий
1. На инстансе PostgreSQL создать ЧЕТЫРЕ отдельные базы crm_service_db, catalog_service_db, pos_service_db, wms_service_db.
2. Выполнить `migrations/<service>/001_schema.sql` в соответствующей БД (psql -v ON_ERROR_STOP=1).
3. Создать роли app и checker и выдать соответствующие привилегии.
4. Seed в порядке CRM, catalog, WMS master data, POS pharmacy + batch_snapshot, POS receipts/payments, WMS movements/stock.
5. Наполнить каждое VIEW минимумом из hw01_contract.yaml.
6. `app.batch_snapshot` заполнять из WMS batch (batch_bk, sku, expiry_date) ДО receipt_line.
7. При INSERT sale/refund обязательно в одной транзакции добавить строки чека и оплаты, поскольку суммы валидируются на COMMIT.
8. При seed повторная загрузка обязана не изменять те же ключи и не создавать конфликтные версии цен.
9. Инфраструктура, CDC publications, wal_level=logical, physical replica, HA и отчёт — часть участника 2.
10. Сверить CHECKER проверки C/X, протестировать все SQLSTATE и исправить интеграционные расхождения.

## Конкретные ограничения модели
- app.price.is_current должен быть равен `(valid_to IS NULL)`.
- POS хранит sku, batch_bk и customer_bk как логические ссылки без FK в другую БД.
- Чтобы пройти I8, для каждой используемой партии нужна запись app.batch_snapshot. Без snapshot продажа блокируется триггером; генератор обязан синхронизировать локальную копию до вставки строк чека.
- Для I10 рецепт определяется `receipt.prescription_bk`, флаг Rx берётся из `receipt_line.is_rx_snapshot`.
- app.stock — материализованные остатки; движения и остатки обязаны быть согласованы генератором.
- Обязательное исправление перед сдачей: связать обновление movement и stock триггером/транзакционной процедурой и согласовать обработку изменений уже проданных партий.
- PostgreSQL `CHECK` не гарантирует matching SUM после ручного изменения movement — это открытый риск модели.
