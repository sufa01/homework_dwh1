# Streaming replication: настройка и проверка

Физическая репликация PostgreSQL работает на уровне всего кластера, поэтому один standby будет реплицировать все четыре базы. Основной контейнер уже запускается с `wal_level=logical`, `max_wal_senders=10` и `max_replication_slots=10`.

Для реплики нужно разрешить роль `replicator` в `pg_hba.conf` на primary, например `host replication replicator all scram-sha-256`, перезагрузить конфигурацию и выполнить `pg_basebackup` в отдельный пустой каталог данных с параметрами `-R -X stream`. Не подключайте один volume данных одновременно к primary и standby.

Проверка на primary:

```sql
SELECT application_name, state, sync_state FROM pg_stat_replication;
```

На standby:

```sql
SELECT pg_is_in_recovery(); -- ожидается true
```

Compose-файл в этой версии поднимает primary и PgBouncer; реплика требует отдельного сервиса и предварительной настройки доступа. Это не автоматический failover.
