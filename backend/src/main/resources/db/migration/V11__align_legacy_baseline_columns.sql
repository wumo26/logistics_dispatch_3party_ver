-- Existing databases created before Flyway may not have the AI key columns
-- that are already present in V1. Keep this migration safe for fresh databases.
DROP PROCEDURE IF EXISTS v11_add_column_if_missing;

DELIMITER //
CREATE PROCEDURE v11_add_column_if_missing(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM information_schema.columns
                   WHERE table_schema = DATABASE()
                     AND table_name = p_table
                     AND column_name = p_column) THEN
        SET @v11_ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
        PREPARE v11_stmt FROM @v11_ddl;
        EXECUTE v11_stmt;
        DEALLOCATE PREPARE v11_stmt;
    END IF;
END //
DELIMITER ;

CALL v11_add_column_if_missing('admin_users', 'ai_api_key_encrypted', 'VARCHAR(512) NULL');
CALL v11_add_column_if_missing('admin_users', 'ai_api_key_last4', 'VARCHAR(4) NULL');
CALL v11_add_column_if_missing('admin_users', 'ai_api_key_updated_at', 'DATETIME(6) NULL');

DROP PROCEDURE v11_add_column_if_missing;

-- Widen legacy columns to the lengths used by the current entities.
ALTER TABLE drivers
    MODIFY COLUMN account VARCHAR(60) NOT NULL,
    MODIFY COLUMN password VARCHAR(100) NULL;

ALTER TABLE emergency_leave_requests
    MODIFY COLUMN reviewed_by VARCHAR(60) NULL;

-- Older manually created databases omitted REDELIVERY from this enum.
ALTER TABLE orders
    MODIFY COLUMN order_type ENUM ('NORMAL', 'REDELIVERY', 'REPLENISHMENT') NOT NULL DEFAULT 'NORMAL';
