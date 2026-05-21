---
title: ACMT HPC 集群節點配置文檔
type: Reference (hardware configuration)
last_updated: 2026-05-22
source_of_truth: This file (hardware specs); `STATUS.md` §1.1 (current node availability)
---

# ACMT HPC 集群節點配置文檔

**集群名稱**: ACMT  
**管理節點**: acmt0  
**總節點數**: 28 (27 個計算節點 + 1 個 GPU 節點)

> 本檔記錄 **硬體配置與分區結構**（屬於 Protocol 層級，變動頻率低）。  
> **目前節點可用狀態** → 見 [`STATUS.md`](STATUS.md) §1.1 或 `acmt nodes` / `sinfo` 即時抓取。  
> 不要在本檔內嵌即時狀態，避免 stale。

---

## 1. 分區配置詳情

### r620 分區（高記憶體）
- **節點**: acmt01, acmt02
- **CPU**: Intel Xeon E5-2590v3 @ 2.9GHz
- **核心**: 16 cores (2×8×1)
- **記憶體**: 209GB

### r630a 分區（高效能）
- **節點**: acmt04
- **CPU**: Intel Xeon E5-2697v3
- **核心**: 28 cores (2×14×2)
- **記憶體**: 126GB

### r630b 分區（平衡型）
- **節點**: acmt05, acmt06
- **CPU**: Intel Xeon E5-2690v3 @ 2.6GHz
- **核心**: 24 cores (2×12×2)
- **記憶體**: 126GB

### r630c 分區（標準型）
- **節點**: acmt07
- **CPU**: Intel Xeon E5-2620v4
- **核心**: 20 cores (2×10×2)
- **記憶體**: 64GB

### r630l 分區（大記憶體）
- **節點**: acmt08
- **CPU**: Intel Xeon E5-2697v3
- **核心**: 28 cores (2×14×2)
- **記憶體**: 128GB

### r630m 分區（中階）
- **節點**: acmt03, acmt12
- **CPU**: Intel Xeon E5-2620v4
- **核心**: 16 cores (2×8×2)
- **記憶體**: 154GB

### r630s 分區（入門級）— 預設分區
- **節點**: acmt09–11, acmt13–15（共 6 個；acmt12 屬 r630m）
- **CPU**: Intel Xeon E5-2620v2
- **核心**: 12 physical / 24 logical (2:6:2，HT on)
- **記憶體**: 15GB（節點記憶體偏小，注意作業 mem 申請）

### apollo 分區（Silver 系列）
- **節點**: acmt16–19
- **CPU**: Intel Xeon Silver 4114
- **核心**: 20 cores (2×10×2)
- **記憶體**: 11GB

### r740 分區（RTX 3090 GPU 節點）
- **節點**: acmt20
- **CPU**: Intel Xeon Gold 5118 @ 2.3GHz
- **核心**: 24 cores (2×12×2)
- **記憶體**: 112GB
- **GPU**: **2 × NVIDIA GeForce RTX 3090 24GB GDDR6X**（Ampere sm_86，driver 560.35.05）

### gpu 分區（P100 GPU 節點）
- **節點**: acmt-gpu
- **CPU**: AMD EPYC 7252
- **核心**: 16 cores (2×8×1)
- **記憶體**: 64GB
- **GPU**: **4 × NVIDIA Tesla P100 PCIe 16GB HBM2**（Pascal sm_60）
- **OverSubscribe**: YES（唯一允許單節點多作業的分區）
- ⚠️ 目前 `nvidia-smi` 報 NVML driver/library mismatch — 跑作業前需先排查（見 [`STATUS.md`](STATUS.md) ISS-NODE-10）

### dl360 分區（高效能計算）
- **節點**: acmt21–26
- **CPU**: Intel Xeon Gold 6142
- **核心**: 32 cores (2×16×2)
- **記憶體**: 251GB

### dl360s 分區（單執行緒）
- **節點**: acmt27
- **CPU**: Intel Xeon Gold 6142
- **核心**: 16 cores (2×16×1)
- **記憶體**: 251GB

---

## 2. 硬體統計

### 2.1 CPU 類型分佈

| CPU 型號 | 節點數 | 用途 |
|---------|-------|------|
| Intel Xeon Gold 6142 | 7 | 最高效能 |
| Intel Xeon E5-2620v2 | 7 | 入門級 |
| Intel Xeon Silver 4114 | 4 | 平衡型 |
| Intel Xeon E5-2620v4 | 3 | 標準型 |
| Intel Xeon E5-2697v3 | 2 | 高效能 |
| Intel Xeon E5-2590v3 | 2 | 高記憶體 |
| Intel Xeon E5-2690v3 | 2 | 平衡型 |
| Intel Xeon Gold 5118 | 1 | GPU |
| AMD EPYC 7252 | 1 | GPU |

### 2.2 記憶體配置

| 容量 | 節點數 | 系列 |
|------|-------|------|
| 251GB | 7 | dl360 |
| 209GB | 2 | r620 |
| 154GB | 2 | r630m |
| 128GB | 1 | r630l |
| 126GB | 3 | r630a/b |
| 112GB | 1 | r740 |
| 64GB | 2 | r630c, gpu |
| 15GB | 7 | r630s |
| 11GB | 4 | apollo |

### 2.3 GPU 配置（heterogeneous — 跑作業前選對分區）

- **acmt20** (`r740`): 2 × NVIDIA GeForce RTX 3090 24GB（Ampere sm_86，Intel Xeon 平台）
- **acmt-gpu** (`gpu`): 4 × NVIDIA Tesla P100 PCIe 16GB（Pascal sm_60，AMD EPYC 平台）
- **總計**: 2 × RTX 3090 + 4 × Tesla P100 = 6 張 GPU / 共 112GB GPU 記憶體（48GB GDDR6X + 64GB HBM2）
- **CUDA 相容**: P100 需 ≥ 9.0；RTX 3090 需 ≥ 11.0（共用 cuda/12.6 即可同時支援兩款）

---

## 3. 容量規劃（理論值）

| 項目 | 數值 |
|------|------|
| 總 physical cores | ~560 |
| 總 logical CPUs（含 HT） | ~1100 |
| 總記憶體 | 約 2.8TB |
| GPU 總記憶體 | 112GB（64GB HBM2 + 48GB GDDR6X） |
| NFS 共用儲存 | 11TB `/home` + 11TB `/opt`（acmt-storage） |

> 實際可用節點數請以 `sinfo` 抓取，並參照 [`STATUS.md`](STATUS.md) §1.1 排除已知 down/drain 節點。

---

## 4. 網路與儲存

- **本地儲存**：各節點獨立配置
- **NFS 共享**：11TB `/home` 與 `/opt`（192.168.1.11）
- **網路拓撲**：見 [`network-topology.md`](network-topology.md)
- **InfiniBand**：見 [`ACMT_InfiniBand_Analysis_Report.md`](ACMT_InfiniBand_Analysis_Report.md)

---

## 5. GPU 詳細規格

### NVIDIA Tesla P100 PCIe 16GB（acmt-gpu，4 張）

| 項目 | 規格 |
|------|------|
| GPU 架構 | Pascal（sm_60） |
| CUDA 核心 | 3584 |
| 記憶體 | 16GB HBM2 |
| 記憶體頻寬 | 720 GB/s |
| 雙精度效能 (FP64) | 5.3 TFLOPS |
| 單精度效能 (FP32) | 10.6 TFLOPS |
| NVLink | 支援 |
| CUDA 版本 | ≥ 9.0 |
| 功耗 | 300W |

### NVIDIA GeForce RTX 3090 24GB（acmt20，2 張）

| 項目 | 規格 |
|------|------|
| GPU 架構 | Ampere（sm_86） |
| CUDA 核心 | 10496；Tensor 核心 328 |
| 記憶體 | 24GB GDDR6X |
| 記憶體頻寬 | 936 GB/s |
| 雙精度效能 (FP64) | ~0.56 TFLOPS（**不適合 FP64**） |
| 單精度效能 (FP32) | 35.6 TFLOPS |
| Driver | 560.35.05 |
| CUDA 版本 | ≥ 11.0 |
| 功耗 | 350W |

### 適用場景（分區選擇）

| 工作類型 | 建議節點 | 原因 |
|---------|---------|------|
| FP64 科學模擬（CFD、FEA） | `gpu` (acmt-gpu, P100) | P100 FP64 強且支援 NVLink |
| 深度學習訓練/推論 | `r740` (acmt20, RTX 3090) | 大顯存 24GB、FP32 高 |
| 需要 24GB 以上顯存的單卡作業 | `r740` (acmt20) | RTX 3090 顯存大 |
| 多卡平行（NVLink） | `gpu` (acmt-gpu) | 4 張 P100 + NVLink |

---

## 6. 分區用途建議（穩定性建議，與當前可用性無關）

| 分區 | 建議用途 |
|------|---------|
| dl360 / dl360s | 大型 CPU 工作（高核心、高記憶體） |
| r740 / gpu | GPU 工作負載（DL、CFD 模擬） |
| r620 | 大記憶體單機作業 |
| r630a–m | 中型平行作業 |
| r630s | 小作業、教學、CI |
| apollo | 低記憶體輕量任務 |
