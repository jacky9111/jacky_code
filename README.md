# EABR — EPFD-Aware Beam Reassociation for Service Recovery

多波束 LEO 衛星系統在 NGSO–GSO 共存情境下的服務救援框架，論文模擬程式碼。

> **論文**：*EPFD-Aware Beam Reassociation for Service Recovery in Multi-Beam LEO Satellite Systems*

---

## 目錄

1. [這是什麼](#這是什麼)
2. [環境需求](#環境需求)
3. [專案結構](#專案結構)
4. [快速開始](#快速開始)
5. [Evaluation 各圖表 → 對應程式](#evaluation-各圖表--對應程式)
6. [換場景要改哪些關鍵參數](#換場景要改哪些關鍵參數)
7. [輸出檔案命名規則](#輸出檔案命名規則)
8. [常見問題與已知限制](#常見問題與已知限制)

---

## 這是什麼

當 LEO 衛星飛過 GSO 地面站（GS）附近時，會對 GSO 系統造成嚴重干擾。為了滿足
**EPFD（equivalent power flux-density）** 限制，必須關閉高干擾的 beam ——
但這會中斷該 beam 底下使用者的服務。

**EABR** 的作法是：在關束的同時，用鄰近衛星的 beam 把受影響的使用者接手過來，
且全程維持 EPFD 合規。它由三個步驟組成：

| 步驟 | 全名 | 做什麼 |
|------|------|--------|
| **SBR** | Safe-Beam Reassociation | 把 helper 衛星自家的使用者換到「安全束」，騰出功率 |
| — | EPFD-constrained power allocation | 把騰出的功率配給 helper recovery beam，且不得讓 EPFD 超標 |
| **HBR** | Helper-Beam Reassociation | 把關閉束底下的使用者接到 helper recovery beam |

論文比較四個方法：

| 方法 | 說明 | 程式中的開關 |
|------|------|-------------|
| Beam shutdown only | 只關束，不做救援 | `enableRelay = false` |
| PC + Tilt | Jalali et al. 的功率控制 + 衛星傾斜 | 走 `RunKu16BeamBaselineObservationLogExcel` |
| Only HBR | 只做 HBR，helper 用預設功率 | `enableRelay=true, enableMiddleHelperSwap=false` |
| **EABR**（本論文） | SBR + 功率配置 + HBR | `enableRelay=true, enableMiddleHelperSwap=true` |

> **命名對照**：程式裡的舊名 `SAPR-R` / `RelayWithMiddleSwap` = 論文的 **EABR**；
> `RelayOnly` / `Only BPLR` = 論文的 **Only HBR**；`BackoffOnly` = **Beam shutdown only**。
> 檔名與變數名仍沿用舊稱，看程式時請自行對照。

---

## 環境需求

| 項目 | 版本／說明 |
|------|-----------|
| **MATLAB** | R2019b 以上（需 `string`、`readtable('Sheet',...)`、`writetable`） |
| **STK** | **STK 12**，且需有 **Integration / COM** 授權 |
| MATLAB Toolbox | Statistics and Machine Learning Toolbox（`prctile`，overhead 模組用） |
| 作業系統 | Windows（`actxGetRunningServer` 為 Windows COM 專屬） |

**只有主模擬需要 STK。** 以下三個模組是純 MATLAB，沒裝 STK 也能跑：

- `Matlab/helper_availability/` — 不同星座密度的 helper 可用性
- `Matlab/overhead_evaluation/` — 線上計算負擔量測
- Evaluation 的畫圖區段（純讀 Excel）

---

## 專案結構

```
jacky_code/                      ← 專案根目錄（下方 file_path 指向這裡）
├── Matlab/                      ← 所有程式碼
│   ├── jacky.m                  ★ 主流程驅動腳本（分 cell 逐段執行）
│   ├── jacky/                   ← 評估主線：模擬引擎 + 畫圖 + STK 建場（65 檔）
│   ├── helper_availability/     ← 不同密度的 helper 可用性（純 MATLAB，18 檔）
│   ├── overhead_evaluation/     ← 線上執行時間量測（純 MATLAB，11 檔）
│   ├── powertilt/               ← PC + Tilt 相關模型與復現驗證（29 檔）
│   ├── Method/                  ← 早期 STK 工具與 progressive pitch 相關（25 檔）
│   ├── pitch1.m / powertilt.m   ← 舊的 TLE-based STK 驅動腳本（與論文評估無關）
│   └── Satellite_Name.m / 畫圖.m
├── Matlab_data/                 ← 所有模擬輸出：Excel / PNG / FIG / MAT
├── STK/ STK1/ STK2/ jacky_STK/  ← STK 場景檔（Scenario.sc 等）
├── oneweb_tle/ geo_tle/         ← TLE 快照（舊腳本使用）
├── 論文/                        ← 論文 LaTeX 原始碼與圖檔（main.tex、figures/）
├── 論文文獻/                     ← 參考文獻 PDF
└── Paper_Single/                ← 單篇論文版本的建置腳本
```

**唯一的路徑設定**在 [jacky.m](jacky_code/Matlab/jacky.m) 裡：

```matlab
file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
```

換電腦或搬資料夾時，**只需要改這一行**（`jacky.m` 內共出現 4 次，都是同一個值的預設補齊）。

---

## 快速開始

### 前置：啟動 STK

1. 開啟 **STK 12**
2. 新建場景，或載入既有場景 `jacky_code/jacky_STK/Scenario.sc`
3. 保持 STK 開著（MATLAB 是用 `actxGetRunningServer` 連上「已在執行」的 STK）

### 執行 jacky.m

在 MATLAB 開啟 [jacky_code/Matlab/jacky.m](jacky_code/Matlab/jacky.m)，
**用 Ctrl+Enter 逐個 cell（`%%`）執行，不要整支按 F5** ——
前半段需要 STK、後半段是純 MATLAB，混在一起跑會出錯。

各 cell 的順序與用途：

| # | Cell 標題 | 需要 STK | 做什麼 |
|---|-----------|:--------:|--------|
| 1 | 重置 / 與 STK 連線 / 初始化 | ✅ | 連上 STK COM、設定 `file_path` |
| 2 | 建立衛星 | ✅ | 建 Walker star 星座（1200 km / 87.9°） |
| 3 | 建立 beam | ✅ | 建 RectBeam sensor（僅視覺化） |
| 4 | 建立地面站 / user | ✅ | 建 GS_01 與 User_* facility（僅視覺化） |
| 5 | **四方法模擬 → Excel** | ✅ | 產生圖一～圖六所需的所有 Excel（**最耗時**） |
| 6 | **Evaluation（讀 Excel 畫圖）** | ❌ | 畫圖一～圖六 |
| 7 | Helper availability | ❌ | 產生密度比較表格 |
| 8 | Worst-EPFD scene | ❌ | 產生密度比較示意圖 |
| 9 | Computational overhead | ❌ | 量測 Only HBR / PC+Tilt / EABR 執行時間（產生 2 張圖） |
| 10 | 場景儲存 | ✅ | `root.Save` / `SaveAs` |

### 只想重畫圖，不重跑模擬

Excel 已經在 `Matlab_data/` 裡的話，**跳過 cell 5，直接跑 cell 6**。
畫圖區段有自動補齊預設值的邏輯（`file_path`、`evalCriticalSat`、EPFD 門檻等），
所以就算 workspace 是空的也能單獨執行。

**記得先設定要畫哪個 user 負載：**

```matlab
numUsersPerSatPlot = 70;   % 30 / 50 / 70，決定讀哪一組 U 標籤的 Excel
```

### 只跑純 MATLAB 模組

```matlab
cd('C:\Users\jacky\Desktop\jacky_code\jacky_code');
addpath(genpath(fullfile(pwd, 'Matlab')));

% 不同星座密度的 helper 可用性 → 論文 Table
[summaryTable, caseResults] = main_helper_availability();

% 最壞 EPFD 時刻的覆蓋示意圖
worstSlotSchematic = main_worst_slot_schematic();

% 線上執行時間量測（同時產生 PC+Tilt vs EABR 與 Only HBR vs EABR 兩張圖）
overheadResults = main_overhead_evaluation();
disp(overheadResults.summaryTable);
```

---

## Evaluation 各圖表 → 對應程式

論文 Evaluation（`論文/chapter6_content.tex`）共六個結果小節。下表把每張圖
對應到「產生資料的程式」與「畫圖的程式」。

### ① EPFD Compliance and Beam Shutdown

| 論文圖 | 內容 | 資料來源 | 畫圖程式 | jacky.m 位置 |
|--------|------|---------|---------|-------------|
| `ch5_epfd_constraint` | Aggregate EPFD 隨時間變化 vs 門檻線 | `*_U{U}_RelayWithMiddleSwap.xlsx` 的 `Slot_EPFD` 分頁 | [PlotFullPowerSweepEpfdVsRelativeTime.m](jacky_code/Matlab/jacky/PlotFullPowerSweepEpfdVsRelativeTime.m) | `optsFig1` |
| `ch5_FullPower_BeamShutdown` | critical 衛星關閉的 beam 數 | 同上 | [PlotFullPowerSweepClosedCriticalBeamsVsTime.m](jacky_code/Matlab/jacky/PlotFullPowerSweepClosedCriticalBeamsVsTime.m) | `optsFig2` |

**資料產生**：[RunFullPowerAggregateShutdownSweepExcel.m](jacky_code/Matlab/jacky/RunFullPowerAggregateShutdownSweepExcel.m)（需 STK）

**橫軸 t=0 的定義**：全部 beam 開啟、尚未 backoff 前 **EPFD 最高的那個 slot**（worst EPFD slot），
由 `FullPowerSweepSlotTimeOffsetLocal.m` 計算。圖一～圖六共用同一個 t=0。

### ② Helper Satellite Availability under Different Constellation Densities

| 論文圖表 | 內容 | 程式 |
|---------|------|------|
| Table「Helper Availability…」 | 四個指標 × 三種密度 | [main_helper_availability.m](jacky_code/Matlab/helper_availability/main_helper_availability.m) |
| `ch6_density_worst_epfd_coverage` | 最壞 EPFD 時刻的 critical/helper 覆蓋圖（三個子圖） | [main_worst_slot_schematic.m](jacky_code/Matlab/helper_availability/main_worst_slot_schematic.m) |

**純 MATLAB，不需要 STK。** 參數集中在
[config_helper_availability.m](jacky_code/Matlab/helper_availability/config_helper_availability.m)。

圖的三個子圖分別由三次執行產生，輸出到 `Matlab_data/`：

```
Low_density_worst_epfd_ssp_16beams.png              ← (a) 低密度
OneWeb_like_reference_worst_epfd_ssp_16beams.png    ← (b) OneWeb-like 參考
High_density_worst_epfd_ssp_16beams.png             ← (c) 高密度
```

Table 的四個欄位由 [compute_helper_availability_metrics.m](jacky_code/Matlab/helper_availability/compute_helper_availability_metrics.m) 計算，
helper 判定準則在 [identify_recovery_helpers.m](jacky_code/Matlab/helper_availability/identify_recovery_helpers.m)。

### ③ User Satisfaction under Different User Loads

| 論文圖 | 內容 | 畫圖程式 | jacky.m 位置 |
|--------|------|---------|-------------|
| `ch5_U{30,50,70}_AvgUserSatisfaction_4MethodCompare` | 四方法平均滿意度 vs 時間 | [PlotFullPowerSweepSatisfactionVsTimeCompare.m](jacky_code/Matlab/jacky/PlotFullPowerSweepSatisfactionVsTimeCompare.m) | `optsFig3` |

一張圖需要**四份 Excel**（四個方法各一份），由
[RunEvalFourMethodSweepsLocal.m](jacky_code/Matlab/jacky/RunEvalFourMethodSweepsLocal.m) 一次產生。
三種負載就是把 `numUsersPerSatPlot` 依序設成 30 / 50 / 70 各畫一次。

### ④ Service Recovery Capability and Satisfaction Distribution

| 論文圖 | 內容 | 畫圖程式 | jacky.m 位置 |
|--------|------|---------|-------------|
| `ch5_U{50,70}_RecoveredUserCount` | Only HBR vs EABR 救回的 user 數 | [PlotFullPowerSweepRelayUserCountCompare.m](jacky_code/Matlab/jacky/PlotFullPowerSweepRelayUserCountCompare.m) | `optsFig4` |
| `ch5_U{50,70}_UserSatisfaction_CDF_3MethodCompare` | 三方法滿意度 CDF | [PlotFullPowerSweepUserSatisfactionCdfCompare.m](jacky_code/Matlab/jacky/PlotFullPowerSweepUserSatisfactionCdfCompare.m) | `optsFig5` |

> **CDF 圖需要 `PerUser` 分頁。** 舊版 sweep 產生的 xlsx 沒有這個分頁，
> 會跳出 `MissingPerUserSheet` 警告並跳過此圖 —— 需重跑 RelayOnly 與 EABR 的 sweep。

論文只畫 U50 / U70，因為 U30 是低負載、helper 預設功率就夠用，兩法差異不明顯。

### ⑤ On-Orbit Computational Overhead

| 論文圖 | 內容 | 畫圖程式 |
|--------|------|---------|
| `runtime_overhead_pc_tilt_vs_eabr` | PC+Tilt vs EABR 每 slot 執行時間 | [plot_overhead_result.m](jacky_code/Matlab/overhead_evaluation/plot_overhead_result.m) |
| `ch5_overhead_only_hbr_vs_eabr` | Only HBR vs EABR 每 slot 執行時間 | [plot_overhead_only_hbr_result.m](jacky_code/Matlab/overhead_evaluation/plot_overhead_only_hbr_result.m) |

**入口**：[main_overhead_evaluation.m](jacky_code/Matlab/overhead_evaluation/main_overhead_evaluation.m)，
**一次執行同時產生上面兩張圖**（jacky.m 的 cell 9）。

**純 MATLAB，不需要 STK。** 量測方法：先在 ±120 s 內找出最壞 EPFD 時刻 `t_worst`，
再在 `[t_worst-30, t_worst+30)` 這 60 個 1 秒 slot 各量一次執行時間；
長條 = 平均，黑色 I 形線 = p10–p90 範圍。

三個方法**跑在同一組場景上**（同幾何、同 user 分佈、同關閉束），
每個負載只呼叫一次 [prepare_overhead_case.m](jacky_code/Matlab/overhead_evaluation/prepare_overhead_case.m)，
所以量到的時間差純粹來自演算法本身：

| 方法 | 量測函式 | 線上做的事 |
|------|---------|-----------|
| Only HBR | [measure_only_hbr_runtime.m](jacky_code/Matlab/overhead_evaluation/measure_only_hbr_runtime.m) | 只做關閉束 user 的重新關聯（recovery beam 用預設功率） |
| PC + Tilt | [measure_pc_tilt_runtime.m](jacky_code/Matlab/overhead_evaluation/measure_pc_tilt_runtime.m) | 功率控制 + 傾斜角搜尋 |
| EABR | [measure_eabr_runtime.m](jacky_code/Matlab/overhead_evaluation/measure_eabr_runtime.m) | SBR + EPFD 受限功率配置 + HBR |

Only HBR 的作法是**重用 EABR 的同一組場景**，只在內部加上
`scenario.onlyHbrWithInitialPower = true`，讓
[runGraphSelectionPolicyLocal.m](jacky_code/Matlab/jacky/runGraphSelectionPolicyLocal.m)
跳過 SBR 與功率釋放 —— 所以它一定比 EABR 快，差值就是 SBR 的成本。

兩張圖的繪製與存檔共用
[plot_overhead_bar_chart.m](jacky_code/Matlab/overhead_evaluation/plot_overhead_bar_chart.m)，
字型、尺寸、長條寬度、I 形線畫法完全一致，論文並排時風格統一。
EABR 在兩張圖都用同一個橘色。

**想跳過 Only HBR**（省約 1/3 時間）：

```matlab
overheadMeasureOnlyHbr = false;   % jacky.m overhead 區
% 或直接 cfgOverhead.measureOnlyHbr = false;
```

關掉後 `summaryTable` 不會有 `OnlyHbr*` 欄位，也不會產生第二張圖。

### ⑥ Impact of Different EPFD Limits

| 論文圖 | 內容 | 畫圖程式 | jacky.m 位置 |
|--------|------|---------|-------------|
| `ch5_U70_EABR_AvgUserSatisfaction_EpfdCompare` | EABR 在不同 EPFD 門檻下的平均滿意度 | 同圖三的 `PlotFullPowerSweepSatisfactionVsTimeCompare.m` | `optsFig6` |

**資料產生**：[RunEvalSaprRSweepLocal.m](jacky_code/Matlab/jacky/RunEvalSaprRSweepLocal.m)
（只跑 EABR 一個方法，省下 3/4 的模擬時間）。

`evalEpfdThr_dB_Matrix` 有幾個門檻就畫幾條線。基準值 `-173.4` 的 Excel 已由圖三的
四方法 sweep 產生（檔名不帶 `Thr` 標籤），迴圈會自動跳過不重跑。

---

## 換場景要改哪些關鍵參數

### 一覽表

| 想改什麼 | 改哪個變數 | 位置 | 預設值 |
|---------|-----------|------|--------|
| **使用者負載**（U30/U50/U70） | `evalUsersPerSat_Matrix` | jacky.m 四方法 sweep 區 | `[30, 50, 70]` |
| **要畫哪個負載的圖** | `numUsersPerSatPlot` | jacky.m Evaluation 區 | `70` |
| **EPFD 門檻**（基準） | `evalEpfdThr_dB_Baseline` | jacky.m | `-173.4` |
| **EPFD 門檻**（圖六掃描） | `evalEpfdThr_dB_Matrix` | jacky.m | `[-173.4,-172.4,-171.4,-170.4]` |
| **圖六用哪個負載** | `evalUsersPerSat_Fig6` | jacky.m | `70` |
| **critical 衛星** | `evalCriticalSat` | jacky.m | `"P03_S49"` |
| **Excel 明細記錄的衛星** | `evalRecordSats` | jacky.m | `["P03_S01","P03_S49","P03_S48"]` |
| **模擬時間窗** | `evalTStartStr` / `evalTEndStr` | jacky.m | `16 Dec 2025 12:11:00`～`12:13:30` |
| **time slot 長度** | `evalStepSec` | jacky.m | `1`（秒） |
| **GS 位置** | `evalGsLat_deg` / `evalGsLon_deg` | jacky.m | `0` / `120.4` |
| **beam 大小** | `evalBeamHalfEW_deg` / `evalBeamHalfNS_deg` | jacky.m | `34.0` / `33.5/16` |
| **beam 全開功率** | `evalFullBeamPower_W` | jacky.m | `1.05` W（×16 = 16.8 W/星） |
| **helper beam 功率上限** | `evalMaxBeamPower_W` | jacky.m | `2` W |
| **使用者需求速率** | `evalUserDemand_Mbps` | jacky.m | `50` Mbps |
| **星座高度／傾角** | `alt_km` / `inc_deg` | jacky.m 建立衛星區 | `1200` / `87.9` |
| **軌道面數／每面衛星數** | `numPlanes` / `satsPerPlane` | jacky.m 建立衛星區 | `12` / `49` |
| **哪個軌道面建 RectBeam** | `rectBeamPlanes` | jacky.m | `[3]` |
| **beam 輪廓** | `beamProfile` | jacky.m | `"-5dB"` |
| **EPFD 物理參數** | 整支檔案 | [ku_epfd_params.m](jacky_code/Matlab/jacky/ku_epfd_params.m) | 頻率 11.7 GHz 等 |

### 情境 1：換使用者負載

```matlab
% jacky.m 四方法 sweep 區
evalUsersPerSat_Matrix = [30, 50, 70];   % 改成你要的，例如 [40, 80, 120]
```

跑完 sweep 後，到 Evaluation 區把 `numUsersPerSatPlot` 設成同一個值再畫圖：

```matlab
numUsersPerSatPlot = 80;
```

> ⚠️ **U 值不一致會畫錯圖。** `assertFig3ExcelPathsMatchPlotTag` 會擋下明顯的混用，
> 但仍請自行確認 sweep 與畫圖用的是同一個 U。

### 情境 2：換 EPFD 門檻（圖六）

```matlab
evalUsersPerSat_Fig6  = 70;                                    % 固定一個負載
evalEpfdThr_dB_Matrix = [-173.4, -172.4, -171.4, -170.4];      % 幾個門檻 → 幾條線
```

畫圖時 `numUsersPerSatPlot` 必須設成與 `evalUsersPerSat_Fig6` 相同。

門檻越寬鬆 → 需要關的束越少 → 滿意度越高（這正是論文圖六的結論）。

### 情境 3：換星座密度（helper availability）

密度情境定義在
[config_helper_availability.m](jacky_code/Matlab/helper_availability/config_helper_availability.m)
的 `c1`～`c4`：

| 名稱 | 軌道面 × 每面衛星 | 總數 | 密度參考 |
|------|------------------|------|---------|
| `OneWeb-like reference` | 12 × 49 | 588 | 論文主模擬 |
| `Medium-density` | 24 × 50 | 1200 | 介於中間 |
| `High-density` | 36 × 74 | 2664 | ~Starlink 規模 |
| `Low-density` | 8 × 36 | 288 | ~Lightspeed 規模 |

**只跑其中一種**（High-density 有 2664 顆，很慢）：

```matlab
% jacky.m helper availability 區
helperConstellationsToRun     = "Low-density";     % 統計表用
helperPlotConstellationsToRun = "Medium-density";  % 場景圖用
% 也可以傳陣列或 "all"
```

**新增一種密度**：在 `config_helper_availability.m` 複製 `c4` 改參數，再加進 `cfg.constellations`：

```matlab
c5 = struct();
c5.name              = 'My-density';
c5.epoch             = epoch;
c5.isExampleGeometry = true;
c5.shells            = {mkShell(owAlt_km, owInc_deg, 16, 40, owWalker, owF)};  % 16 面 × 40 顆
c5.ref_shell_index   = 1;
c5.ref_plane_index   = 1;
c5.ref_sat_index     = 1;

cfg.constellations = {c1, c2, c3, c4, c5};
```

**調整 helper 判定的嚴格度**：

```matlab
helperMinOverlapBeamFrac = 1;    % 1.0 = 重疊面積須達一整條 beam；0.5 = 半條
helperTimeHalfWindow_s   = 30;   % 統計時間窗 t = ±N 秒
```

這個門檻直接影響 Table 的第 2、4 欄，調鬆會讓 helper 數量上升。

### 情境 4：換星座本身（主模擬）

```matlab
% jacky.m 建立衛星區
alt_km       = 1200;    % 高度
inc_deg      = 87.9;    % 傾角
numPlanes    = 12;      % 軌道面數 → 決定 RAAN 間距 (180/numPlanes)
satsPerPlane = 49;      % 每面衛星數 → 決定同軌相位間距 (360/satsPerPlane)
```

> ⚠️ **重要陷阱**：[CreateWalkerConstellation_HPOP.m](jacky_code/Matlab/jacky/CreateWalkerConstellation_HPOP.m)
> 的迴圈寫死 `for p = 1:5`，**只實際建立 5 個軌道面**（P01～P05）。
> RAAN 間距仍照 `numPlanes` 計算，所以幾何等同完整星座，只是為了省建場時間而不建其餘軌道面。
>
> 如果你需要用到 P06 以上的衛星（例如把 `evalCriticalSat` 改成 `P08_S20`），
> **必須把該行改成 `for p = 1:numPlanes`**，只改 `numPlanes` 是不會生效的。

換 critical 衛星時要同步改三處：

```matlab
evalCriticalSat = "P03_S49";                              % ← 改這裡
evalRecordSats  = ["P03_S01", "P03_S49", "P03_S48"];      % ← 也要改
rectBeamPlanes  = [3];                                     % ← 對應的軌道面
satUserTargets  = [...];                                   % ← 灑 user 的衛星清單
```

### 情境 5：換 GS / GSO 位置

```matlab
evalGsLat_deg = 0;        % GS 緯度
evalGsLon_deg = 120.4;    % GS 經度（受擾 GSO 星下點設在同一點 → 最壞 in-line 幾何）
```

`useIdealGsoAtGs = true`（在 `BuildEvalEnvironmentLocal.m` 內設定）代表把 GSO
放在 GS 正上方，也就是最嚴苛的干擾幾何。要模擬非 in-line 的情況需改這個旗標。

helper availability 模組有自己的一組（`config_helper_availability.m`）：

```matlab
common.gsLat_deg  = 0;
common.gsLon_deg  = 0;
common.gsoLon_deg = 0;
```

### 情境 6：調整 overhead 量測

```matlab
% jacky.m overhead 區
overheadSlotHalfWindow_s = 30;          % t_worst 前後各 N 秒（30 → 共 60 slot）
overheadMeasureOnlyHbr   = true;        % 是否一併量 Only HBR（多產生第二張圖）
overheadPcTiltSearchMode = 'max_only';  % 'max_only' | 'coarse_to_fine' | 'exhaustive'
```

`overheadPcTiltSearchMode` 是**PC+Tilt 那張圖最敏感的參數**，直接決定它的執行時間：

| 模式 | 每 slot 候選角度數 | 速度 |
|------|------------------|------|
| `max_only` | ≤ 2（只試 ±tiltMax） | 最快（論文採用） |
| `coarse_to_fine` | 粗搜 + 局部細搜 | 中等 |
| `exhaustive` | ≈ 2×tiltMax/step + 1 | 最慢 |

論文用 `max_only`，等於給 PC+Tilt 最有利的設定去比較。

其餘參數在 [overhead_config.m](jacky_code/Matlab/overhead_evaluation/overhead_config.m)：
`userLoads`、`measureOnlyHbr`、`epfdThreshold_dB`、`nLocalSats`、`runtimeRangePercentiles`，
以及兩張圖的輸出路徑 `figureExportPaths` / `onlyHbrFigureExportPaths`。

### 情境 7：換 EPFD 物理參數

全部集中在 [ku_epfd_params.m](jacky_code/Matlab/jacky/ku_epfd_params.m)，**只改這一支**：

```matlab
P.freq_GHz   = 11.7;      % 下行載波頻率
P.BWref_Hz   = 4e4;       % EPFD 參考頻寬 40 kHz
P.EPFD_thr_dB = -173.4;   % EPFD 門檻
P.GSO_D_m    = 0.6;       % GSO 地球站參考天線徑 60 cm
P.LEO_D_m    = 0.55;      % LEO 發射天線口徑
P.beta_fit   = -0.0671;   % 天線場型擬合係數 G ≈ A·exp(β·φ)
P.B_Hz       = 250e6;     % user link 頻寬
P.Nchannel   = 8;         % Ku user 通道數
```

> ⚠️ **不要跟 `powertilt/paper_params.m` 搞混。** 那支是 Jalali et al. 原論文的
> **Ka 頻段**參數（19.7 GHz / 200 MHz），只給 `powertilt/` 底下的復現驗證腳本用。
> 本論文所有 Evaluation（含 PC+Tilt baseline）走的都是 `ku_epfd_params.m` 的 **Ku 頻段**參數。

---

## 輸出檔案命名規則

全部輸出到 `jacky_code/Matlab_data/`。

### 四方法模擬結果

```
FullPower_BeamShutdownSweep_GS01_U<U>_<方法>.xlsx
```

| `<方法>` | 論文中的名稱 |
|---------|------------|
| `BackoffOnly` | Beam shutdown only |
| `RelayOnly` | Only HBR |
| `RelayWithMiddleSwap` | **EABR** |

PC + Tilt 走另一套命名：

```
LEO16_Ku_Baseline_Observation_PC_BaselineTilt_GS01_U<U>_Aligned.xlsx
```

### 圖六的不同 EPFD 門檻

門檻標籤規則（[epfdThrPathTagLocal.m](jacky_code/Matlab/jacky/epfdThrPathTagLocal.m)）：
去掉負號、小數點換成 `p`。

```
-172.4  →  Thr172p4
FullPower_BeamShutdownSweep_GS01_U70_Thr172p4_RelayWithMiddleSwap.xlsx
```

基準門檻 `-173.4` 的檔案**不帶** `Thr` 標籤（由四方法 sweep 產生）。

### 圖檔

每張圖同時輸出 `.png` 與對應數據的 `.xlsx`：

```
FullPower_BeamShutdownSweep_GS01_U70_P03S49_EPFD_afterShutdown_vsRelTime.png   ← 圖一
FullPower_BeamShutdownSweep_GS01_U70_P03S49_ClosedCriticalBeams_vsRelTime.png  ← 圖二
FullPower_BeamShutdownSweep_GS01_U70_P03S49_AvgUserSatisfaction_4MethodCompare.png       ← 圖三
FullPower_BeamShutdownSweep_GS01_U70_P03S49_RelayUserCount_OnlyBPLR_vs_SAPR-R.png        ← 圖四
FullPower_BeamShutdownSweep_GS01_U70_P03S49_UserSatisfaction_CDF_3MethodCompare.png      ← 圖五
FullPower_BeamShutdownSweep_GS01_U70_P03S49_SAPR-R_AvgUserSatisfaction_EpfdCompare.png   ← 圖六
```

放進論文時再改名成 `論文/figures/` 底下的 `ch5_*` / `ch6_*` 名稱。

### Overhead 圖檔

overhead 模組的兩張圖各輸出 `.png`（600 dpi）/ `.fig` / `.pdf`（向量，論文用），
並且**同時寫到兩個位置**：`Matlab_data/` 與 `overhead_evaluation/results/`。

```
runtime_overhead_pc_tilt_vs_eabr.{png,fig,pdf}    → 論文 PC+Tilt vs EABR
runtime_overhead_only_hbr_vs_eabr.{png,fig,pdf}   → 論文 ch5_overhead_only_hbr_vs_eabr
overhead_runtime_summary.csv                       → 各負載的 min/avg/max/std 統計表
overhead_runtime_raw.mat                           → 每個 slot 的原始執行時間與中繼資料
```

`overhead_runtime_summary.csv` 的欄位：`UserLoad`、`PcTilt*`、`EABR*`，
以及 `cfg.measureOnlyHbr = true` 時才會出現的 `OnlyHbr*`。

---

## 常見問題與已知限制

### 執行相關

**`Invalid ProgID 'STK12.application'` 或 `actxGetRunningServer` 失敗**
STK 沒開，或 STK 版本不是 12。必須先手動啟動 STK 並開好場景。

**`leoRectBeam is empty` 警告**
`rectBeamPlanes` 指定的軌道面在 STK 場景裡沒有衛星。
記得 `CreateWalkerConstellation_HPOP` 只建 P01～P05，所以 `rectBeamPlanes` 不能設 6 以上。

**`Skip fig.3: missing ...LEO16_Ku_Baseline_Observation_PC_BaselineTilt...`**
PC + Tilt 的 Excel 還沒產生。需要跑過 cell 5 的四方法 sweep。

**`Skip fig.5: ... PerUser ...`**
舊版 Excel 缺 `PerUser` 分頁，需重跑 RelayOnly 與 EABR 的 sweep。

**`Skip fig.6 line EPFD=... : missing ...Thr...`**
該門檻的 sweep 還沒跑。檢查 `evalEpfdThr_dB_Matrix` 與已產生的檔案是否一致。

**`EPFD still illegal after backoff; relay skipped.`**
關掉所有 beam 後 EPFD 仍超標，該 slot 會跳過救援。通常代表門檻設得太嚴，
或參與 EPFD 累加的衛星數（`leoList`）過多。

