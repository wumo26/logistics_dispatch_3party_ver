-- 車輛保養規則、既有維修狀態、司機所屬倉庫與出車前安全檢查。
-- 舊資料只回填可由現有欄位確定的資訊；不從歷史路線猜司機所屬倉庫，
-- 也不把目前里程臆測成最近一次大小保里程。

DROP PROCEDURE IF EXISTS v9_add_column_if_missing;

DELIMITER //
CREATE PROCEDURE v9_add_column_if_missing(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition VARCHAR(255))
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = p_table
          AND column_name = p_column
    ) THEN
        SET @v9_ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
        PREPARE v9_stmt FROM @v9_ddl;
        EXECUTE v9_stmt;
        DEALLOCATE PREPARE v9_stmt;
    END IF;
END //
DELIMITER ;

-- 舊司機沒有可信的單一所屬倉庫，保留 NULL 讓主管確認後設定。
CALL v9_add_column_if_missing('drivers', 'warehouse_id', 'BIGINT NULL');

-- 車型文字可確定噸位；大小保基準沒有可靠來源，新增後維持 NULL。
CALL v9_add_column_if_missing('vehicles', 'tonnage', 'DECIMAL(6,2) NULL');
CALL v9_add_column_if_missing('vehicles', 'last_minor_maintenance_km', 'INT NULL');
CALL v9_add_column_if_missing('vehicles', 'last_major_maintenance_km', 'INT NULL');

ALTER TABLE vehicles
    MODIFY COLUMN status ENUM (
        'AVAILABLE', 'MAINTENANCE', 'MINOR_MAINTENANCE', 'MAJOR_MAINTENANCE', 'RETIRED'
    ) NOT NULL;

UPDATE vehicles
SET tonnage = CASE
    WHEN vehicle_type LIKE '1.5噸%' THEN 1.50
    WHEN vehicle_type LIKE '1.75噸%' THEN 1.75
    WHEN vehicle_type LIKE '3.5噸%' THEN 3.50
    WHEN vehicle_type LIKE '5噸%' THEN 5.00
    WHEN vehicle_type LIKE '8噸%' THEN 8.00
    ELSE tonnage
END
WHERE tonnage IS NULL;

CREATE TABLE IF NOT EXISTS vehicle_maintenance_settings (
    id         BIGINT NOT NULL,
    warning_km INT    NOT NULL DEFAULT 500,
    PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

INSERT INTO vehicle_maintenance_settings (id, warning_km)
VALUES (1, 500)
ON DUPLICATE KEY UPDATE warning_km = warning_km;

CREATE TABLE IF NOT EXISTS vehicle_maintenance_policies (
    tonnage           DECIMAL(6,2) NOT NULL,
    minor_interval_km INT          NOT NULL,
    major_interval_km INT          NOT NULL,
    retirement_km     INT          NOT NULL,
    PRIMARY KEY (tonnage)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- 專案既有測試與畫面採用的初始規則；主管日後可由保養規則 API 調整。
INSERT INTO vehicle_maintenance_policies
    (tonnage, minor_interval_km, major_interval_km, retirement_km)
VALUES
    (1.50, 3000, 20000, 500000),
    (1.75, 3000, 20000, 500000),
    (3.50, 3000, 20000, 500000),
    (5.00, 3000, 20000, 500000),
    (8.00, 3000, 20000, 500000)
ON DUPLICATE KEY UPDATE tonnage = VALUES(tonnage);

CREATE TABLE IF NOT EXISTS vehicle_maintenance_records (
    id                    BIGINT       NOT NULL AUTO_INCREMENT,
    vehicle_id            BIGINT       NOT NULL,
    type                  VARCHAR(10)  NOT NULL,
    status                VARCHAR(12)  NOT NULL,
    sent_at               DATETIME(6)  DEFAULT NULL,
    sent_odometer_km      INT          DEFAULT NULL,
    completed_at          DATETIME(6)  DEFAULT NULL,
    completed_odometer_km INT          DEFAULT NULL,
    cancelled_at          DATETIME(6)  DEFAULT NULL,
    recorded_by           VARCHAR(100) DEFAULT NULL,
    completed_by          VARCHAR(100) DEFAULT NULL,
    active_vehicle_id     BIGINT       DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_vehicle_maintenance_active_vehicle (active_vehicle_id),
    KEY idx_vehicle_maintenance_vehicle (vehicle_id, id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- 更新前已標示維修中的車保留為進行中一般維修；送修日期與里程未知，不捏造資料。
INSERT INTO vehicle_maintenance_records
    (vehicle_id, type, status, sent_at, sent_odometer_km, recorded_by, active_vehicle_id)
SELECT v.id, 'REPAIR', 'ACTIVE', NULL, NULL, 'SYSTEM_MIGRATION', v.id
FROM vehicles v
LEFT JOIN vehicle_maintenance_records r ON r.active_vehicle_id = v.id
WHERE v.status = 'MAINTENANCE'
  AND r.id IS NULL;

CREATE TABLE IF NOT EXISTS pre_trip_inspections (
    id                    BIGINT        NOT NULL AUTO_INCREMENT,
    route_id              BIGINT        NOT NULL,
    driver_id             BIGINT        NOT NULL,
    vehicle_id            BIGINT        NOT NULL,
    route_version         INT           NOT NULL,
    work_date             DATE          NOT NULL,
    alcohol_mg_l          DECIMAL(3,2)  NOT NULL,
    alcohol_tested        BIT(1)        NOT NULL,
    headlights            BIT(1)        NOT NULL,
    taillights            BIT(1)        NOT NULL,
    turn_signals          BIT(1)        NOT NULL,
    brake_lights          BIT(1)        NOT NULL,
    front_left_tire       BIT(1)        NOT NULL,
    front_right_tire      BIT(1)        NOT NULL,
    rear_left_tire        BIT(1)        NOT NULL,
    rear_right_tire       BIT(1)        NOT NULL,
    dashcam               BIT(1)        NOT NULL,
    alcohol_photo         VARCHAR(255)  NOT NULL,
    vehicle_photo         VARCHAR(255)  NOT NULL,
    dashcam_photo         VARCHAR(255)  NOT NULL,
    passed                BIT(1)        NOT NULL,
    submitted_at          DATETIME(6)   NOT NULL,
    invalidated_at        DATETIME(6)   DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_pre_trip_route (route_id, id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

DROP PROCEDURE v9_add_column_if_missing;
