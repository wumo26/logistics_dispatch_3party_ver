-- 團專報表移植所需的點交證據；保留所有既有訂單與商品紀錄。
-- 舊資料沒有整單點交備註時保持 NULL；不推測過去是否回報商品不符。
-- 同時支援曾手動新增欄位的本機資料庫，不重複執行 ADD COLUMN。
SET @v12_has_loading_notes = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'orders' AND column_name = 'loading_notes'
);
SET @v12_ddl = IF(@v12_has_loading_notes = 0,
    'ALTER TABLE orders ADD COLUMN loading_notes VARCHAR(500) NULL AFTER loaded_at', 'DO 0');
PREPARE v12_stmt FROM @v12_ddl;
EXECUTE v12_stmt;
DEALLOCATE PREPARE v12_stmt;

SET @v12_has_loading_mismatch = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'order_items' AND column_name = 'loading_mismatch_reported'
);
SET @v12_ddl = IF(@v12_has_loading_mismatch = 0,
    'ALTER TABLE order_items ADD COLUMN loading_mismatch_reported BIT(1) NOT NULL DEFAULT b''0''', 'DO 0');
PREPARE v12_stmt FROM @v12_ddl;
EXECUTE v12_stmt;
DEALLOCATE PREPARE v12_stmt;
