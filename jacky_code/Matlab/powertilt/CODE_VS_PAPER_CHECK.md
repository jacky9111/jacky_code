# 程式與論文對照檢查 (Joint Power and Tilt Control in Satellite, OJVT 2023)

## 一、與論文一致的部分

| 項目 | 論文 | 程式 | 狀態 |
|------|------|------|------|
| 頻率 | 19.7 GHz | P.freq_GHz = 19.7 | ✓ |
| 帶寬 | 200 MHz | P.B_Hz = 200e6 | ✓ |
| LEO 最大功率 | 10 dBW (10 W) | P.Pmax_W = 10 | ✓ |
| LEO 最大增益 | 39.6 dBi | P.LEO_Gmax_dBi = 39.6 | ✓ |
| 最大 tilt 角 | 10° | P.theta_max_deg = 10 | ✓ |
| 天線近似係數 A, β | A=1.0632e+04, β=-0.0671 | P.A_fit, P.beta_fit | ✓ |
| GSO 地面站增益/直徑 | 40.95 dBi, 70 cm | P.GSO_Gmax_dBi, P.D_ref_m | ✓ |
| EPFD 門檻 | -173.4 dB(W/m²/1MHz) | P.EPFD_thr_dB = -173.4 | ✓ |
| 最小仰角 | 10° | P.min_elev_deg = 10 | ✓ |
| 噪聲溫度 | 240 K | P.user_noise_temp_K, P.GSO_noise_temp_K | ✓ |
| Half 3dB 波束寬 | 13.9° | P.leo_half_3dB_deg_paper = 13.9 | ✓ |
| ζ_thr | 0.7 | P.zeta_thr = 0.7 | ✓ |
| 每衛星用戶數 | 5 | U_init = 5 | ✓ |
| 需求範圍 | 4–6 Gbps | demand_min/max = 4e9, 6e9 | ✓ |
| EPFD 公式 Eq.(17) | γ_i = (A G'_G(φ'_i) exp(βφ'_i))/(BW_ref 4πd_i² G'_Gmax) | Precompute_EPFD_Terms_STK：phi_r 用於 GSO 增益，phi_t 用於 exp(β·) | ✓ |
| Problem 18 結構 | L1 EPFD, L2 功率, L3 tilt；目標 min \|\|C-D\|\|_2 | solve_problem_18 三約束 + 容量誤差目標 | ✓ |
| 變數代換 P_i = exp(q_i) | 論文採用 | CVX 使用 q, theta | ✓ |

---

## 二、與論文不一致或需說明的部分

### 1. 關鍵衛星判定用功率 (Algorithm 1 Step 4) — **已對齊論文**

- **論文**：Step 4 使用 **Step 2 得到的初始功率分配 p_i**，條件 (γ_i · p_i) / 10^(EPFD_thr/10) ≥ ζ_thr。
- **程式**：已改為使用 **Pi_init**（Step 2 的初始功率）判定關鍵衛星，與論文一致。

### 2. GSO 地面站天線主瓣 (Eq.9)

- **論文 Eq.(9)**：主瓣為 Gmax − 0.0025**(ψ/ψm)²**，其中 ψm = (20λ/D)·√(Gmax − G1)。
- **程式** (`gso_rx_gain_itu1428.m`)：主瓣為 Gmax − 0.0025**(φ·D/λ)²**。
- **說明**：主瓣形狀不同（(ψ/ψm)² 與 (φ·D/λ)² 對角度依賴不同），其餘分段（G1、29−25log ψ、-9、-4 等）與論文一致。若需完全對齊論文，需改為依 Eq.(9)(10) 實作 ψm 與 (ψ/ψm)²。

### 3. 容量常數 k_i,u 與 LEO→用戶增益 (Eq.3, Eq.15)

- **論文**：Eq.3 中 LEO→用戶通道含 **Gi(ψi,u)**（LEO 對用戶的增益）；優化時用 Eq.13 近似 **A·exp(β·φ'_i,u)**，故 Eq.15 的 k_i,u 應含 **A·exp(β·φ'_i,u)**（φ'_i,u = LEO i 對用戶 u 的離軸角）。
- **程式** (`Precompute_Capacity_Constants_STK.m`)：k 僅含 **A·Gur·λ²/(4πd)²**，未乘 **exp(β·φ'_i,u)**。
- **說明**：程式相當於假設用戶都在波束軸上（φ'=0）得到常數項，只對 tilt 項乘 exp(β·s·θ)。若用戶離軸角較大，會高估容量。

### 4. 多顆關鍵衛星時的篩選

- **論文**：只說明 ζ_thr = 0.7 時在給定場景下「會得到一顆關鍵衛星」，未寫「只保留一顆」的規則。
- **程式** (`find_critical_satellites.m`)：當多顆滿足 ≥ ζ_thr 時，若最大貢獻 ≥ 第二大的 **10 倍**，則只保留貢獻最大的一顆。
- **說明**：此為程式額外啟發式，論文無此 10 倍篩選；一般情境下論文參數會自然只出現一顆關鍵衛星。

### 5. 通道模型中的 Lsh、Latm (Eq.3)

- **論文**：|hi,u|² 含 **Lsh**（遮蔽）、**Latm**（大氣）。
- **程式**：`Precompute_Capacity_Constants_STK` 未加入 Lsh、Latm。
- **說明**：程式為理想通道，若需與論文仿真一致可再引入 Lsh、Latm 模型。

---

## 三、建議修改優先順序（若要嚴格對齊論文）

1. ~~**高**：Algorithm 1 Step 4 改為使用 **Pi_init**~~ → **已實作**
2. **中**：容量常數 **k_i,u** 加入 **exp(β·φ'_i,u)**，其中 φ'_i,u 為 LEO i 到用戶 u 的 off-nadir 角。
3. **低**：GSO 天線主瓣改為論文 Eq.(9)(10) 的 (ψ/ψm)² 形式；視需要加入 Lsh、Latm。

---

## 四、Plot_Figure14_LEO_Passing.m 與論文 Figure 14

- **5 用戶 / 每用戶 4–6 Gbps**：與論文多用戶設定一致。
- **EPFD violation (c)**：已改為**所有可見 LEO 在 Pmax 下的總 EPFD** 與門限比較（ITU 總 EPFD）。
- **關鍵衛星**：已改為先 Step 2 得 Pi_init，再以 Pi_init 識別關鍵衛星（Algorithm 1 Step 4）。
- **緯度範圍**：[-1.5, 1.5] deg，與論文 Figure 14 一致。

---

*對照依據：論文 Table 1、Eq.(2)(3)(9)(10)(13)(15)(17)、Algorithm 1、Section IV 仿真參數與圖表說明。*
