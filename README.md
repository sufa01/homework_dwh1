# HW01 — источники данных и инфраструктура

Учебный стенд для четырёх сервисных баз PostgreSQL: CRM, Catalog, POS и WMS. Физические схемы и контрактные представления лежат в `migrations/`; инфраструктурные настройки — в `compose.yaml` / `docker-compose.yml`.

## Запуск локального базового стенда

Требуются Docker Desktop / Docker Engine с Compose v2 и Python 3.10+.

```bash
cp hw01_submission.yaml hw01_submission.local.yaml  # при необходимости поправьте DSN
# При первом запуске создаются базы, применяются миграции и настраивается CDC.
docker compose up -d
python3 -m pip install 'psycopg[binary]' 'psycopg2-binary' 'PyYAML'
bash scripts/seed.sh --seed 20261019
```

Подключения для локальной машины:

- PostgreSQL primary: `localhost:5432`
- физическая standby: `localhost:5433`
- PgBouncer: `localhost:6432`
- базы: `crm_service_db`, `catalog_service_db`, `pos_service_db`, `wms_service_db`

Учебные учётные данные приведены в `hw01_submission.yaml`. Не использовать их вне локального задания.

## Проверки

```bash
python hw01_check.py --submission hw01_submission.yaml
# Для диагностики конкретных разделов:
python hw01_check.py --submission hw01_submission.yaml --sections contract,keys,volume,dq,cross,repl,inv,cdc
```

Чекер необходимо запускать после реального запуска Docker и генерации. Файл `docs/failover_journal.md` — шаблон: добавляйте только фактические логи и измерения.

## Догонка для проверки репликации

В манифесте `entrypoint.seed_delta` указан `bash scripts/seed.sh --delta`. Команда добавляет 100 чеков, чтобы чекер мог проверить прирост на мастере и последующее совпадение с репликой.

## Важные ограничения текущего комплекта

- В этой версии реализован базовый профиль: один PostgreSQL primary, физическая standby и PgBouncer. Это закрывает учебную основу по репликации, но **не является** кластером Patroni + etcd + HAProxy из расширенной части задания.
- Файлы `hw01_submission.yaml` и конфигурация содержат локальные пароли для учебного окружения.
