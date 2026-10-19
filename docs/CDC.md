# CDC / logical replication

`wal_level=logical` включён параметром запуска PostgreSQL. Publication создаётся отдельно в каждой базе. В PostgreSQL publication нельзя создавать на VIEW — публикуются базовые таблицы `app.*`. Пример для CRM:

```sql
CREATE PUBLICATION cdc_app FOR TABLE app.customer, app.loyalty_card, app.consent;
ALTER TABLE app.customer REPLICA IDENTITY FULL;
SELECT * FROM pg_publication_tables;
```

Аналогично создайте publication в каждой из остальных баз, перечислив нужные физические таблицы. У таблиц с первичным ключом обычно достаточно стандартного `REPLICA IDENTITY DEFAULT`; `FULL` отправляет старую строку целиком и увеличивает объём WAL. Проверяйте публикации отдельно в каждой базе.
