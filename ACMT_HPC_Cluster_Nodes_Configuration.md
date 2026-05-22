---
title: ACMT HPC Cluster Node Configuration | ACMT HPC 集群節點配置文檔
type: Reference (hardware configuration)
last_updated: 2026-05-22
source_of_truth: This file (hardware specs); `STATUS.md` §1.1 (current node availability)
---

# ACMT HPC Cluster Node Configuration / ACMT HPC 集群節點配置文檔

**Cluster name / 集群名稱**: ACMT
**Headnode / 管理節點**: acmt0
**Total nodes / 總節點數**: 28 (27 compute nodes + 1 GPU node / 27 個計算節點 + 1 個 GPU 節點)

> This document records **hardware configuration and partition layout** (Protocol-level, low-frequency changes).
> **Current node availability** → see [`STATUS.md`](STATUS.md) §1.1 or run `acmt nodes` / `sinfo` to fetch live state.
> Do not embed live status here to avoid drift.
>
> 本檔記錄 **硬體配置與分區結構**（屬於 Protocol 層級，變動頻率低）。
> **目前節點可用狀態** → 見 [`STATUS.md`](STATUS.md) §1.1 或 `acmt nodes` / `sinfo` 即時抓取。
> 不要在本檔內嵌即時狀態，避免 stale。

---

## 1. Partition Configuration Details / 分區配置詳情

### r620 — High-memory partition / 高記憶體分區

- **Nodes / 節點**: acmt01, acmt02
- **CPU**: Intel Xeon E5-2590v3 @ 2.9GHz
- **Cores / 核心**: 16 cores (2×8×1)
- **RAM / 記憶體**: 209GB

### r630a — High-performance partition / 高效能分區

- **Nodes / 節點**: acmt04
- **CPU**: Intel Xeon E5-2697v3
- **Cores / 核心**: 28 cores (2×14×2)
- **RAM / 記憶體**: 126GB

### r630b — Balanced partition / 平衡型分區

- **Nodes / 節點**: acmt05, acmt06
- **CPU**: Intel Xeon E5-2690v3 @ 2.6GHz
- **Cores / 核心**: 24 cores (2×12×2)
- **RAM / 記憶體**: 126GB

### r630c — Standard partition / 標準型分區

- **Nodes / 節點**: acmt07
- **CPU**: Intel Xeon E5-2620v4
- **Cores / 核心**: 20 cores (2×10×2)
- **RAM / 記憶體**: 64GB

### r630l — Large-memory partition / 大記憶體分區

- **Nodes / 節點**: acmt08
- **CPU**: Intel Xeon E5-2697v3
- **Cores / 核心**: 28 cores (2×14×2)
- **RAM / 記憶體**: 128GB

### r630m — Mid-tier partition / 中階分區

- **Nodes / 節點**: acmt03, acmt12
- **CPU**: Intel Xeon E5-2620v4
- **Cores / 核心**: 16 cores (2×8×2)
- **RAM / 記憶體**: 154GB

### r630s — Entry-level partition (default) / 入門級分區（預設分區）

- **Nodes / 節點**: acmt09–11, acmt13–15 (6 nodes; acmt12 belongs to r630m / 共 6 個；acmt12 屬 r630m)
- **CPU**: Intel Xeon E5-2620v2
- **Cores / 核心**: 12 physical / 24 logical (2:6:2, HT on)
- **RAM / 記憶體**: 15GB (small per-node memory — watch job mem requests / 節點記憶體偏小，注意作業 mem 申請)

### apollo — Silver-series partition / Silver 系列分區

- **Nodes / 節點**: acmt16–19
- **CPU**: Intel Xeon Silver 4114
- **Cores / 核心**: 20 cores (2×10×2)
- **RAM / 記憶體**: 11GB

### r740 — RTX 3090 GPU partition / RTX 3090 GPU 節點

- **Nodes / 節點**: acmt20
- **CPU**: Intel Xeon Gold 5118 @ 2.3GHz
- **Cores / 核心**: 24 cores (2×12×2)
- **RAM / 記憶體**: 112GB
- **GPU**: **2 × NVIDIA GeForce RTX 3090 24GB GDDR6X** (Ampere sm_86, driver 560.35.05)

### gpu — P100 GPU partition / P100 GPU 節點

- **Nodes / 節點**: acmt-gpu
- **CPU**: AMD EPYC 7252
- **Cores / 核心**: 16 cores (2×8×1)
- **RAM / 記憶體**: 64GB
- **GPU**: **4 × NVIDIA Tesla P100 PCIe 16GB HBM2** (Pascal sm_60)
- **OverSubscribe**: YES (the only partition allowing multiple jobs per node / 唯一允許單節點多作業的分區)
- ⚠️ `nvidia-smi` currently reports NVML driver/library mismatch — investigate before running jobs (see [`STATUS.md`](STATUS.md) ISS-NODE-10).
- ⚠️ 目前 `nvidia-smi` 報 NVML driver/library mismatch — 跑作業前需先排查（見 [`STATUS.md`](STATUS.md) ISS-NODE-10）

### dl360 — High-performance computing partition / 高效能計算分區

- **Nodes / 節點**: acmt21–26
- **CPU**: Intel Xeon Gold 6142
- **Cores / 核心**: 32 cores (2×16×2)
- **RAM / 記憶體**: 251GB

### dl360s — Single-threaded partition / 單執行緒分區

- **Nodes / 節點**: acmt27
- **CPU**: Intel Xeon Gold 6142
- **Cores / 核心**: 16 cores (2×16×1)
- **RAM / 記憶體**: 251GB

---

## 2. Hardware Statistics / 硬體統計

### 2.1 CPU Distribution / CPU 類型分佈

| CPU model / CPU 型號 | Nodes / 節點數 | Purpose / 用途 |
|---------|-------|------|
| Intel Xeon Gold 6142 | 7 | Top performance / 最高效能 |
| Intel Xeon E5-2620v2 | 7 | Entry-level / 入門級 |
| Intel Xeon Silver 4114 | 4 | Balanced / 平衡型 |
| Intel Xeon E5-2620v4 | 3 | Standard / 標準型 |
| Intel Xeon E5-2697v3 | 2 | High performance / 高效能 |
| Intel Xeon E5-2590v3 | 2 | High memory / 高記憶體 |
| Intel Xeon E5-2690v3 | 2 | Balanced / 平衡型 |
| Intel Xeon Gold 5118 | 1 | GPU |
| AMD EPYC 7252 | 1 | GPU |

### 2.2 Memory Configuration / 記憶體配置

| Capacity / 容量 | Nodes / 節點數 | Series / 系列 |
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

### 2.3 GPU Configuration / GPU 配置

Heterogeneous — pick the right partition before submitting jobs.

GPU 為異質配置 — 跑作業前選對分區：

- **acmt20** (`r740`): 2 × NVIDIA GeForce RTX 3090 24GB (Ampere sm_86, Intel Xeon platform / Ampere sm_86，Intel Xeon 平台)
- **acmt-gpu** (`gpu`): 4 × NVIDIA Tesla P100 PCIe 16GB (Pascal sm_60, AMD EPYC platform / Pascal sm_60，AMD EPYC 平台)
- **Total / 總計**: 2 × RTX 3090 + 4 × Tesla P100 = 6 GPUs / 112GB GPU memory (48GB GDDR6X + 64GB HBM2) / 共 6 張 GPU、共 112GB GPU 記憶體
- **CUDA compatibility / CUDA 相容**: P100 needs ≥ 9.0; RTX 3090 needs ≥ 11.0 (shared cuda/12.6 covers both) / P100 需 ≥ 9.0；RTX 3090 需 ≥ 11.0（共用 cuda/12.6 即可同時支援兩款）

---

## 3. Capacity Planning (Theoretical) / 容量規劃（理論值）

| Item / 項目 | Value / 數值 |
|------|------|
| Total physical cores / 總 physical cores | ~560 |
| Total logical CPUs (with HT) / 總 logical CPUs（含 HT） | ~1100 |
| Total RAM / 總記憶體 | ~2.8TB |
| Total GPU memory / GPU 總記憶體 | 112GB (64GB HBM2 + 48GB GDDR6X) |
| NFS shared storage / NFS 共用儲存 | 11TB `/home` + 11TB `/opt` (acmt-storage) |

> Pull actual available node count via `sinfo` and cross-check [`STATUS.md`](STATUS.md) §1.1 to exclude known down/drain nodes.
>
> 實際可用節點數請以 `sinfo` 抓取，並參照 [`STATUS.md`](STATUS.md) §1.1 排除已知 down/drain 節點。

---

## 4. Network & Storage / 網路與儲存

- **Local storage / 本地儲存**: Each node has its own local disks / 各節點獨立配置
- **NFS shares / NFS 共享**: 11TB `/home` and `/opt` (192.168.1.11) / 11TB `/home` 與 `/opt`（192.168.1.11）
- **Network topology / 網路拓撲**: see [`network-topology.md`](network-topology.md) / 見 [`network-topology.md`](network-topology.md)
- **InfiniBand**: see [`ACMT_InfiniBand_Analysis_Report.md`](ACMT_InfiniBand_Analysis_Report.md) / 見 [`ACMT_InfiniBand_Analysis_Report.md`](ACMT_InfiniBand_Analysis_Report.md)

---

## 5. GPU Detailed Specifications / GPU 詳細規格

### NVIDIA Tesla P100 PCIe 16GB (acmt-gpu, 4 cards / 4 張)

| Item / 項目 | Spec / 規格 |
|------|------|
| GPU architecture / GPU 架構 | Pascal (sm_60) |
| CUDA cores / CUDA 核心 | 3584 |
| Memory / 記憶體 | 16GB HBM2 |
| Memory bandwidth / 記憶體頻寬 | 720 GB/s |
| FP64 performance / 雙精度效能 (FP64) | 5.3 TFLOPS |
| FP32 performance / 單精度效能 (FP32) | 10.6 TFLOPS |
| NVLink | Supported / 支援 |
| CUDA version / CUDA 版本 | ≥ 9.0 |
| Power / 功耗 | 300W |

### NVIDIA GeForce RTX 3090 24GB (acmt20, 2 cards / 2 張)

| Item / 項目 | Spec / 規格 |
|------|------|
| GPU architecture / GPU 架構 | Ampere (sm_86) |
| CUDA / Tensor cores / CUDA 核心 | 10496 CUDA cores; 328 Tensor cores / CUDA 核心 10496；Tensor 核心 328 |
| Memory / 記憶體 | 24GB GDDR6X |
| Memory bandwidth / 記憶體頻寬 | 936 GB/s |
| FP64 performance / 雙精度效能 (FP64) | ~0.56 TFLOPS (**not suitable for FP64** / **不適合 FP64**) |
| FP32 performance / 單精度效能 (FP32) | 35.6 TFLOPS |
| Driver | 560.35.05 |
| CUDA version / CUDA 版本 | ≥ 11.0 |
| Power / 功耗 | 350W |

### Use-case Recommendations (partition selection) / 適用場景（分區選擇）

| Workload type / 工作類型 | Recommended node / 建議節點 | Reason / 原因 |
|---------|---------|------|
| FP64 scientific simulation (CFD, FEA) / FP64 科學模擬（CFD、FEA） | `gpu` (acmt-gpu, P100) | Strong FP64 + NVLink / P100 FP64 強且支援 NVLink |
| Deep-learning training/inference / 深度學習訓練/推論 | `r740` (acmt20, RTX 3090) | Large VRAM 24GB, strong FP32 / 大顯存 24GB、FP32 高 |
| Single-card job needing >24GB VRAM / 需要 24GB 以上顯存的單卡作業 | `r740` (acmt20) | RTX 3090 has large VRAM / RTX 3090 顯存大 |
| Multi-card parallel (NVLink) / 多卡平行（NVLink） | `gpu` (acmt-gpu) | 4 × P100 + NVLink / 4 張 P100 + NVLink |

---

## 6. Partition Use-case Guidance / 分區用途建議

Stability-based suggestions independent of current availability.

穩定性建議，與當前可用性無關。

| Partition / 分區 | Recommended workload / 建議用途 |
|------|---------|
| dl360 / dl360s | Large CPU jobs (many cores, high RAM) / 大型 CPU 工作（高核心、高記憶體） |
| r740 / gpu | GPU workloads (DL, CFD simulation) / GPU 工作負載（DL、CFD 模擬） |
| r620 | Large-memory single-node jobs / 大記憶體單機作業 |
| r630a–m | Medium parallel jobs / 中型平行作業 |
| r630s | Small jobs, teaching, CI / 小作業、教學、CI |
| apollo | Low-memory lightweight tasks / 低記憶體輕量任務 |
