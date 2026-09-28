-- 將舊訂單既有的箱數與內容摘要轉成一筆可點交明細。
-- 不捏造商品代碼、點交時間、點交司機或實點數量；已經有明細的訂單不重複新增。
INSERT INTO order_items (
    order_id,
    product_code,
    item_name,
    expected_quantity,
    unit,
    sequence,
    notes,
    loaded_quantity,
    checked_at,
    checked_by_driver_id,
    loading_notes
)
SELECT
    orders.id,
    NULL,
    LEFT(COALESCE(
        NULLIF(TRIM(orders.item_description), ''),
        NULLIF(TRIM(orders.source_vendor), ''),
        '訂單箱貨'
    ), 100),
    orders.box_count,
    '箱',
    1,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
FROM orders
WHERE orders.box_count > 0
  AND NOT EXISTS (
      SELECT 1
      FROM order_items
      WHERE order_items.order_id = orders.id
  );
