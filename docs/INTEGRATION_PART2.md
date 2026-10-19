# Интеграция — часть 2

## Запуск

```bash
docker compose up -d postgres pgbouncer
docker compose logs -f postgres
```

При первом запуске на пустом volume создаются четыре базы, применяются миграции и назначаются роли. Инициализационные скрипты не запускаются повторно на существующем volume. Для полностью чистого стенда используйте `docker compose down -v` (команда удаляет все локальные данные).

## Подключения

- PostgreSQL напрямую: `localhost:5432`
- PgBouncer: `localhost:6432`
- Базы: `crm_service_db`, `catalog_service_db`, `pos_service_db`, `wms_service_db`
- Учебные пароли в compose предназначены только для локальной среды; перед публикацией репозитория их следует заменить.

## Генерация и проверки

После старта нужно наполнить источники данными в порядке CRM, Catalog, WMS, затем POS. До вставки строк чеков POS требуется скопировать `batch_bk`, `sku`, `expiry_date` из WMS в `app.batch_snapshot`. Вставка чека, его строк и оплат должна быть одной транзакцией, поскольку сверка сумм отложенная.

Минимумы из `hw01_contract.yaml`: customer 2000, loyalty_card 1500, sku 500, price 1500, pharmacy 30, receipt 20000, receipt_line 60000, payment 20000, supplier 10, distribution_center 3, batch 3000, purchase_line 5000, movement 20000, stock 5000.

После генерации проверить все минимумы по VIEW, запустить `tests/invariants/*.sql` в соответствующих базах и официальный `hw01_check.py`. Пока команды не исполнены на живом стенде, нельзя утверждать, что чекер пройден.
