# 完整非測試資料快照（敏感欄位遮蔽）

本目錄保留 `3party_ver` 的完整結構與**全部 15,057 筆非測試紀錄**，包含 14,284 筆 GPS 及 1 筆帳號申請。每一筆非測試紀錄均保留，只遮蔽登入憑證、個資、精確位置與自由文字等敏感欄位；不再像上一版一樣省略整張 GPS 或帳號申請表的資料。

SQL 不包含 `backend/.env` 中的資料庫連線密碼、JWT 金鑰，也不包含實體照片檔案、OSRM 路網或 MySQL 系統帳號。匯出與篩選未寫入原本的資料庫。

## 版本與範圍

| 項目               | 內容                                           |
| ------------------ | ---------------------------------------------- |
| 來源資料庫         | `3party_ver`                                   |
| 擷取時間           | 2026-11-26 09:12:59 UTC，即台北時間 17:12:59   |
| 來源 MySQL         | 8.0.46                                         |
| 結構版本           | Flyway V12                                     |
| 資料表             | 36 張，包含現有舊版相容資料表；空表仍保留結構  |
| 來源資料           | 15,313 筆                                      |
| 排除測試及關聯資料 | 256 筆                                         |
| 實際匯出           | 15,057 筆，包含 12 筆 Flyway 中繼資料          |
| GPS                | 14,284 筆均保留，座標已遮蔽                    |
| 帳號申請           | 保留 1 筆非測試紀錄，排除 1 筆有測試標記的紀錄 |

- [schema.sql](snapshots/3party_ver/schema.sql)：原始建表、索引、外鍵與自增設定。
- [data.sql](snapshots/3party_ver/data.sql)：保留全部非測試紀錄，敏感欄位依下方規則遮蔽。
- [manifest.json](snapshots/3party_ver/manifest.json)：各表來源、保留、排除筆數，已知關聯缺口、公開範圍及 SQL 的 SHA-256。

來源以單次 `mysqldump --single-transaction` 完整擷取，再排除測試及其關聯紀錄，最後逐欄遮蔽敏感資料。原始數字 ID、資料關聯、日期、時間、數量與一般狀態保留；兩個 SQL 檔請成套使用。

## 敏感欄位處理

| 類型           | 處理方式                                                                          |
| -------------- | --------------------------------------------------------------------------------- |
| ID／關聯       | 原始數字主鍵與外鍵保留，不因遮蔽重新編號或刪列                                    |
| 帳號與姓名     | 改為 `snapshot_admin_*`、`snapshot_driver_*`、`snapshot_application_*` 及編號代稱 |
| 密碼／API Key  | 原始雜湊及金鑰完全移除；可空欄位為 `NULL`，必填密碼為空字串；匯入後無可用登入密碼 |
| 個人聯絡資料   | 電話、地址、聯絡人與身分證相關欄位清空；必填欄位以空字串處理                      |
| 車牌／業務識別 | 車牌、訂單編號、門市碼、倉庫碼與名稱改成快照代稱                                  |
| GPS            | 每筆原始 ID、司機 ID 與時間保留，緯經度均設為 `0`；不能還原原始軌跡               |
| 其他座標       | 可空欄位為 `NULL`，門市／倉庫等必填座標為 `0`                                     |
| 照片／附件     | 路徑清空，實體檔不打包；紀錄本身仍保留                                            |
| 自由文字       | 備註、理由、處理人等清空或改成 `REDACTED`；不保留原文                             |
| 請假類別       | 非 `ABSENT` 類型統一為 `PERSONAL`，不公開健康及家庭類別                           |
| 批次群組       | 批次識別碼另產生代碼，保留原有分組關係                                            |

**座標 `0` 是遮蔽值，不是有效配送地點。** 這份資料可核對結構、筆數與關聯，但不能用來重現真實軌跡或原始敏感內容。需要導航、排車或實地定位前，先補正倉庫與門市的位置。

## 排除規則

辨識字串欄位中的 `DEMO`、`E2E`、`SMOKE`、`REGRESSION`、`CODEX`、`TEST`、測試、示範等標記。密碼雜湊、API Key 欄位不參與標記比對，避免將隨機編碼誤認為測試標記。

先排除命中標記的紀錄，再沿實體外鍵與業務關聯排除引用它們的子紀錄；不在來源資料庫執行清理或刪除。

| 資料表                        | 直接測試標記 | 關聯排除 |    合計 |
| ----------------------------- | -----------: | -------: | ------: |
| `orders`                      |           82 |        3 |      85 |
| `order_items`                 |            0 |       85 |      85 |
| `delivery_records`            |            0 |       82 |      82 |
| `driver_account_applications` |            1 |        0 |       1 |
| `vehicles`                    |            1 |        0 |       1 |
| `routes`                      |            0 |        1 |       1 |
| `route_vehicle_segments`      |            0 |        1 |       1 |
| **合計**                      |       **84** |  **172** | **256** |

此次直接命中的內容為：81 筆供應商帶 `DEMO` 標記的訂單、1 筆 `E2E` 訂單、1 筆拒絕理由有測試標記的帳號申請，以及 1 台車型有測試標記的車輛。沒有另行新增示範訂單、測試人員或補造空表資料。

**原庫既有的非測試關聯缺口也原樣保留：** `delivery_records.order_id` 有 11 筆找不到訂單，`delivery_records.route_id` 有 2 筆找不到路線。這兩組數字可能重疊，不能相加當成筆數。它們不是資料庫宣告的實體外鍵，此版不再因這些缺口刪除非測試紀錄；相關歷史頁面可能無法對應完整父資料。

## 各表筆數

| 資料表                         |  筆數 | 資料表                        | 筆數 |
| ------------------------------ | ----: | ----------------------------- | ---: |
| `admin_sticky_notes`           |     0 | `admin_users`                 |    3 |
| `attendance_records`           |    12 | `delivery_records`            |   18 |
| `dispatch_templates`           |     0 | `distance_matrix_cache`       |    0 |
| `driver_account_applications`  |     1 | `driver_leave_request_events` |   32 |
| `driver_leave_requests`        |    32 | `driver_messages`             |    0 |
| `driver_shifts`                |   455 | `drivers`                     |    8 |
| `emergency_leave_requests`     |     1 | `exception_cases`             |    3 |
| `flyway_schema_history`        |    12 | `fuel_price_history`          |    9 |
| `gps_pings`                    | 14284 | `mileage_logs`                |    1 |
| `order_items`                  |    20 | `orders`                      |   20 |
| `pre_trip_inspections`         |     0 | `route_leg_mileages`          |    0 |
| `route_template_stores`        |     0 | `route_templates`             |    0 |
| `route_vehicle_segments`       |    38 | `routes`                      |   38 |
| `schedule_months`              |     3 | `stores`                      |   12 |
| `template_routes`              |     0 | `template_stops`              |    0 |
| `vehicle_maintenance_policies` |     5 | `vehicle_maintenance_records` |    8 |
| `vehicle_maintenance_settings` |     1 | `vehicle_replacement_events`  |    0 |
| `vehicles`                     |    35 | `warehouses`                  |    6 |

## 匯入方式

### 1. 建立新的空白資料庫

使用新的 schema，例如 `3party_ver_snapshot`。不要對已有資料的原庫或上一版快照直接執行本次 SQL；本版保留來源 ID，與上一版重新編號的 ID 不相容。

從專案根目錄開 PowerShell，將路徑換成自己的 MySQL Client：

```powershell
$mysqlClient = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
& $mysqlClient --host=127.0.0.1 --port=3306 --default-character-set=utf8mb4 -u root -p
```

在提示時輸入自己的 MySQL 密碼，再執行：

```sql
CREATE DATABASE `3party_ver_snapshot`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

如果建庫失敗，先停止並確認原因。名稱已存在時換另一個新名稱，不要刪除既有資料庫。

### 2. 先結構，再資料

建庫成功後在同一個 MySQL Client 執行：

```sql
USE `3party_ver_snapshot`;
SOURCE database/snapshots/3party_ver/schema.sql;
```

確認沒有錯誤，再執行：

```sql
SOURCE database/snapshots/3party_ver/data.sql;

SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = DATABASE();

SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS drivers_count FROM drivers;
SELECT COUNT(*) AS gps_count FROM gps_pings;
SELECT COUNT(*) AS applications_count FROM driver_account_applications;

SELECT version, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

預期為 36 張表、20 張非測試訂單、8 位司機、14,284 筆 GPS、1 筆帳號申請；Flyway 最後版本為 `12`、`success=1`。所有表合計 15,057 筆，逐表筆數見 `manifest.json`。

`SOURCE` 路徑相對於啟動 MySQL Client 的工作目錄，使用正斜線。Workbench 也可選定新的預設 schema 後依序執行兩個檔案，每一步都先確認成功。SQL 使用 MySQL 8 語法與定序，不保證相容 MariaDB 或 MySQL 5.7。

### 3. 連接專案

只修改自己本機的 `backend/.env`，填入新建 schema 與有權限的 MySQL 帳密：

```dotenv
DB_URL=jdbc:mysql://127.0.0.1:3306/3party_ver_snapshot?serverTimezone=Asia/Taipei&rewriteBatchedStatements=true
DB_USER=<自己的 MySQL 帳號>
DB_PASSWORD=<自己的 MySQL 密碼>
APP_JWT_SECRET=<自己產生的隨機金鑰>
```

啟動方法見[主 README](../README.md#startup)。快照已包含相容的 Flyway 歷史，不必重新 baseline、repair 或手動逐一執行 V1～V12。

匯入的帳號均為快照代稱，原密碼雜湊已清除，不能用原本的帳密直接登入。依[主 README 第 7 章](../README.md#first-login)產生自己的 BCrypt，新增主管帳號；登入後再為需要使用的司機設定新密碼。沒有共用預設帳密。

歷史日期、時間與資料關聯保留，但精確座標及照片路徑已遮蔽，名稱及識別碼也已改寫。實際使用前須補正倉庫／門市資料；公開快照不能復原真實 GPS 或照片。歷史班表與路線不會自動變成今日任務。

## 驗證與更新

本次在新建的獨立暫存 schema 匯入 SQL，核對 36 張表、15,057 筆資料、遮蔽後所有保留欄位、32 組實體外鍵，以及本分支 Flyway V12 的 `validate`。驗證完畢移除暫存 schema，不修改來源資料庫。

這項檢查確認匯出、篩選與還原正確，不等同重新驗收所有網站功能。來源中原有的邏輯關聯缺口已列於上方與 manifest，沒有透過補造測試資料修復。

之後更新時，重新做一致性匯出與測試篩選，再核對筆數、原始欄位、升級紀錄及實體外鍵，成套更新兩個 SQL、manifest 和本指南。原始完整 SQL 與中繼 dump、實際 `.env`、照片與本機工具不加入 Git。

可從專案根目錄檢查檔案雜湊：

```powershell
Get-FileHash -Algorithm SHA256 database/snapshots/3party_ver/schema.sql
Get-FileHash -Algorithm SHA256 database/snapshots/3party_ver/data.sql
```

結果應與 `manifest.json` 的 `sha256` 相符。
