# 公開資料庫快照

本目錄提供從本機 `3party_ver` 匯出的**完整資料表結構與去識別化資料**，方便接手者了解資料關聯、在空白開發資料庫查看既有操作紀錄。匯出過程只讀取來源，未寫入或刪除原本的 `3party_ver`。

這份快照會改寫識別資訊、排除測試與敏感紀錄，不能拿來還原正式環境。正式備份仍須另行保存原始 SQL、照片及設定，並限制存取。

## 版本與檔案

| 項目         | 內容                                         |
| ------------ | -------------------------------------------- |
| 來源資料庫   | `3party_ver`                                 |
| 擷取時間     | 2026-11-26 08:07:04 UTC，即台北時間 16:07:04 |
| 來源 MySQL   | 8.0.46                                       |
| 結構版本     | Flyway V12                                   |
| 資料表       | 36 張，包括現存的舊版相容資料表              |
| 匯出資料     | 761 筆，包含 12 筆 Flyway 中繼資料           |
| 建議匯入環境 | MySQL 8.0／8.4 的新空白 schema               |

- [schema.sql](snapshots/3party_ver/schema.sql)：完整建表、索引與外鍵；不含業務資料、刪表或建使用者指令。
- [data.sql](snapshots/3party_ver/data.sql)：經處理的資料與對應的 Flyway 紀錄；以明確欄位名稱逐筆寫入。
- [manifest.json](snapshots/3party_ver/manifest.json)：各表來源／保留／排除筆數、處理政策與兩個 SQL 檔的 SHA-256。

`schema.sql` 與 `data.sql` 是同一組快照，請成套使用。業務資料在同一個唯讀一致性交易內擷取；後續來源資料變動不會自動更新 Git 中的檔案。

## 去識別化與排除範圍

| 類型                   | 處理方式／影響                                                                                             |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| ID 與關聯              | 主要資料 ID 重新編號，關聯同步改寫；不公開原始 ID 對照表                                                   |
| 主管／司機帳號與姓名   | 改成 `snapshot_admin_0001`、`snapshot_driver_0001`、主管／司機編號等代稱                                   |
| 密碼與金鑰             | 主管密碼改為空字串，司機密碼為 `NULL`；API Key 欄位清空，所有匯入帳號均無可用登入密碼                      |
| 聯絡資料               | 電話、聯絡人、地址及帳號申請資料移除                                                                       |
| 車牌／訂單／門市／倉庫 | 識別碼與名稱改成快照內唯一代稱                                                                             |
| 自由文字               | 備註、請假理由、異常描述、處理人等清空或改成 `REDACTED`，不保留原文                                        |
| 請假類型               | 非 `ABSENT` 類型統一為 `PERSONAL`，不公開原本健康或家庭相關類別                                            |
| 照片／附件             | 路徑清空；未打包任何實體照片、行前檢查照片、請假附件                                                       |
| GPS／座標              | 不匯出 `gps_pings` 與位置快取；可空的座標設為 `NULL`，門市與倉庫的必填座標設為 `0`                         |
| 私密訊息               | 帳號申請、私人訊息、便利貼與行前照片紀錄不匯出，表結構仍保留                                               |
| 測試紀錄               | 排除含 `DEMO`、`E2E`、`SMOKE`、`REGRESSION`、`CODEX`、`TEST`、測試、示範等可辨識標記的紀錄，以及其關聯紀錄 |
| 無效關聯               | 排除缺少必要父資料的紀錄；可空的遺失參照清為 `NULL`                                                        |
| 日期與數值             | 保留作業日期、時間、狀態、數量與里程等數值；識別與分類欄位依上表處理                                       |

**地理座標 `0` 只是清除位置後的佔位值，不是可用的配送地點。** 要實際定位、計算距離或排車前，須先在資源管理補正倉庫與門市的位置。沒有 GPS 軌跡或照片時，相關頁面無原始證據可供顯示。

此次辨識到 81 筆供應商帶有 `DEMO` 標記的訂單、1 筆 `E2E` 訂單與 1 台帶測試標記的車輛。連帶排除相關訂單明細、配送及路線紀錄；另外排除 11 筆缺少必要訂單的配送紀錄。細項與來源／排除筆數以 `manifest.json` 為準。

## 各表保留筆數

| 資料表                         | 筆數 | 資料表                        | 筆數 |
| ------------------------------ | ---: | ----------------------------- | ---: |
| `admin_sticky_notes`           |    0 | `admin_users`                 |    3 |
| `attendance_records`           |   12 | `delivery_records`            |    7 |
| `dispatch_templates`           |    0 | `distance_matrix_cache`       |    0 |
| `driver_account_applications`  |    0 | `driver_leave_request_events` |   32 |
| `driver_leave_requests`        |   32 | `driver_messages`             |    0 |
| `driver_shifts`                |  455 | `drivers`                     |    8 |
| `emergency_leave_requests`     |    1 | `exception_cases`             |    3 |
| `flyway_schema_history`        |   12 | `fuel_price_history`          |    9 |
| `gps_pings`                    |    0 | `mileage_logs`                |    1 |
| `order_items`                  |   20 | `orders`                      |   20 |
| `pre_trip_inspections`         |    0 | `route_leg_mileages`          |    0 |
| `route_template_stores`        |    0 | `route_templates`             |    0 |
| `route_vehicle_segments`       |   38 | `routes`                      |   38 |
| `schedule_months`              |    3 | `stores`                      |   12 |
| `template_routes`              |    0 | `template_stops`              |    0 |
| `vehicle_maintenance_policies` |    5 | `vehicle_maintenance_records` |    8 |
| `vehicle_maintenance_settings` |    1 | `vehicle_replacement_events`  |    0 |
| `vehicles`                     |   35 | `warehouses`                  |    6 |

## 匯入步驟

### 1. 準備新資料庫

先停止會連到**目標資料庫**的後端，使用另一個空白 schema，例如 `3party_ver_snapshot`。不要把這組 SQL 對著原本有資料的 `3party_ver` 執行，也不要用「遇到錯誤繼續」的方式匯入。

Windows 從專案根目錄開 PowerShell；替換成自己 MySQL Client 的路徑與管理帳號：

```powershell
$mysqlClient = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
& $mysqlClient --host=127.0.0.1 --port=3306 --default-character-set=utf8mb4 -u root -p
```

輸入自己的 MySQL 密碼。在 MySQL 提示字元先執行：

```sql
CREATE DATABASE `3party_ver_snapshot`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

**如果顯示資料庫已存在或其他錯誤，先停止，不要繼續。** 換一個確認不存在的名稱重新建立；不用刪除既有 schema 來騰出名稱。

### 2. 依序匯入

建庫成功後，在同一個 MySQL 視窗執行：

```sql
USE `3party_ver_snapshot`;
SOURCE database/snapshots/3party_ver/schema.sql;
```

確認結構匯入沒有錯誤，再執行：

```sql
SOURCE database/snapshots/3party_ver/data.sql;
SELECT COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema = DATABASE();
SELECT COUNT(*) AS orders_count FROM orders;
SELECT COUNT(*) AS drivers_count FROM drivers;
SELECT version, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

預期：36 張表、20 張訂單、8 位去識別化司機，Flyway 最後版本 `12`、`success=1`。完整筆數可與 `manifest.json` 比對。

`SOURCE` 使用正斜線，路徑相對於啟動 MySQL Client 時的工作目錄。檔案找不到時，先確認終端機是在專案根目錄；不要因此換成不明 SQL 檔。

Workbench 也可依序開啟兩個 SQL 檔：先將新空白 schema 設為預設，確認每個檔案成功後再執行下一個。此檔使用 MySQL 8 的語法及定序，不保證可直接匯入 MariaDB 或 MySQL 5.7。

### 3. 指向匯入後的資料庫

只在自己的 `backend/.env` 將資料庫名稱改成剛才建立的名稱，並填入對該 schema 有權限的 MySQL 帳密：

```dotenv
DB_URL=jdbc:mysql://127.0.0.1:3306/3party_ver_snapshot?serverTimezone=Asia/Taipei&rewriteBatchedStatements=true
DB_USER=<自己的 MySQL 帳號>
DB_PASSWORD=<自己的 MySQL 密碼>
APP_JWT_SECRET=<自己產生的隨機金鑰>
```

其餘啟動步驟見[主 README](../README.md#startup)。確認 IDE 或程序沒有另一組環境變數把連線覆蓋回舊資料庫。

快照已帶入對應的 `flyway_schema_history`，**不用再手動逐一執行 V1～V12，也不用重新 baseline 或 repair**。後續版本仍由 Flyway 正常升級。

### 4. 初始化自己的登入資料

匯入的主管／司機使用代稱，沒有可用密碼，不存在共用預設帳密。

1. 按[主 README 第 7 章](../README.md#first-login)在本機產生自己的 BCrypt 雜湊，新增自己的主管帳號。
2. 登入後核對倉庫、門市、司機與車輛；補正地址、座標、聯絡資料及必要的帳號設定。
3. 有需要使用的司機另行設定新密碼；不要把原始人員帳密或金鑰重新放入這些公開 SQL 檔。
4. 歷史日期、舊班表及舊路線保留原有時間，不會因匯入自動變成今天的配送任務。

## 匯出驗證與後續更新

本次已在獨立、隨機命名的暫存 schema 實際匯入兩個 SQL，核對：

- 36 張表、761 筆資料的筆數。
- 32 組實體外鍵沒有遺失父資料。
- MySQL 必填欄位、唯一索引及 SQL 匯入成功。
- Flyway 使用本分支 migration 完成 `validate`，版本到 V12。
- 沒有可用密碼、API Key、電話、照片路徑及原始 GPS 資料。

驗證用 schema 已刪除，未對原本資料庫執行升級、清理或還原。此驗證確認快照可匯入與結構相容，不代表所有頁面或正式操作均已重新驗收。

之後更新時，重新從指定資料庫做一致性匯出、套用去識別化及測試篩選，再核對資料關聯與還原結果，最後更新 SQL、`manifest.json` 和本文件。不要直接覆蓋為原始 dump。

可用 PowerShell 檢查檔案雜湊：

```powershell
Get-FileHash -Algorithm SHA256 database/snapshots/3party_ver/schema.sql
Get-FileHash -Algorithm SHA256 database/snapshots/3party_ver/data.sql
```

結果應與 `manifest.json` 中的 `sha256` 一致。實際 `.env`、原始備份、照片、GPS 與匯出中繼檔仍應留在 Git 外。
