# DWH mapping (HW01)

| Business entity | Source service | Contract view | Business key | Join / integration key | Notes |
|---|---|---|---|---|---|
| Customer | CRM | `contract.v_customer` | `customer_bk` | `customer_bk` in POS receipt | Optional for anonymous sales |
| Loyalty card | CRM | `contract.v_loyalty_card` | `card_bk` | `customer_bk` | Link to customer uses CRM BK |
| SKU / product | Catalog | `contract.v_sku` | `sku` | `sku` in POS lines and WMS batches | Product name and Rx status snapshot at sale in POS |
| Price history | Catalog | `contract.v_price` | `price_id` | `sku`, scope fields, validity interval | Historical price version; avoid joining by SKU alone |
| Pharmacy | POS | `contract.v_pharmacy` | `pharmacy_bk` | `pharmacy_bk` in receipt | Store dimension |
| Receipt | POS | `contract.v_receipt` | `receipt_bk` | `receipt_bk` in lines/payments | `customer_bk` nullable |
| Receipt line | POS | `contract.v_receipt_line` | (`receipt_bk`, `line_no`) | `sku`, `batch_bk` | Snapshot attributes must not be replaced from current catalog |
| Payment | POS | `contract.v_payment` | (`receipt_bk`, `payment_no`) | `receipt_bk` | Multiple tenders supported |
| Supplier | WMS | `contract.v_supplier` | `supplier_bk` | `supplier_bk` in purchase line | Supplier dimension |
| Distribution center | WMS | `contract.v_distribution_center` | `dc_bk` | `dc_bk` in purchase line / stock | Location dimension |
| Batch | WMS | `contract.v_batch` | `batch_bk` | `batch_bk` in POS snapshot and movements | Cross-service consistency validated by BK, not FK |
| Purchase line | WMS | `contract.v_purchase_line` | (`purchase_bk`, `line_no`) | `sku`, `batch_bk`, supplier and DC BKs | `line_cost = quantity * unit_cost` |
| Movement | WMS | `contract.v_movement` | `movement_bk` | `batch_bk`, `sku`, source/destination BK | Event ledger |
| Stock | WMS | `contract.v_stock` | location + SKU + batch | `location_bk`, `sku`, `batch_bk` | Snapshot; reconcile with movement ledger |

## Integration rules

- Cross-service links use business keys and are checked by the official checker; physical foreign keys do not cross database boundaries.
- For sales reporting, use the receipt-line snapshots for product name and prescription status at transaction time.
- Price matching must respect scope precedence and the `valid_from` / `valid_to` interval.
- Incremental extraction uses `updated_at`; for deletes, this schema uses soft-delete/status flags where available. The consumer should also capture source deletes if a source table is later changed to hard-delete semantics.
