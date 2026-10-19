#!/usr/bin/env python3
"""Генератор синтетических данных для локального стенда HW01.
Зависимость: pip install 'psycopg[binary]'. Повторный запуск добавляет только отсутствующие BK.
"""
import os, random, argparse
from datetime import date, datetime, timedelta, timezone
import psycopg
random.seed(20261019)
BASE=os.getenv('PG_DSN','postgresql://postgres:postgres_dev_only@localhost:5432')
NOW=datetime.now(timezone.utc).replace(microsecond=0)
def db(name): return psycopg.connect(f'{BASE}/{name}')
def insert(c, sql, rows):
    with c.cursor() as cur: cur.executemany(sql, rows)
def ts(): return NOW-timedelta(days=random.randint(0,500), minutes=random.randint(0,1440))
def main():
    parser = argparse.ArgumentParser(description="Seed synthetic HW01 data")
    parser.add_argument("--delta", action="store_true", help="append 100 receipts for replication checks")
    parser.add_argument("--seed", type=int, default=20261019)
    args = parser.parse_args()
    random.seed(args.seed + (1 if args.delta else 0))
    # CRM
    with db('crm_service_db') as c:
        insert(c,'''INSERT INTO app.customer(customer_bk,birth_year,sex,city,region,loyalty_level,marketing_opt_in,registered_at,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        (f'C{i:06}',random.randint(1940,2007) if i%9 else None,random.choice(['M','F',None]),random.choice(['Москва','Казань','Тула','Пермь']),random.choice(['Центральный','Приволжский','Уральский']),random.choice(['basic','silver','gold']),i%5!=0,ts(),NOW) for i in range(1,2501)])
        insert(c,'''INSERT INTO app.loyalty_card(card_bk,customer_bk,issued_at,closed_at,status,bonus_balance,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        (f'L{i:06}',f'C{i:06}',ts(),None,'active',round(random.uniform(0,500),2),NOW) for i in range(1,1801)])
    # Catalog
    with db('catalog_service_db') as c:
        insert(c,'''INSERT INTO app.sku(sku,sku_name,inn_name,manufacturer_name,drug_form,category,is_rx,is_vital,pack_qty,is_active,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        (f'SKU{i:05}',f'Товар {i}',f'Вещество {i}' if i%5==0 else None,f'Производитель {i%40+1}',random.choice(['таблетки','раствор','мазь',None]),cat,cat=='rx',i%7==0,1 if i%4 else 2,True,NOW)
        for i in range(1,601) for cat in [(['rx','otc','supplement','device','cosmetics'][(i-1)%5])]])
        prices=[]
        for i in range(1,601):
            for v in range(3):
                vf=NOW-timedelta(days=180-v*60); vt=NOW-timedelta(days=120-v*60) if v<2 else None
                prices.append((f'SKU{i:05}','chain','ALL',round(random.uniform(20,2000),2),'RUB',vf,vt,vt is None,NOW))
        insert(c,'''INSERT INTO app.price(sku,price_scope,scope_bk,price,currency,valid_from,valid_to,is_current,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',prices)
    # WMS master + batches
    with db('wms_service_db') as c:
        insert(c,'INSERT INTO app.supplier(supplier_bk,supplier_name,country,is_active,updated_at) VALUES (%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING',[(f'SUP{i:03}',f'Поставщик {i}',random.choice(['RU','BY','KZ']),True,NOW) for i in range(1,21)])
        insert(c,'INSERT INTO app.distribution_center(dc_bk,dc_name,region,city,is_active,updated_at) VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING',[(f'DC{i:02}',f'Склад {i}',random.choice(['Центральный','Приволжский']),random.choice(['Москва','Казань','Тула']),True,NOW) for i in range(1,5)])
        batches=[]
        for i in range(1,4001):
            m=date.today()-timedelta(days=random.randint(60,600)); exp=date.today()+timedelta(days=random.randint(10,900))
            batches.append((f'B{i:06}',f'SKU{(i-1)%600+1:05}',f'SER{i:06}',m,exp,ts(),NOW))
        insert(c,'''INSERT INTO app.batch(batch_bk,sku,series_no,manufactured_date,expiry_date,received_at,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',batches)
        insert(c,'''INSERT INTO app.purchase_line(purchase_bk,line_no,supplier_bk,dc_bk,sku,batch_bk,ordered_at,received_at,quantity,unit_cost,line_cost,currency,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        (f'PO{i:06}',1,f'SUP{(i-1)%20+1:03}',f'DC{(i-1)%4+1:02}',f'SKU{(i-1)%600+1:05}',f'B{(i-1)%4000+1:06}',ts(),ts(),q,10.0,q*10.0,'RUB',NOW) for i,q in ((i,random.randint(1,100)) for i in range(1,6001))])
        insert(c,'''INSERT INTO app.stock(location_type,location_bk,sku,batch_bk,qty_on_hand,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        ('dc',f'DC{((i-1)//4000+(i-1)%4)%4+1:02}',f'SKU{((i-1)%4000)%600+1:05}',f'B{(i-1)%4000+1:06}',random.randint(10,300),NOW) for i in range(1,5001)])
        insert(c,'''INSERT INTO app.movement(movement_bk,batch_bk,sku,movement_type,src_type,src_bk,dst_type,dst_bk,qty,moved_at,updated_at)
        VALUES (%s,%s,%s,'receipt',NULL,NULL,'dc',%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[
        (f'M{i:07}',f'B{(i-1)%4000+1:06}',f'SKU{(i-1)%600+1:05}',f'DC{(i-1)%4+1:02}',random.randint(1,50),ts(),NOW) for i in range(1,22001)])
    # POS snapshot must be in place before lines; sales use three lines to satisfy the contract minimum.
    with db('wms_service_db') as w, db('catalog_service_db') as cat, db('pos_service_db') as p:
        with w.cursor() as cur: cur.execute('SELECT batch_bk,sku,expiry_date FROM app.batch'); snapshots=cur.fetchall()
        insert(p,'INSERT INTO app.batch_snapshot(batch_bk,sku,expiry_date,updated_at) VALUES (%s,%s,%s,%s) ON CONFLICT DO NOTHING',[(b,s,e,NOW) for b,s,e in snapshots])
        insert(p,'''INSERT INTO app.pharmacy(pharmacy_bk,pharmacy_name,region,city,address,opened_at,is_active,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',[(f'PH{i:03}',f'Аптека {i}',random.choice(['Центральный','Приволжский']),random.choice(['Москва','Казань','Тула']),f'ул. Примерная, {i}',date(2018,1,1),True,NOW) for i in range(1,41)])
        with cat.cursor() as cur: cur.execute('SELECT sku,sku_name,is_rx FROM app.sku ORDER BY sku'); skus=cur.fetchall()
        with w.cursor() as cur: cur.execute('SELECT batch_bk,sku FROM app.batch WHERE expiry_date >= %s ORDER BY batch_bk',(date.today()+timedelta(days=1),)); batches=cur.fetchall()
        valid_by_sku={}
        for b,s in batches: valid_by_sku.setdefault(s,[]).append(b)
        sku_map={s:(name,rx) for s,name,rx in skus}
        receipts=[]; lines=[]; pays=[]
        receipt_start = 20001 if args.delta else 1
        receipt_stop = receipt_start + (100 if args.delta else 20000)
        for i in range(receipt_start, receipt_stop):
            rb=f'R{i:07}'; ph=f'PH{(i-1)%40+1:03}'; dt=ts(); total=0; chosen=[]
            for ln in range(1,4):
                sku,name,rx=random.choice(skus); available=valid_by_sku.get(sku)
                if not available: continue
                batch=random.choice(available); qty=random.randint(1,3); price=round(random.uniform(25,1500),2); amount=round(qty*price,2); total+=amount
                chosen.append((rb,ln,sku,batch,qty,price,0,amount,rx,name,NOW))
            if not chosen: continue
            rx_needed=any(x[8] for x in chosen)
            receipts.append((rb,ph,f'C{(i-1)%2500+1:06}' if i%6 else None,f'CS{(i-1)%120+1:03}',f'SH{i:07}',dt,'sale',None,total,0,'RUB',f'RX{i:07}' if rx_needed else None,NOW))
            lines.extend(chosen); pays.append((rb,1,random.choice(['cash','card']),total,'RUB',NOW))
        insert(p,'''INSERT INTO app.receipt(receipt_bk,pharmacy_bk,customer_bk,cashier_bk,shift_bk,receipt_dt,doc_type,parent_receipt_bk,total_amount,discount_amount,currency,prescription_bk,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',receipts)
        insert(p,'''INSERT INTO app.receipt_line(receipt_bk,line_no,sku,batch_bk,quantity,unit_price,line_discount,line_amount,is_rx_snapshot,sku_name_snapshot,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',lines)
        insert(p,'''INSERT INTO app.payment(receipt_bk,payment_no,payment_method,amount,currency,updated_at)
        VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING''',pays)
    print('Delta добавлена.' if args.delta else 'Базовые данные созданы. Проверьте объёмы и запустите hw01_check.py.')
if __name__=='__main__': main()
