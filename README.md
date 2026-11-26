# logistics_dispatch_3party_ver

物流調度與司機配送系統：主管建立訂單、安排人車與路線，司機完成打卡、行前檢查、倉庫點交、配送及收車，主管再追蹤異常與營運報表。

這份指南寫給第一次接觸專案的人。先依環境設定完成啟動，再依操作章節走完一筆配送；不需要先熟悉 Spring Boot、Angular 或 Docker 才能閱讀。

> 核對日期：2026-11-26。本文依目前分支的程式、設定與 migration 整理，不代表所有環境已完成全功能驗收；後續更新仍須一起核對版本檔。
>
> **沒有預設登入帳密。** MySQL 帳號不是網站的主管／司機帳號。Git 不含實際 `backend/.env`、正式資料、上傳照片或 OSRM 路網，下載程式不會自動取得這些資料。

## 閱讀順序

1. [用途與使用者](#overview)
2. [先認識名詞](#glossary)
3. [架構、目錄、連接埠與技術](#architecture)
4. [必要軟體與下載程式](#prerequisites)
5. [MySQL 與環境變數](#configuration)
6. [啟動後端與兩個前端](#startup)
7. [建立第一個主管與登入](#first-login)
8. [OSRM 道路服務](#osrm)
9. [完整操作流程](#workflow)
10. [訂單與相關狀態](#states)
11. [營運報表、歷史查詢與 Excel](#reports)
12. [資料庫升級、照片與備份](#data)
13. [API、授權與推播](#api)
14. [建置、測試與驗收](#verification)
15. [正式部署與 CI/CD](#deployment)
16. [常見問題](#troubleshooting)
17. [開發與 Git 提交](#development)
18. [文件與程式入口](#references)

第一次只想成功登入，先讀第 4～7 章；要跑完整配送，再接第 8～11 章。接手維運或部署的人請務必讀第 12～17 章，不要只複製啟動指令。

<a id="overview"></a>

## 1. 用途與使用者

### 1.1 系統解決什麼問題

主管需要知道哪些訂單待確認、尚未排車、正在配送或已完成；哪些司機今天出勤、哪台車容量足夠且可用；路線如何安排、配送是否異常、補送到哪一步，以及各倉實際表現是否有紀錄可查。

本系統是**物流決策輔助工具**。自動排車提供建議，不取代主管的核對、調整與發布決定。

| 使用者／元件 | 資料夾             | 工作                                              |
| ------------ | ------------------ | ------------------------------------------------- |
| 主管／調度員 | `frontend/`        | 看板、訂單、人車、班表、異常、報表及個人設定      |
| 司機         | `frontend-driver/` | 打卡、任務、行前檢查、點交、配送、GPS、請假與訊息 |
| GPS 開發工具 | `gps-api-tester/`  | 模擬位置與測試 API，並非正式配送必備元件          |
| 共用業務後端 | `backend/`         | 權限、規則、資料庫、檔案、排車、報表與推播        |

主管端程式中的 `DISPATCHER` 對應**後端 JWT 的 `ADMIN`**；司機角色為 `DRIVER`。不要把前端命名直接當成後端角色。

### 1.2 不包含或不能直接假設的能力

- 不是購物商城，不處理商品銷售、付款或金流。
- 目前沒有 AI 助理，不需要填 OpenAI API Key。
- 司機端是網頁／PWA，不保證瀏覽器關閉、手機休眠後持續回傳 GPS。
- 報表不是薪資結算、法遵證明或不可變的歷史快照。
- 地圖能顯示不代表 OSRM 或自動排車正常。
- 健康檢查 `UP` 不等於登入、道路服務、原生引擎及手機操作都已驗收。

<a id="glossary"></a>

## 2. 先認識名詞

| 名詞              | 意思                                             |
| ----------------- | ------------------------------------------------ |
| 前端              | 瀏覽器看到的頁面，主管與司機是兩個獨立程式       |
| 後端／API         | 接收請求、檢查權限、執行規則並讀寫資料的服務     |
| MySQL／schema     | 資料庫服務及資料庫名稱，不是某一個 SQL 檔案      |
| migration／Flyway | 版本化的 SQL 結構變更，以及管理它們的工具        |
| OSRM              | 根據道路資料計算開車路徑與距離的獨立服務         |
| OR-Tools          | 後端內的排車引擎，處理距離、容量、指定車輛等條件 |
| JWT／Token        | 登入取得的存取憑證，包含使用者、角色及有效期限   |
| BCrypt            | 密碼雜湊，不是可還原原密碼的加密                 |
| proxy             | 將前端的 `/api` 等請求轉送給後端                 |
| CORS              | 對瀏覽器來源的限制，不是帳號登入權限             |
| PWA               | 可加入手機主畫面的網頁應用，可快取部分靜態資源   |
| CI／CD            | 自動檢查／建置與部署流程                         |
| 容器              | 獨立的執行環境；容器內的 `localhost` 指容器自己  |

<a id="architecture"></a>

## 3. 架構、目錄、連接埠與技術

### 3.1 本機架構

```text
主管頁面 :4200 ── Angular 開發代理 ─┐
                                     ├─ /api、/uploads ─→ Spring Boot :8080
司機頁面 :4001 ── Angular 開發代理 ─┘                          │
                                                              ├─ MySQL :3306
GPS 工具 :4204 ── 直接呼叫 API／CORS ──────────────────────────┤
                                                              ├─ OSRM :5001
                                                              ├─ OR-Tools（後端程序內）
                                                              └─ uploads/ 照片檔案

底圖、字型、天氣與地址查詢另有外部網路服務。
```

**OSRM 與 OR-Tools 不是同一個東西。** OSRM 有 HTTP 網址和連接埠；OR-Tools 是 Java 依賴與原生程式庫，不需要另開一個埠。

### 3.2 目錄

```text
logistics_dispatch_3party_ver/
├── README.md                    本指南
├── backend/
│   ├── build.gradle             依賴、Java 21 工具鏈與測試設定
│   ├── gradlew / gradlew.bat     專案自帶的 Gradle 啟動器
│   ├── .env.example             本機設定範本
│   └── src/
│       ├── main/java/com/example/backend/
│       │   ├── controller/      API 入口
│       │   ├── service/         業務流程、交易與排程
│       │   ├── dao/             資料查詢／Repository
│       │   ├── entity/          資料表模型
│       │   ├── dto/             API 輸入／輸出格式
│       │   ├── dispatch/        OSRM、OR-Tools 等整合
│       │   ├── config/          JWT、權限、推播與檔案設定
│       │   ├── constants/       共用狀態與常數
│       │   └── excition/         例外處理
│       ├── main/resources/
│       │   ├── application.properties
│       │   └── db/migration/    資料庫結構版本
│       └── test/                後端測試
├── frontend/                    主管端 Angular
├── frontend-driver/             司機端 Angular／PWA
├── gps-api-tester/              獨立 GPS 開發工具
├── osrm/                        路網與啟動說明
├── deploy/                      Compose、Dockerfile、Nginx
├── .github/workflows/           CI／映像建置與部署
├── http/                        HTTP 手動請求範例
├── scripts/                     維護、驗證及歷史資料腳本
└── docs/                        功能文件與歷史設計紀錄
```

`excition/` 與 `dto/respones/` 是目前保留的拼字，找程式時請照實際路徑。

### 3.3 連接埠與網址

| 元件          | 本機預設                          | 注意                         |
| ------------- | --------------------------------- | ---------------------------- |
| 主管端        | `http://localhost:4200`           | `frontend`                   |
| 司機端        | `http://localhost:4001`           | 已在其 Angular 設定指定      |
| GPS 開發工具  | `http://localhost:4204`           | 選用                         |
| 後端          | `http://localhost:8080`           | 主要提供 API，不是主管操作頁 |
| 本機 MySQL    | `127.0.0.1:3306`                  | 以實際安裝為準               |
| 本機 OSRM     | `http://127.0.0.1:5001`           | 主機 5001 → 容器 5000        |
| Compose MySQL | 主機 `127.0.0.1:3307` → 容器 3306 | 可用 `MYSQL_PORT` 調整       |
| Compose 內部  | `backend:8080`、`osrm:5000`       | 基礎檔不直接對外發布這兩個埠 |
| 正式 Nginx    | 80／443                           | 網站及 HTTPS                 |

本機可使用 `3party_ver`；現有 CI／Compose 範本使用 `logistics`。**它們不會自動共享資料。** 請看 JDBC URL 的主機、埠及 schema，而不是只看名稱。

### 3.4 技術

| 層次       | 目前使用                                                          |
| ---------- | ----------------------------------------------------------------- |
| 後端       | Java 21、Spring Boot 4.0.7、Security、JPA、WebSocket／STOMP       |
| 建置       | Gradle Wrapper 9.5.1，通常不必另裝系統 Gradle                     |
| 前端       | Angular 22、Material／CDK、RxJS、TypeScript 6                     |
| 地圖       | MapLibre GL JS 6、OpenFreeMap 底圖樣式                            |
| 報表繪圖   | 報表元件本身的繪圖／樣式，不是舊文件中的 Chart.js 依賴            |
| Excel      | 主管端使用 SheetJS `xlsx`                                         |
| 排車／道路 | OR-Tools 9.12.4544、OSRM MLD                                      |
| 資料庫     | MySQL；CI／Compose 使用 8.4，既有本機也可能是 8.0                 |
| 外部服務   | Nominatim 地址查詢、Open-Meteo 天氣、中油牌價、圖磚及 Google 字型 |

不能宣稱整套系統完全離線。即使自架資料庫和 OSRM，底圖、字型、天氣、地址查詢與初次套件下載仍可能需要網路。

<a id="prerequisites"></a>

## 4. 必要軟體與下載程式

### 4.1 安裝檢查

| 軟體                   | 要求／用途                                   | 檢查指令                          |
| ---------------------- | -------------------------------------------- | --------------------------------- |
| Git                    | 下載與版本管理                               | `git --version`                   |
| JDK 21                 | 必須有編譯器，不能只是 JRE                   | `java -version`、`javac -version` |
| Node.js                | 建議與 CI 一致的 22.x，**至少 22.22.3**      | `node --version`                  |
| npm                    | 兩前端 package.json 目前宣告 npm 11.12.1     | `npm --version`                   |
| MySQL                  | 建議與 CI 一致的 8.4；需有可連線資料庫與帳號 | `mysql --version` 或 Workbench    |
| Docker／Docker Desktop | 跑 OSRM；Windows 需可執行 Linux 容器         | `docker version`、`docker info`   |
| IntelliJ IDEA          | 選用，也可直接以終端機啟動                   | 開啟 Gradle 專案                  |
| 瀏覽器                 | 桌面檢查與手機司機操作                       | 手機正式使用需 HTTPS／定位權限    |

Node 要求來自目前鎖定檔的 Angular `engines`，不是任意 Node 22 都可用。更新依賴後請重查，不要直接重建鎖定檔來消除錯誤。

不需要全域 Angular CLI；使用 `npm start`、`npm run build` 或專案的 `npx ng`。PowerShell 若無法使用 npm 的官方 PowerShell 啟動腳本，可使用 `npm.cmd`／`npx.cmd`，不必為此放寬安全政策。

官方下載／安裝入口：[Git](https://git-scm.com/downloads/)、[Microsoft JDK](https://learn.microsoft.com/en-us/java/openjdk/download)、[Node.js](https://nodejs.org/en/download)、[MySQL Community](https://dev.mysql.com/downloads/)、[Docker Desktop](https://docs.docker.com/desktop/)。

Windows 新安裝時：

1. 依作業系統選正確架構，例如一般 Windows x64；不是把所有安裝包都下載。
2. JDK 選 **21**，Node 選符合上表的 **22.x**，不要只按下載頁預設的最新大版本。
3. MySQL 除 Workbench 外也要有執行中的 **Server**，記下自設管理密碼及埠；只有 Workbench 不等於有資料庫服務。
4. Docker Desktop 安裝完成後還要啟動引擎；依官方文件確認 Linux 容器／WSL 等需求。
5. 關閉再開終端機，執行上表版本指令，確認 PATH 生效，再下載或啟動專案。

### 4.2 JDK 的四個位置

1. `JAVA_HOME`：指向 JDK 根目錄，不是 `bin` 或 `java.exe`。
2. IntelliJ **Project SDK**：JDK 21，語言等級 21。
3. IntelliJ **Gradle JVM**：可用的 JDK 21。
4. `BackendApplication` Run Configuration：若另指定 JRE，也要正確。

修改後重新載入 Gradle；必要時先儲存工作，再重開 IDE。別人的本機 SDK 名稱與絕對路徑不會隨 Git 帶到你的電腦。

如果只想在目前 PowerShell 選擇 JDK，可先替換下面路徑再執行；只影響此視窗，不會永久改系統設定：

```powershell
$env:JAVA_HOME = "<你的 JDK21 安裝根目錄，不含 bin>"
$env:Path = (Join-Path $env:JAVA_HOME "bin") + ";" + $env:Path
java -version
javac -version
```

Windows 若封鎖 `management.dll`、`extnet.dll` 或 OR-Tools DLL，請看[錯誤排查](#troubleshooting)，不要把政策封鎖當成程式語法錯誤。

### 4.3 下載

以目前使用的 `version1` 分支為例，維護者指定其他分支時請換成對應名稱：

```powershell
git clone --branch version1 https://github.com/wumo26/logistics_dispatch_3party_ver.git
cd logistics_dispatch_3party_ver
git branch --show-current
```

已有資料夾時，先用 `git status` 檢查修改，再更新；不要下載另一份直接覆蓋未提交的工作。

本文的「專案根目錄」指包含 `README.md`、`backend/`、`frontend/` 的資料夾。

<a id="configuration"></a>

## 5. MySQL 與環境變數

### 5.1 空白開發資料庫

先啟動 MySQL，用有建庫權限的帳號連線：

```powershell
mysql -u root -p
```

`-p` 要輸入的是安裝 MySQL 時自設的管理密碼，不是專案提供的密碼。在 MySQL 或 Workbench 執行：

```sql
CREATE DATABASE IF NOT EXISTS `3party_ver`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

可請資料庫管理者建立只限此 schema 的開發帳號：

```sql
CREATE USER 'logistics_app'@'localhost'
  IDENTIFIED BY '<自行設定的開發資料庫密碼>';
GRANT ALL PRIVILEGES ON `3party_ver`.* TO 'logistics_app'@'localhost';
```

- `<...>` 要替換，不能原樣當成密碼使用。
- 帳號已存在時不要刪掉重建或任意改密碼。
- 帳號 host 也影響授權；容器或遠端連線須依實際來源設定。
- 開發 migration 需要建表／改表權限；正式環境應另評估應用帳號與 migration 帳號分工。
- 已有資料表的資料庫不是「空白環境」；先看[資料庫升級](#data)。
- **不要手動依序匯入所有 migration SQL**，空白資料庫的建表交給 Flyway。

### 5.2 backend/.env

從專案根目錄複製範本；原檔存在時不覆蓋：

```powershell
if (-not (Test-Path -LiteralPath "backend/.env")) {
    Copy-Item -LiteralPath "backend/.env.example" -Destination "backend/.env"
}
```

以文字編輯器填入自己的值：

```dotenv
DB_URL=jdbc:mysql://127.0.0.1:3306/3party_ver?serverTimezone=Asia/Taipei&rewriteBatchedStatements=true
DB_USER=logistics_app
DB_PASSWORD=<自行設定的開發資料庫密碼>
APP_JWT_SECRET=<自己產生的隨機金鑰>
OSRM_BASE_URL=http://127.0.0.1:5001
SHOW_SQL=false
```

產生 JWT 金鑰：

```powershell
node -e "console.log(require('node:crypto').randomBytes(48).toString('base64'))"
```

貼到 `APP_JWT_SECRET=` 後面。它用來簽發登入憑證，**不是資料庫或網站登入密碼**，不要公開或提交。

注意：

- 每行一個 `KEY=VALUE`，不要加反斜線表示換行。
- 此檔以 Spring properties 格式讀取，不是 Shell 腳本。
- 建議只維護 `backend/.env`；另有根目錄 `.env` 時容易混淆。
- 程式支援從根目錄或 `backend/` 啟動時匯入對應檔案；從其他目錄跑 jar 要另指定設定位置或環境變數。
- 啟動程序環境變數可覆蓋檔案；IDE 保留舊值時，改檔仍可能連舊資料庫。
- Workbench 開哪個分頁不會改變後端連線，`DB_URL` 才是依據。
- 舊 `APP_CRYPTO_PASSWORD`／`APP_CRYPTO_SALT` 不是目前設定中的必要啟動項目。
- 實際 `.env` 已被 Git 忽略；範本應保留空白或非機密值。

### 5.3 設定對照

| 變數                                           | 用途                     | 預設／注意                                             |
| ---------------------------------------------- | ------------------------ | ------------------------------------------------------ |
| `DB_URL`                                       | JDBC 主機、埠、schema    | 必填，沒有內建開發資料庫                               |
| `DB_USER`、`DB_PASSWORD`                       | MySQL 帳密               | 自己的資料庫帳號                                       |
| `APP_JWT_SECRET`                               | JWT 金鑰                 | 至少 32 bytes，建議用隨機值；亦支援舊別名 `JWT_SECRET` |
| `JWT_EXPIRATION_MINUTES`                       | Token 效期               | 480 分鐘；更換金鑰會使舊 Token 無效                    |
| `OSRM_BASE_URL`                                | 道路服務                 | `http://localhost:5001`                                |
| `SHOW_SQL`                                     | Hibernate SQL 輸出       | 程式預設 true；建議明確設 false                        |
| `CORS_ALLOWED_ORIGINS`                         | 瀏覽器允許來源，逗號分隔 | 預設 localhost／127.0.0.1 的 4200、4001、4204          |
| `DISPATCH_MAX_STORE_WAREHOUSE_DISTANCE_METERS` | 可排程直線半徑           | 30000 公尺，非道路里程                                 |
| `GPS_FRESHNESS_MINUTES`                        | 即時位置過期門檻         | 10 分鐘                                                |
| `GPS_RETENTION_YEARS`                          | 原始 GPS 保存期限        | 5 年，影響清除排程                                     |
| `CLOCK_OUT_RADIUS_METERS`                      | 收車／下班的倉庫鄰近範圍 | 200 公尺                                               |
| `DRIVER_PHOTOS_DIR`                            | 大頭照目錄               | `uploads/driver-photos`                                |
| `DELIVERY_PHOTOS_DIR`                          | 交貨照片目錄             | `uploads/delivery-photos`                              |
| `MILEAGE_PHOTOS_DIR`                           | 儀表照片目錄             | `uploads/mileage-photos`                               |
| `LEAVE_EVIDENCE_DIR`                           | 請假附件目錄             | `uploads/leave-evidence`                               |
| `CPC_SYNC_CRON`                                | 牌價同步排程             | 每日台北時間 00:15；啟動時另同步一次                   |
| `GEOCODE_BASE_URL`                             | 地址查詢                 | Nominatim 公開服務                                     |
| `GEOCODE_USER_AGENT`                           | 地址查詢的程式識別       | 部署應設定可辨識資訊                                   |

行前照片另由屬性 `app.storage.pre-trip-dir` 控制，預設 `uploads/pre-trip`。不要自行假設存在未在程式使用的環境變數名稱。

<a id="startup"></a>

## 6. 啟動後端與兩個前端

先完成「連到資料庫、開啟登入頁」，再設定完整道路服務。OSRM 未開時後端仍可啟動，但道路里程／排車不會因此自動可用。

### 6.1 終端機 A：後端

Windows PowerShell，從根目錄開始：

```powershell
cd backend
./gradlew.bat --version
./gradlew.bat classes
./gradlew.bat bootRun
```

macOS／Linux：

```bash
cd backend
chmod +x gradlew
./gradlew --version
./gradlew classes
./gradlew bootRun
```

分別是查看 Wrapper／JVM、編譯主要程式、啟動服務。`classes` **不是完整測試**。初次需下載依賴；啟動會連 MySQL 並檢查 migration。看到 `Started BackendApplication` 才算啟動完成，終端機需保持開啟。

另開 PowerShell：

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/actuator/health"
```

預期 `status: UP`。後端根網址顯示找不到頁面不一定是錯誤，主管頁在 4200。

IntelliJ 可載入 `backend/build.gradle` 所屬的 Gradle 專案，執行 `com.example.backend.BackendApplication`。根目錄沒有 `build.gradle` 是正常結構，不是遺失檔案。

### 6.2 終端機 B：主管端

從根目錄另開終端機：

```powershell
cd frontend
npm ci --ignore-scripts
npm start
```

開啟 `http://localhost:4200/login`。

### 6.3 終端機 C：司機端

從根目錄另開終端機：

```powershell
cd frontend-driver
npm ci --ignore-scripts
npm start
```

開啟 `http://localhost:4001/login`。兩個前端各有自己的 `package-lock.json`／`node_modules`，只安裝主管端不會替司機端完成安裝。

`npm ci` 依鎖定檔安裝；`--ignore-scripts` 與目前 CI 一致，不影響後續執行 `npm start`。不必另用全域 `ng serve`。

### 6.4 連線與停止

- 前端以相對 `/api/...` 呼叫，兩份 `proxy.conf.json` 轉到 8080，並代理 `/uploads` 與 WebSocket。
- 改後端埠要同步改兩份 proxy；改前端埠要核對 CORS、proxy 的 Origin 與實際來源。
- `localhost` 與 `127.0.0.1` 是不同 origin，請固定一種網址登入。
- 開發代理不等於正式設定；production 使用 Nginx。
- 前景服務用 Ctrl+C 停止；IDE 服務用對應 Run 視窗停止；OSRM 用 `docker stop logistics-osrm`。
- 先查明程序用途，不要為釋放埠一次結束所有 Java、MySQL 或 Docker 服務。

<a id="first-login"></a>

## 7. 建立第一個主管與登入

### 7.1 沒有預設帳號

Flyway 建表但不提供可登入的預設主管；`/api/admin-users` 需要 ADMIN，所以空白資料庫的第一個主管須由維運者初始化。

`DB_USER=root` 不代表存在「root／root」網站帳號。既有環境請向維護者取得主管、司機各自的帳號；不要因登入失敗清空資料或覆寫帳密。

### 7.2 全新環境初始化

先讓後端完成空白 schema 的 migration，再由有權限者產生 BCrypt。以下是選用 Python 的方法，Python／bcrypt **不是網站日常執行的必要依賴**。沒有 Python 時可請維護者使用核准的本機 BCrypt 工具；不要把正式密碼送給線上雜湊網站。

```powershell
python -m pip install bcrypt
python -c "import bcrypt,getpass; p=getpass.getpass('Admin password (8-12 characters): '); assert 8 <= len(p) <= 12, 'Password must contain 8-12 characters'; print(bcrypt.hashpw(p.encode('utf-8'), bcrypt.gensalt()).decode('utf-8'))"
```

macOS／Linux 可能使用 `python3`；套件依自己的 Python 環境管理規則安裝。

輸入自選密碼，複製產生的完整雜湊。在**確認過的開發資料庫**執行，全部換成自己的值：

```sql
USE `3party_ver`;
INSERT INTO admin_users (account, password, name, phone)
VALUES ('<主管帳號>', '<完整 BCrypt 雜湊>', '<主管名稱>', '<主管手機號碼>');
```

這是必要帳號初始化範本，不是 demo 資料，也不會自動執行。既有環境不能重複插入或覆寫同名帳號。密碼及雜湊都不應提交 Git。

目前主管建立／修改密碼限制 **8～12 字元**。手機號碼用於目前的帳號核對／忘記密碼流程，不應任填他人的資料。

### 7.3 驗證登入

主管登入成功後應進入 `/dispatch/dashboard`。也可用 PowerShell 互動式輸入，避免密碼寫入命令歷史：

```powershell
$credential = Get-Credential -Message "輸入網站主管帳號，不是 MySQL 帳號"
$loginBody = @{
    account = $credential.UserName
    password = $credential.GetNetworkCredential().Password
} | ConvertTo-Json

$authResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/auth/admin/login" -ContentType "application/json" -Body $loginBody
$apiHeaders = @{ Authorization = "Bearer " + $authResponse.accessToken }
Invoke-RestMethod -Uri "http://localhost:8080/api/warehouses" -Headers $apiHeaders
```

不要公開完整 `$authResponse`，其中含有效 Token。空白資料庫的倉庫清單為空正常。登入後才能用有權限的 API 建其他主管，並在人車資源管理司機；兩種角色的 Token 不能互換。

<a id="osrm"></a>

## 8. OSRM 道路服務

### 8.1 路網不是只有一個容器

- 原始檔為 `taiwan-latest.osm.pbf`；前處理後產生整組 `.osrm*`。
- 路網可占數 GB 磁碟，前處理時間與記憶體需求依資料大小、硬體而變，不保證幾分鐘完成。
- Docker Desktop 與主機都要有足夠記憶體。
- 倉庫、門市及測試座標必須在路網範圍內。
- 前處理與服務必須使用相容的同版本映像；正式維運應固定 tag／digest。
- 原始資料與預處理檔不進 Git，也不能只複製其中一個衍生檔。

### 8.2 首次設定：PowerShell

從根目錄開始；已有可用路網時不要覆蓋原始檔後混用舊衍生檔。

```powershell
cd osrm
Invoke-WebRequest -Uri "https://download.geofabrik.de/asia/taiwan-latest.osm.pbf" -OutFile "taiwan-latest.osm.pbf"
$osrmDirectory = (Get-Location).Path
docker pull ghcr.io/project-osrm/osrm-backend
$osrmImage = docker image inspect ghcr.io/project-osrm/osrm-backend --format "{{.Id}}"
```

以下使用同一個本機映像 ID，**每一步成功後才做下一步**：

```powershell
docker run --rm --mount "type=bind,source=$osrmDirectory,target=/data" $osrmImage osrm-extract -p /opt/car.lua /data/taiwan-latest.osm.pbf
docker run --rm --mount "type=bind,source=$osrmDirectory,target=/data" $osrmImage osrm-partition /data/taiwan-latest.osrm
docker run --rm --mount "type=bind,source=$osrmDirectory,target=/data" $osrmImage osrm-customize /data/taiwan-latest.osrm
```

再啟動：

```powershell
docker run -d --name logistics-osrm --restart unless-stopped --publish 127.0.0.1:5001:5000 --mount "type=bind,source=$osrmDirectory,target=/data,readonly" $osrmImage osrm-routed --algorithm mld /data/taiwan-latest.osrm
```

綁 `127.0.0.1` 是避免開發服務直接公開。若後端也跑在容器，請依容器網路改設定，不是繼續照抄 `localhost`。

Bash 指令另見 [osrm/README.md](osrm/README.md)。PowerShell／Bash 的變數與換行語法不同，不要混貼。

### 8.3 驗證與日常啟停

```powershell
docker ps --filter "name=logistics-osrm"
docker logs --tail 50 logistics-osrm
curl.exe "http://127.0.0.1:5001/route/v1/driving/121.5170,25.0478;121.5200,25.0500?overview=false"
```

正常道路回應應有 `"code":"Ok"` 及路線資料。容器存在不代表正在執行或已載入路網；根網址也不是管理頁。

之後只需：

```powershell
docker start logistics-osrm
docker stop logistics-osrm
```

同名容器已存在時，用 `docker ps -a`、`docker inspect logistics-osrm` 與日誌核對埠、image、掛載位置。不要一直重複建立同名容器，更不要任意刪除 MySQL 容器。

<a id="workflow"></a>

## 9. 完整操作流程

### 9.1 主管端頁面

| 路徑                  | 畫面／工作                                       |
| --------------------- | ------------------------------------------------ |
| `/login`              | 主管登入及目前的帳號恢復入口                     |
| `/dispatch/dashboard` | 今日配送總覽：看板、編組、排車、調整、發布與進度 |
| `/dispatch/orders`    | 訂單審核：建單／匯入、日期、倉庫與商品明細       |
| `/dispatch/resources` | 倉庫、門市、司機、車輛、保養與退役               |
| `/dispatch/schedules` | 月班表、每日班次與發布                           |
| `/dispatch/anomalies` | 異常與後續補送處理                               |
| `/dispatch/reports`   | 營運彙總、比例與明細連結                         |
| `/dispatch/history`   | 歷史篩選、逐筆核對與 Excel                       |
| `/dispatch/profile`   | 個人資料與密碼設定                               |

司機端主要是 `/login` 與 `/dashboard`；班表、任務、請假、訊息等操作在工作頁內，不是主管端路徑的角色切換。

### 9.2 第一次建主檔

依資料相依關係建立：

1. **倉庫**：名稱、有效座標、啟用狀態。
2. **門市**：名稱、地址／座標、收貨時段、啟用狀態。
3. **司機**：帳號、密碼、所屬倉庫、啟用狀態及班表設定。
4. **車輛**：倉庫、車牌、容量、噸位、初始儀表及保養基準。
5. **保養／退役規則**：依真實車隊資料設定，不能填猜測里程。
6. **班表**：建立月份，把上班日設為 `WORK`，完成後發布。
7. **訂單**：門市、出貨倉庫、預定配送日期、箱數、商品資料，審核為已確認。

訂單匯入檔請依目前畫面的格式及驗證提示，不要把 Excel／CSV 訂單匯入與資料庫 SQL 匯入混為一談。

#### 訂單匯入的具體格式

在訂單頁使用「下載 Excel 範本」，支援未加密的 `.xlsx`、`.xls`、`.csv`。程式只讀第一個工作表，表頭需放在前 10 列內。建議直接保留範本表頭：

```csv
訂單編號,門市,出貨倉,來源廠商,品項,箱數,配送日期,備註
```

| 欄位     | 填寫方式                                                   |
| -------- | ---------------------------------------------------------- |
| 訂單編號 | 必要，不可與檔案內或已存在訂單重複，最多 30 字             |
| 門市     | 必要，須能對應已建立的門市名稱或代號；重名不明確時先修主檔 |
| 出貨倉   | 已建立的倉庫名稱或代號；留白時可由匯入畫面的預設倉庫套用   |
| 來源廠商 | 選用，最多 100 字                                          |
| 品項     | 選用的品項描述，最多 255 字；不是任意新增門市／倉庫的入口  |
| 箱數     | 必要的箱數，依畫面驗證有效整數；不是商品重量或噸位         |
| 配送日期 | 必要，建議 `YYYY-MM-DD` 或正確的 Excel 日期格              |
| 備註     | 訂單備註，不是行前檢查或配送簽收證明                       |

未提供狀態欄時預設 `PENDING_CONFIRM`。先預覽並修正列號對應的錯誤，再送出；不要把範本中的示範列當成真正訂單匯入。匯入建立訂單不等於審核、排車或發布，後端仍會驗證。

基本規則：

- 門市與倉庫須啟用且座標有效。
- 門市距倉庫的直線半徑預設不可超過 30 公里。
- 司機、車輛的倉庫歸屬、班表及已被占用狀態會影響可選資源。
- 車輛須有容量，且不能是保養、退役或未通過出車檢核的狀態。

### 9.3 排車與發布

```text
訂單待確認 → 主管確認 → 已確認的待排訂單
    → 自動排車或主管編組／調整
    → 路線草稿 DRAFT
    → 主管核對及發布 PUBLISHED
    → 司機看到本人、對應日期的任務
```

- OSRM 先算道路距離矩陣，OR-Tools 再按條件求解。
- 容量不足或未安排的訂單可能仍在待排區；不能只因請求成功就認定全部已排。
- 指定給車輛的訂單有對應限制。
- 手動改派仍需通過後端規則，不是繞過資源／維護檢查。
- **班表發布**與**配送路線發布**不同，兩者都需要完成。
- 撤回／重排會影響司機任務，不是單純把卡片藏起來。
- 已出車或有配送歷史的任務不能任意撤回來抹除紀錄，應走交接／異常流程。

### 9.4 司機一天的操作

依當天畫面提示與後端檢核完成：

1. 用啟用的司機帳號登入。
2. 確認今天有已發布 `WORK` 班次，完成上班打卡。
3. 確認主管已發布今天且指派給本人的路線。
4. 完成酒測、車輛檢點、行車紀錄器及三類照片的行前檢查。
5. 倉庫點交：核對箱數、商品及實點數量。
6. 登記真實儀表里程與必要照片，依畫面完成出車。
7. 到門市登記抵達，再記錄交付、短少／損壞或無人簽收。
8. 有異常就回報，不把未交付硬填為完整交付。
9. 回到規定倉庫範圍，登記結束儀表里程並收車。
10. 完成下班；請假、交接及未完成任務走相應流程。

行前檢查目前採用系統的 **0.00 mg/L** 出車規則，不是法規門檻說明。不通過時禁止點交與出車，應通知主管。

路線撤回、人車或版本變更可能使檢查失效；不能把另一條路線／版本的檢查拿來使用。

### 9.5 里程、保養與收車

| 距離種類     | 來源                         | 用途                           |
| ------------ | ---------------------------- | ------------------------------ |
| 規劃道路里程 | OSRM                         | 規劃、估算油費及出車前保養餘額 |
| 儀表總里程   | 真實出車／收車登錄及車輛資料 | 車輛累積讀數與保養基準         |
| GPS 結算里程 | 有效軌跡結算                 | 報表實際紀錄及來源核對         |

- 開始里程須符合目前車輛儀表值等檢核。
- 收車與下班需要有效定位、規定倉庫範圍，預設半徑 200 公尺。
- 先結束里程，才能完成下班。
- 維修、保養、退役會影響排車／發布，不只是文字標籤。
- 保養次數與基準來自完成紀錄，OSRM 預估不能冒充真實里程。
- 細節見 [車輛保養](docs/vehicle-maintenance.md)，文件中的歷史 SQL 版本仍須與本分支程式核對。

### 9.6 GPS、請假與訊息

- GPS 接受狀態由後端檢查，目前為 `WORKING` 或 `OVERTIME`；休息、已下班或沒有工作紀錄時不可上傳。
- 司機 ID 從 JWT 取得、時間由後端產生，不能自行冒用其他人。
- **目前司機追蹤的定時器間隔是 1 秒**，見 `driver-gps-tracking.service.ts`，不是設定檔註解中的 5 分鐘。定位及請求可能重疊、延遲、失敗；部署前須評估資料量、耗電與頻率。
- 預設超過 10 分鐘的即時位置視為過期；未知位置不能當成座標 0。
- 手機定位需要安全來源／HTTPS 與授權；`localhost` 的開發例外不代表手機的 `http://192.168...` 可用。
- 請假包含排假、當日臨請與事後補請，會檢查班次、日期、整天／部分時段及重疊申請。
- 訊息、看板與請假通知使用 WebSocket／STOMP；代理錯誤、斷線與 Token 過期會影響即時更新。
- 背景分頁、鎖屏與省電模式會限制網頁，不可視為原生背景定位服務。

### 9.7 選用 GPS 開發工具

主系統啟動後，另開終端機，從根目錄：

```powershell
cd gps-api-tester
pnpm install --frozen-lockfile
pnpm dev
```

開啟 `http://localhost:4204`，API Base URL 用 `http://localhost:8080`。此工具使用獨立 pnpm 鎖定檔，不參與兩個 Angular 的標準啟動。

它會真的呼叫打卡／GPS API，可能新增資料。只用於隔離測試資料庫，不要公開連到正式後端，不要提交真實位置、帳密或 Token。詳見 [GPS 工具](gps-api-tester/README.md)。

<a id="states"></a>

## 10. 訂單與相關狀態

### 10.1 訂單

| 值                | 解讀                               |
| ----------------- | ---------------------------------- |
| `PENDING_CONFIRM` | 待確認，不能直接配送               |
| `CONFIRMED`       | 已確認，是否排車另看路線關聯       |
| `LOADED`          | 倉庫點交完成                       |
| `IN_DELIVERY`     | 配送中                             |
| `COMPLETED`       | 已完成，數量與時間仍須查交付紀錄   |
| `NO_SIGNATURE`    | 無人簽收                           |
| `FAILED`          | 配送／點交等失敗，查看異常及後續單 |
| `CANCELLED`       | 已取消                             |

```text
PENDING_CONFIRM → CONFIRMED → LOADED → IN_DELIVERY → COMPLETED
                      │                       └→ NO_SIGNATURE → 後續重送／異常
                      └→ 點交不符等 FAILED ─────→ 後續補送／異常
```

這是理解用簡圖，不代表可任意跳轉狀態。

- 排車後沒有另一個 `SCHEDULED` 訂單狀態，使用 `CONFIRMED` 配合 `route_id` 等欄位區分。
- 類型另有 `NORMAL`、`REPLENISHMENT`、`REDELIVERY`，不要與狀態混用。
- 後續單保留原單關聯，不應把原單改成正常交貨來隱藏問題。

### 10.2 其他類別

| 類別     | 值／意思                                         |
| -------- | ------------------------------------------------ |
| 路線     | `DRAFT` 草稿、`PUBLISHED` 已發布                 |
| 月班表   | 有自己的建立／發布流程，與配送路線不同           |
| 每日班別 | `UNASSIGNED`、`WORK`、`DAY_OFF`、`LEAVE`         |
| 出勤     | `WORKING`、`ON_BREAK`、`OVERTIME`、`CLOCKED_OUT` |
| 異常     | 另有案件狀態、處理說明及可能的後續訂單           |

異常包含無人簽收、短少、損壞、短少及損壞、司機回報、電話補登、點交不符與未結訂單相關識別。**案件結案、訂單完成、後續單交付不是同一件事。**

<a id="reports"></a>

## 11. 營運報表、歷史查詢與 Excel

### 11.1 營運報表

`/dispatch/reports` 可依年度、月度、週別與日別觀察：

- 打卡、準時上班、加班及缺卡。
- 實際出車／收車與可核對的里程。
- 訂單交付與完整交貨。
- 無人簽收、點交不符、未結訂單異常。
- 各倉配送與出貨點交結果。

圖表或指標可帶條件進歷史明細，不只是裝飾圖。

### 11.2 歷史查詢與匯出

`/dispatch/history` 提供日期區間及各資料來源的篩選。常見條件有倉庫、門市、司機、車輛／噸位、路線與異常狀態；**不同分頁不一定支援相同條件**。

分頁涵蓋營運總覽、訂單、路線里程油費、司機打卡、補送追蹤、配送結果、出貨點交、車輛、倉庫門市、門市表現、異常與欄位說明。

Excel 是依查詢資料整理的多工作表，不是整庫下載。部分工作表只在取得對應資料時出現。條件變更後先重新查詢、等待完成，再匯出，不要把舊預覽當成新結果。

### 11.3 指標限制

| 容易誤解                 | 正確解讀                                         |
| ------------------------ | ------------------------------------------------ |
| `—`                      | 缺資料、無有效分母或取得失敗，不能強當 0         |
| 完成＝準時足量           | 不成立，另看時間、數量及證據                     |
| 上班準時率＝配送準時率   | 不同指標                                         |
| 異常件次＝不重複訂單數   | 不一定，依案件及分類口徑                         |
| 跨倉百分比直接平均       | 應看分子／分母加權                               |
| 過去日期永遠不變         | 多數依查詢當下狀態重算，後續結案可能改變舊期數值 |
| 預估里程／油費＝實際成本 | 規劃、GPS、儀表及財務成本是不同來源              |
| 匯出有欄位＝都有證據     | 未知仍應保留未知，不補成成功                     |

主要日期規則使用 `Asia/Taipei`。人員目前歸屬與歷史出貨倉庫也不一定相同。細節見 [報表口徑](docs/operations-report-scope.md)，並與目前 Service 及畫面提示核對。

<a id="data"></a>

## 12. 資料庫升級、照片與備份

### 12.1 Flyway

- SQL 在 `backend/src/main/resources/db/migration/`。
- 命名如 `V1__baseline.sql`，中間兩個底線。
- 此分支目前有 V1～V12，未來以資料夾實際內容為準。
- 啟動時驗證已套用檔案，並執行尚未套用版本，歷史存在 `flyway_schema_history`。
- `ddl-auto=none`，新增 Entity 欄位不會自動完成正式改表。

| 版本     | 主要用途                         |
| -------- | -------------------------------- |
| V1       | 空白資料庫的基礎結構             |
| V2～V4   | 編組、預設司機與模型對齊         |
| V5       | 倉庫點交狀態與欄位               |
| V6～V8   | 請假、便條、分段里程與商品結構等 |
| V9       | 保養與行前檢查                   |
| V10～V11 | 舊資料商品／基礎欄位相容         |
| V12      | 報表點交證據欄位                 |

後續新增版本，不修改已在環境成功套用的舊 SQL 或手動改 checksum。

### 12.2 既有資料庫升級

**先備份，確認狀態，再升級。**

```sql
SELECT DATABASE();
SHOW TABLES LIKE 'flyway_schema_history';
```

確認 history 表存在後才查：

```sql
SELECT installed_rank, version, description, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

- 有完整 history：確認版本、分支與成功狀態，正常升級。
- 有結構沒 history：先比對是否符合 baseline，再由維護者決定 baseline 及版本。
- 失敗或 checksum 不符：先找原因，不要靠刪歷史、repair 或改舊 SQL 隱藏。
- `baseline-on-migrate=true` 不是所有舊資料庫的通用修復。
- `ApplyPreTripSchema.java` 等工具有特定歷史背景，不是新環境標準升級流程。
- 不要把陌生分支直接連到正式庫「測能不能啟動」；啟動可能改結構或回填資料。

### 12.3 資料位置

| 類型       | 主要位置                                                                 |
| ---------- | ------------------------------------------------------------------------ |
| 主檔       | `admin_users`、`warehouses`、`stores`、`drivers`、`vehicles`             |
| 配送       | `orders`、`order_items`、`routes`、`delivery_records`、`exception_cases` |
| 出勤／請假 | 月班表、`driver_shifts`、`attendance_records` 及請假相關表               |
| GPS／里程  | `gps_pings`、`mileage_logs`、`route_leg_mileages`                        |
| 車輛／檢查 | 保養規則與紀錄、`pre_trip_inspections`                                   |
| 照片       | 磁碟 `uploads/` 子目錄；資料庫通常只存檔名或路徑                         |

相對照片路徑取決於**工作目錄**。從根目錄與 `backend/` 啟動可能得到不同位置；部署請固定工作目錄或使用絕對儲存路徑。

行前照片由受控 API 驗證任務／司機權限。**目前大頭照與交貨照片的 GET 路徑在安全設定中可公開讀取**，不能宣稱所有照片都只限本人讀取；正式上線前須檢查個資、存取及保存需求。

### 12.4 自動背景工作

主要包含：

- 啟動時及每日 00:15 同步中油牌價，失敗保留可用舊資料。
- 每分鐘更新未結束出勤的工時狀態。
- 每 15 分鐘重試部分未完成結算的里程。
- 每日 02:30 清除過期 GPS，預設保存 5 年。

主要使用台北時區。報表查詢本身唯讀，不代表整台後端沒有背景寫入。

### 12.5 備份與停止

- SQL dump 與照片都要備份；只有資料庫無法還原遺失的照片。
- 備份放儲存庫外、限制權限，並在隔離環境驗證還原。
- Compose 的 `mysql-data`、`uploads` volume 保存資料；換映像不等於刪除 volume。
- `docker compose down` 通常保留 named volumes；**不要任意加 `-v`**，那會刪除資料。
- 不要清 schema、重建資料容器或刪上傳目錄，來解決還沒查明的登入／編譯錯誤。

<a id="api"></a>

## 13. API、授權與推播

### 13.1 主要入口

預設位址 `http://localhost:8080`。表中星號是範圍示意，不是原樣輸入的 API；完整方法、欄位與檢核請看 [Controller](backend/src/main/java/com/example/backend/controller/) 及 [DTO](backend/src/main/java/com/example/backend/dto/)。

| 入口                                                               | 用途                                                                                                            |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `GET /actuator/health`                                             | 不需登入的健康檢查                                                                                              |
| `POST /api/auth/admin/login`                                       | 主管登入，取得 ADMIN Token                                                                                      |
| `POST /api/auth/driver/login`                                      | 司機登入，取得 DRIVER Token                                                                                     |
| `GET /api/auth/me`                                                 | 還原目前登入者                                                                                                  |
| `/api/admin-users`                                                 | 主管建立、個人資料及密碼操作                                                                                    |
| `/api/warehouses`、`/api/stores`                                   | 倉庫、門市管理                                                                                                  |
| `/api/drivers`、`/api/vehicles`                                    | 司機、車輛管理                                                                                                  |
| `/api/orders`                                                      | 訂單建立、查詢、審核等                                                                                          |
| `/api/driver-schedules`                                            | 月班表、班次與發布                                                                                              |
| `/api/dispatch/board`、`/api/dispatch/days`                        | 配送看板與日期摘要                                                                                              |
| `/api/dispatch/optimize`、`/api/dispatch/optimize/slots`           | 自動排車／編組排車                                                                                              |
| `/api/dispatch/reassign`                                           | 手動改派                                                                                                        |
| `/api/dispatch/publish`、`/api/dispatch/withdraw`                  | 發布／撤回                                                                                                      |
| `/api/dispatch/store-sequence`、`/api/dispatch/templates`          | 順序建議、編組模板                                                                                              |
| `/api/dispatch/routes/{routeId}/metrics`                           | 路線距離、估算與保養預覽                                                                                        |
| `/api/fleet`、`/api/vehicle-maintenance`                           | 車隊、保養與退役                                                                                                |
| `/api/exceptions`                                                  | 異常案件                                                                                                        |
| `/api/leave-requests`、`/api/emergency-leave-requests`             | 主管請假審核、當日臨請                                                                                          |
| `/api/reports/*`                                                   | 主管報表：summary、attendance、routes、drivers、vehicles、warehouses、stores、exceptions、performance、outcomes |
| `/api/fuel-prices`、`/api/geocode`                                 | 油價、地址查詢                                                                                                  |
| `/api/admin-sticky-notes`                                          | 主管便條                                                                                                        |
| `/api/driver/profile`、`/api/driver/attendance/*`                  | 司機資料與打卡                                                                                                  |
| `/api/driver/tasks*`                                               | 本人今日、指定日期與未來任務                                                                                    |
| `/api/driver/loading`、`/api/driver/arrive`、`/api/driver/deliver` | 點交、抵達、交付                                                                                                |
| `/api/driver/no-signature`、`/api/driver/exception`                | 無人簽收與通報                                                                                                  |
| `/api/driver/pre-trip`                                             | 行前檢查與受控照片                                                                                              |
| `/api/driver/gps`、`/api/driver/mileage/*`                         | 定位、出車與收車                                                                                                |
| `/api/driver/leave-requests*`、`/api/driver/messages*`             | 司機請假、訊息                                                                                                  |
| `POST /api/route`                                                  | 道路路線查詢                                                                                                    |

目前依賴未提供可直接使用的 Swagger UI，不要假設 `/swagger-ui` 就是完整契約。歷史 [API 文件](docs/api-contract.md) 可作背景，但不是取代 Controller／DTO 的自動產生規格。

### 13.2 JWT 與錯誤

除明確公開的入口，請求需帶：

```http
Authorization: Bearer <自己的有效 Token>
Content-Type: application/json
```

- 密碼用 BCrypt 比對，不是解密取回原密碼。
- JWT 使用 HS256、issuer `logistics-dispatch`，有使用者 ID、角色及有效期。
- 兩前端目前各自把 Token 存入 localStorage；登出清除本機狀態。
- 主管、司機的 storage key 不同，Token 也不能互換。
- 正式環境使用 HTTPS，不把憑證放到公開 URL、截圖或 log。

| HTTP 狀態     | 常見原因                                       |
| ------------- | ---------------------------------------------- |
| 400           | 輸入／業務檢核失敗；目前帳密錯誤通常也走此回應 |
| 401           | 缺少、無效或到期的 Token                       |
| 403           | 角色無權限，或 CORS 來源被拒，需分開判斷       |
| 404           | 路徑、檔案或資源不存在，依入口處理             |
| 413／上傳錯誤 | Nginx、單檔或整次請求大小限制                  |
| 503           | 已明確處理的原生排車引擎載入失敗               |
| 500           | 未處理的後端錯誤，查看伺服器 log               |

一般業務錯誤常為 `{"success":false,"message":"原因"}`，但 Security 等入口不保證同一種 JSON 格式。

### 13.3 WebSocket／STOMP

握手入口 `/api/ws`。握手允許連線不等於能任意訂閱資料；CONNECT 仍須有效 JWT，訂閱會核對角色，私人訊息使用個人佇列。

Nginx 必須轉送 Upgrade／Connection。普通 HTTP API 成功，不代表聊天室、看板或請假推播也正常。

<a id="verification"></a>

## 14. 建置、測試與驗收

### 14.1 標準建置

以下每組指令都要在**對應目錄**執行，不是在同一目錄貼完整段落。

後端，Windows：

```powershell
cd backend
./gradlew.bat classes
./gradlew.bat bootJar
```

macOS／Linux 改用 `./gradlew`。`classes` 編譯主要程式、`bootJar` 包裝可執行 jar，這兩個任務不等於完整 `test`；`build` 通常包含測試。

主管端，從根目錄：

```powershell
cd frontend
npm ci --ignore-scripts
npm run build
```

司機端，從根目錄：

```powershell
cd frontend-driver
npm ci --ignore-scripts
npm run build
```

| 元件   | 產物                                                 |
| ------ | ---------------------------------------------------- |
| 後端   | `backend/build/libs/backend-0.0.1-SNAPSHOT.jar`      |
| 主管端 | `frontend/dist/logistics-dispatch-frontend/browser/` |
| 司機端 | `frontend-driver/dist/frontend-driver/browser/`      |

jar 名稱隨版本而變，以 `build/libs` 實際檔案為準。從 `backend/` 執行：

```powershell
java -jar build/libs/backend-0.0.1-SNAPSHOT.jar
```

Angular 產物須由正確的 HTTP 伺服器提供 SPA 路由及 API 代理，不能直接雙擊 HTML 當成完整網站。

### 14.2 前端單元測試

兩個前端**各自**執行：

```powershell
npm test -- --watch=false
```

目前使用 Angular 測試 builder、Vitest、jsdom。單元測試不是手機定位、真實瀏覽器或完整後端資料流的替代。

### 14.3 後端測試必須隔離

部分是 mock 單元測試，部分會啟動 Spring、連 MySQL、建結構及寫測試紀錄，也有測試需要 OSRM／原生 OR-Tools。

**不要讓完整測試使用正式或正在工作的 `3party_ver`。** 先另外建立例如 `3party_ver_test`，並使用只授權此 schema 的測試帳號。

新開 PowerShell，從根目錄：

```powershell
cd backend
$testDbCredential = Get-Credential -Message "輸入只可存取測試資料庫的 MySQL 帳密"
$env:DB_URL = "jdbc:mysql://127.0.0.1:3306/3party_ver_test?serverTimezone=Asia/Taipei"
$env:SPRING_DATASOURCE_URL = $env:DB_URL
$env:DB_USER = $testDbCredential.UserName
$env:DB_PASSWORD = $testDbCredential.GetNetworkCredential().Password
$env:APP_JWT_SECRET = node -e "console.log(require('node:crypto').randomBytes(48).toString('base64'))"
$env:SHOW_SQL = "false"
./gradlew.bat test --no-daemon
```

先核對帳號沒有正式 schema 權限。若另外設定 `SPRING_FLYWAY_URL` 等獨立 Flyway 連線，也必須指向測試庫，不能只改 datasource。測完關閉這個終端機，避免誤用其環境變數。

只執行報表相關測試：

```powershell
./gradlew.bat test --tests "*Report*Test" --no-daemon
```

仍可能包含整合測試，不表示可省略測試資料庫。

報告位於 `backend/build/reports/tests/test/index.html`，XML 在 `backend/build/test-results/test/`。失敗先查原始原因，不要刪測試或改成永遠通過。

`scripts/verify-*.cjs`、`SeedOperationReportDemo.java` 等可能寫資料、需要額外環境，**不是標準啟動指令**。先讀原始碼，在受控環境由維護者決定是否使用，不夾帶測試資料進正式資料庫或 Git。

### 14.4 分層驗收

| 層級 | 要驗證                                 | 不代表             |
| ---- | -------------------------------------- | ------------------ |
| 編譯 | Java classes、兩前端 production build  | 已登入或跑通配送   |
| 啟動 | DB、migration、health UP               | OSRM／原生排車正常 |
| 登入 | 有效帳號與權限、主檔讀取               | 任務條件已齊全     |
| 排車 | 道路、引擎、人車、容量、班表與維護條件 | 已發布             |
| 司機 | 打卡到收車的完整連續流程               | 所有異常情境已涵蓋 |
| 報表 | 明細、彙總、篩選、Excel 可核對         | 歷史快照／財務結算 |

至少實際確認：

- [ ] MySQL 主機、埠、schema 正確，沒有誤連另一環境。
- [ ] 後端啟動與 migration 成功。
- [ ] 主管、司機分別登入。
- [ ] 主檔、班表、已確認訂單與已發布路線齊全。
- [ ] 行前檢查、點交、出車、抵達、交付、收車及下班連續完成。
- [ ] 有效 GPS、倉庫範圍、照片與即時通知正常。
- [ ] 異常與後續單未遺失／重複。
- [ ] 報表與 Excel 能逐筆核對，不將缺值冒充 0。
- [ ] 部署後重新整理內頁、照片、HTTPS、PWA 及 WebSocket 正常。

<a id="deployment"></a>

## 15. 正式部署與 CI/CD

### 15.1 與本機開發的差別

新手建議先走「本機後端＋兩個 Angular 開發伺服器＋Docker OSRM」。

`deploy/docker-compose.yml` 不是無設定的一鍵啟動：含網域、TLS 憑證與映像來源。**沒有憑證而直接開整套 web 可能失敗，不代表後端有 bug。**

- 預設 Compose 會合併 `docker-compose.override.yml`，加入本機建置。
- 明確指定 `-f docker-compose.yml` 則只用該基礎檔，適用拉取已建映像的流程。
- 容器互連用 `mysql`、`osrm`、`backend` 名稱，不用容器自己的 `127.0.0.1`。
- Compose schema 為 `logistics`，不會自動使用本機 `3party_ver`。
- `mysql-data` 與 `uploads` 保存資料。
- `deploy/.env` 與 `backend/.env` 是不同檔案、用途，不自動同步。

依 Compose 實際變數建立自己未提交的 `deploy/.env`，例如：

```dotenv
DB_PASSWORD=<部署資料庫應用帳號密碼>
MYSQL_ROOT_PASSWORD=<部署 MySQL 管理密碼>
APP_JWT_SECRET=<部署專用隨機金鑰>
MYSQL_PORT=3307
OSRM_DIR=../osrm
OSRM_DATA=taiwan-latest
IMAGE_TAG=latest
```

正式維運應記錄已核准的映像版本／commit，不把 `latest` 當成唯一可追蹤版本。

### 15.2 這個 fork 部署前要改什麼

範本仍有原部署設定：

- 網域 `dispatch.xinchafujin.com`、`driver.xinchafujin.com`、`xinchafujin.com`。
- Compose image 指向 `ghcr.io/xinchafu-jin/logistics-backend` 與 `logistics-web`。
- Actions 的映像 owner 卻使用 `github.repository_owner`，此 fork 不一定與上述 owner 相同。
- 遠端 VM 的帳號、路徑也有預設值。

所以，直接 push `main` **不等於已具備可用部署環境**。部署負責人須同步確認：

1. GHCR owner、映像名稱、tag 與拉取權限。
2. VM 帳號／路徑與 GitHub Secrets。
3. 自己的 DNS、憑證與 Nginx server_name。
4. 真正前端來源與 CORS。
5. 資料庫帳密、schema、備份與 volume。
6. OSRM 路網路徑與處理版本。
7. `/api`、`/api/ws`、`/uploads`、`/actuator/health` 代理。

這些網域只是現有設定值，不保證網站目前可用或本分支已上線。[部署文件](docs/deployment.md) 包含歷史方案，執行前仍核對目前 Compose／workflow。

### 15.3 CI 實際做什麼

[ci.yml](.github/workflows/ci.yml) 在非 `main` 分支 push、被 workflow 呼叫或手動執行時：

1. 建立空白 MySQL 8.4。
2. 用 Flyway 11.14.1 驗證 migration。
3. 執行 `./gradlew classes --no-daemon`。
4. 兩個 Angular 各執行 `npm ci --ignore-scripts`、`npx ng build`。

**目前 CI 沒有跑完整後端 `test` 或兩前端的單元測試。** 綠燈只代表上述實際工作成功。

[build-images.yml](.github/workflows/build-images.yml)：

1. `main` 符合 paths 的 push，或手動觸發。
2. 先呼叫 CI。
3. 建置 `linux/amd64` backend／web 映像並推 GHCR。
4. 用 `VM_SSH_KEY`、`VM_HOST` 等 secrets 連 VM 拉取並重啟。
5. 重試健康檢查。

只改 README 不在目前主分支映像建置的 paths 清單。記憶體小的 VM 應拉取 CI 建好的映像，不要假設它能完成兩個 Angular 的大型編譯。

### 15.4 HTTPS、PWA 與檔案

- 司機端目前在 production 啟用 Service Worker，`npm start` 不等於正式 PWA 驗證。
- 快取以靜態資源為主，不是可離線完成全部配送並自動同步 API。
- 手機正式使用提供 HTTPS，不關閉瀏覽器安全檢查來解定位。
- 單檔上限 5 MB，後端整個 multipart 請求及 Nginx 請求上限 6 MB。
- 行前檢查一次多張照片，**每張都低於 5 MB，合計仍可能超過 6 MB**，需依畫面壓縮。
- SPA fallback、快取更新、照片保存及 WebSocket Upgrade 都要驗收。

### 15.5 上線前安全檢查

- 不直接用 MySQL root／共用開發密碼公開部署。
- 不公開 GPS 工具、SQL dump、照片與真實軌跡。
- 只開必要服務與來源，不任意公開 DB／OSRM。
- 確認大頭照／交貨照片目前的公開讀取規則。
- 現有忘記密碼以帳號、手機資料核對，**不等於簡訊 OTP／Email 驗證**；公開環境須評估驗證強度、限流與風險。
- 檢查 HTTPS、瀏覽器 Token 保存、過期與登出。
- 分別保護雜湊、金鑰、備份，不能因用了 BCrypt 就推定整體安全已完成。

<a id="troubleshooting"></a>

## 16. 常見問題

先依層次排查：`軟體／JDK → MySQL → migration → 後端 → 登入 → 前端代理 → 道路／排車 → 手機與業務條件`。不要先刪資料或重裝全部。

### 16.1 找不到 build.gradle／指令

後端在 `backend/`；PowerShell 用 `./gradlew.bat`。npm 指令在各前端自己的目錄執行，不能全部在根目錄跑。

### 16.2 Unable to start the daemon process

這是外層提示，看最內層原因：

- 明確無效的 JVM option 才去查 `org.gradle.jvmargs`、IDE VM options 等。
- `management.dll`／`extnet.dll` 加上「應用程式控制原則已封鎖」是 JDK 原生檔被 Windows 擋住，改 `-Xmx` 不能解決。
- 使用來源、完整性、簽章經核對且能通過本機政策的 JDK 21，或由管理員核准。
- 同時查 Project SDK、Gradle JVM、Run Configuration、`JAVA_HOME`。
- 不關閉防護、亂加排除、搬動／改名 DLL 來繞過政策。
- `--no-daemon` 仍可能產生一次性 JVM，不代表不再需要原生功能。

### 16.3 OR-Tools：abseil_dll.dll

`ortools-java.../abseil_dll.dll` 是排車引擎，不是 MySQL 或 OSRM 容器。

目前已延後載入；失敗時自動排車／門市最佳化回 503，其他功能不一起停機。這只是故障隔離，**不代表引擎恢復**，不會偷偷換演算法。

須由管理員按政策核准合法程式庫，或使用受支援的 Linux 後端容器。處理後重啟後端再測；同一程序會記住載入失敗，避免每次反覆解壓。

### 16.4 MySQL 連線

| 現象                                 | 先查                                           |
| ------------------------------------ | ---------------------------------------------- |
| Connection refused                   | 服務、主機、埠                                 |
| Access denied                        | 帳密、帳號 host／權限                          |
| Unknown database                     | schema 是否存在、是否接錯埠                    |
| 連上但沒資料                         | `3party_ver`／`logistics`、3306／3307 是否混用 |
| Public Key Retrieval／RSA public key | 驗證方式、驅動、TLS、URL 參數                  |

部署範本保留可協商 TLS 的方式。只有受控本機／隔離 CI 確需非 TLS 時，由維護者評估 `allowPublicKeyRetrieval=true`、`useSSL=false`，不要一律貼到正式 URL。

### 16.5 Flyway

- `Found non-empty schema ... but no schema history table`：先備份比對，再決定 baseline，不能直接清庫。
- checksum mismatch：先找哪份舊 migration 被改。
- 缺欄位／enum：先核對分支與版本，不用 `ddl-auto=update` 讓 Hibernate 任意修表。
- 歷史文件提到 V15／V18 等，不代表本分支一定有該檔案。

### 16.6 前端開得起來但登入失敗

依序查後端 health、Network 請求位置、網站帳號、Token、角色／CORS，再查 proxy／埠。改 JWT 金鑰或 Token 過期時登出重登。不能只看「畫面有出來」。

### 16.7 CI 找不到 class／module／SCSS

- 先看執行紀錄的 **branch 與 commit SHA**。
- `git status --short` 的 `??` 是未追蹤，CI 收不到。
- 新增 Service、DTO、TS helper、SCSS 要一併提交，不是只送修改過的舊檔。
- Linux 檔名大小寫須與 import 一致。
- 舊紀錄按 **Re-run 仍跑原 commit**，不會自動用最新修正。

### 16.8 OSRM 斷線／沒有路線

查容器執行狀態、log、5001:5000、掛載、完整路網、MLD 前處理與版本。本機後端用 5001，Compose 用 `osrm:5000`。

無路線也可能是座標順序錯（道路 API 通常是**經度,緯度**）、超出路網或道路不可達。底圖正常不能證明 OSRM 正常。

### 16.9 不能打卡、看任務、點交或下班

查：啟用的本人帳號、台北日期、已發布 WORK 班表、已發布本人路線、目前版本行前檢查、訂單狀態、里程、照片及倉庫定位範圍。不要直接改資料庫跳過規則。

### 16.10 手機、照片、PWA、報表

- 定位：HTTPS／安全來源、授權、裝置定位及出勤狀態。
- 照片：單檔 5 MB／總請求 6 MB、磁碟目錄、權限、代理及 volume。
- 照片 404：DB 有路徑不代表檔案存在，工作目錄改變也會找不到。
- PWA 舊版：核對 production 產物與 Service Worker 快取，不是只重開開發伺服器。
- 推播：查 `/api/ws` Upgrade、Token、角色及重連。
- 報表空白：分清無資料、無有效分母及 API 失敗，不能一律補 0。
- 測試出現 Mockito／Byte Buddy attach 錯誤：先查受信任 JDK，再依 Mockito 的 Java 21 instrumentation 設定測試 JVM；不要把它誤判為業務斷言失敗。

<a id="development"></a>

## 17. 開發與 Git 提交

### 17.1 如何追一個功能

```text
Angular 頁面／服務
  → Controller：URL、參數與角色
  → DTO：資料格式
  → Service：業務規則與交易
  → DAO／Entity：查詢及表模型
  → migration：結構如何建立與升級
```

修改時核對這整條關聯，不是只改畫面就等於後端規則已變。

### 17.2 提交前

```powershell
git status --short
git diff
git diff --cached
```

- 指定檔案提交，例如 `git add README.md`，避免習慣全部加入。
- import 新檔不會讓它自動進 Git。
- 不推實際 `.env`、帳密、Token、SQL dump、照片、GPS、`uploads`、大型路網、建置產物與本機 SDK／IDE 設定。
- 測試程式不等於測試資料；提交範圍依當次工作決定，不夾帶資料庫內容。
- 更新前保留未提交工作，不強制覆蓋其他人的修改。
- 分支命名依維護者規則，例如 `codex/update-readme`；本指南不宣稱 GitHub 已設任何 branch protection。
- `main` 可能觸發部署，未核對 CI、映像、secrets、環境前不要直接推正式分支。

### 17.3 文件與授權

環境、功能、migration、埠或部署方式改動時一起更新文件，不把「未來想做」寫成已實作。

若儲存庫未提供明確 LICENSE，不可因使用開源套件就推定整個專案是 MIT 或可任意散布；請確認專案與依賴授權。

<a id="references"></a>

## 18. 文件與程式入口

### 18.1 延伸文件

| 文件                                          | 用途／注意                                     |
| --------------------------------------------- | ---------------------------------------------- |
| [部署說明](docs/deployment.md)                | 原部署背景與經驗，部分歷史方案需與現行檔案核對 |
| [API 契約](docs/api-contract.md)              | 設計背景，完整現況以 Controller／DTO 為準      |
| [資料模型](docs/data-model.md)                | 關係背景，表結構以本分支 migration 為準        |
| [報表口徑](docs/operations-report-scope.md)   | 指標、資料缺口、比較與查詢限制                 |
| [行前安全檢查](docs/pre-trip-safety.md)       | 操作與權限，歷史手動升級不是新環境步驟         |
| [車輛保養與退役](docs/vehicle-maintenance.md) | 里程及維護公式，注意跨版本 SQL 名稱            |
| [司機所屬倉庫](docs/driver-warehouse.md)      | 人車歸屬及編組背景                             |
| [司機請假](docs/driver-leave-calendar.md)     | 排假、臨請、補請                               |
| [OSRM](osrm/README.md)                        | 道路處理及端點，本 README 另有 PowerShell 版本 |
| [GPS 工具](gps-api-tester/README.md)          | 受控開發環境測試                               |
| [專題規劃](docs/roadmap.md)                   | 歷史規劃，不是目前時程承諾                     |
| [技術稽核紀錄](TECHNICAL_AUDIT_REPORT.md)     | 歷史檢查，不等同即時驗收結果                   |

### 18.2 常用程式入口

- 版本：[後端建置](backend/build.gradle)、[主管 package](frontend/package.json)、[司機 package](frontend-driver/package.json)。
- 埠／前端：[主管 Angular 設定](frontend/angular.json)、[司機 Angular 設定](frontend-driver/angular.json)。
- 設定：[application.properties](backend/src/main/resources/application.properties)、[.env.example](backend/.env.example)。
- 授權：[SecurityConfig](backend/src/main/java/com/example/backend/config/SecurityConfig.java)、[AuthService](backend/src/main/java/com/example/backend/service/AuthService.java)。
- 道路／排車：[RouteOptimizer](backend/src/main/java/com/example/backend/dispatch/RouteOptimizer.java)、[OsrmClient](backend/src/main/java/com/example/backend/dispatch/OsrmClient.java)。
- 資料：[migration](backend/src/main/resources/db/migration/)。
- 部署：[CI](.github/workflows/ci.yml)、[映像流程](.github/workflows/build-images.yml)、[Compose](deploy/docker-compose.yml)、[本機覆寫](deploy/docker-compose.override.yml)、[Nginx](deploy/web/default.conf)。

**上手完成不只是畫面能開，而是知道元件做什麼、資料存哪裡，並能在隔離環境完成一筆可核對的配送流程。**
