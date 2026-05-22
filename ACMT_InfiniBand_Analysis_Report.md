---
title: ACMT HPC Cluster InfiniBand Implementation Status Report | ACMT HPC 集群 InfiniBand 實現狀況報告
type: Snapshot
last_updated: 2026-01-25
source_of_truth: This file (frozen analysis snapshot at 2026-01-25)
---

# ACMT HPC Cluster InfiniBand Implementation Status Report / ACMT HPC 集群 InfiniBand 實現狀況報告

> **Status: SUPERSEDED — 2026-05-22.** This snapshot is no longer being maintained. For current InfiniBand topology see [network-topology.md §IB](network-topology.md). For per-node IB device presence run `ssh admin "ibstat"` directly. This file is retained for historical reference.
>
> **狀態：已被取代 — 2026-05-22。** 本快照不再維護。當前 InfiniBand 拓撲請見 [network-topology.md §IB](network-topology.md)；逐節點 IB 裝置狀態請直接執行 `ssh admin "ibstat"`。本檔僅作歷史參考。

**Generated**: 2026-01-25
**Inspected node**: acmt0 (headnode)
**Report scope**: InfiniBand hardware configuration, network topology, connection status

**生成時間**：2026-01-25
**檢查節點**：acmt0 (headnode)
**報告範圍**：InfiniBand 硬體配置、網路拓撲、連接狀態

> This is a one-off analysis snapshot. For live IB fabric state, run `ibstat`, `ibnetdiscover`, `ibdiagnet` on acmt0.
>
> 本檔為一次性分析快照（Snapshot）。若需即時 IB fabric 狀態，請於 acmt0 執行 `ibstat`、`ibnetdiscover`、`ibdiagnet`。

## Hardware Configuration Overview / 硬體配置概況

### Headnode (acmt0) InfiniBand Devices / Headnode (acmt0) InfiniBand 設備

- **Device model / 設備型號**: Mellanox ConnectX-4 (MT27700)
- **PCI ID**: af:00.0
- **Subsystem / 子系統**: Hewlett Packard Enterprise
- **Firmware version / 韌體版本**: 12.25.1020
- **HCA model / HCA 型號**: MT4115 (mlx5_0)
- **Node GUID / 節點 GUID**: 0xe0071bffff7d6a2c
- **Link speed / 連接速率**: 100 Gb/sec (4X EDR)

### Device Specifications / 設備規格

- **PCIe version / PCIe 版本**: v2, x16 lanes, 8GT/s
- **Memory mapping / 記憶體映射**: 32MB prefetchable
- **Power / 功耗**: 75W
- **Supported features / 支援特性**:
  - MSIX interrupts / MSIX 中斷
  - NUMA node 1
  - PCIe privileged operations / PCIe 特權級別操作

## Network Topology Analysis / 網路拓撲分析

### InfiniBand Fabric Components / InfiniBand Fabric 組件

- **Switch / 交換機**: 1 × Mellanox MSB7700/U1
  - **Switch GUID**: 0x248a070300bc2ad0
  - **Port count / 端口數量**: 36 ports
  - **Status / 狀態**: Enhanced port 0, LID 2
  - **Model / 型號**: MF0;switch-a2b85c:MSB7700/U1

### Connected Node Statistics / 連接節點統計

Total: **22 nodes** + **1 storage node** + **1 management node**.

總計 **22 個節點** + **1 個儲存節點** + **1 個管理節點**。

#### Identified nodes (by category) / 已識別的節點（按類型分類）

**High-performance nodes (ibp18s0 series) / 高效能節點（ibp18s0 系列）**:
- acmt21, acmt22, acmt23, acmt24

**Mid-tier nodes (ibp129s0 series) / 中階節點（ibp129s0 系列）**:
- acmt04, acmt05, acmt09, acmt10, acmt11, acmt13, acmt14, acmt15

**Entry-level nodes (ibp3s0, ibp4s0, ibp130s0 series) / 入門節點（ibp3s0、ibp4s0、ibp130s0 系列）**:
- acmt01, acmt02, acmt06, acmt07, acmt08, acmt12

**GPU nodes / GPU 節點**:
- acmt20 (ibp59s0)
- acmt-gpu (HCA-1)

**Storage node / 儲存節點**:
- acmt-storage (HCA-1)

**Management node / 管理節點**:
- acmt0 (mlx5_0)

## Network Configuration Details / 網路配置詳情

### Headnode Network Interface / Headnode 網路介面

- **Interface name / 介面名稱**: ib0
- **MTU**: 2044 (network layer) / 4096 (InfiniBand layer) — 2044（網路層）/ 4096（InfiniBand 層）
- **Status / 狀態**: UP, BROADCAST, RUNNING, MULTICAST
- **IP configuration / IP 配置**: 10.0.0.10/24
- **Broadcast address / 廣播地址**: 10.0.0.255
- **Link-layer address / Link-layer 位址**: 00:00:10:93:fe:80:00:00:00:00:00:00:e0:07:1b:ff:ff:7d:6a:2c

### InfiniBand Layer Parameters / InfiniBand 層參數

- **Port state / 端口狀態**: PORT_ACTIVE (4)
- **Physical state / 物理狀態**: LinkUp
- **Link speed / 連接速率**: 100 Gb/sec (4X EDR)
- **Base LID**: 1
- **SM LID**: 1
- **LMC**: 0x00
- **Capability Mask**: 0x2651e84a

## Node InfiniBand Support Status / 節點 InfiniBand 支援狀況

### Fully Supported Nodes / 完全支援節點

1. **acmt0** (management node / 管理節點) — ConnectX-4
2. **acmt-gpu** (GPU node / GPU 節點) — MT4115

### Unsupported Nodes / 不支援節點

- **acmt01, acmt02, acmt20** — no InfiniBand devices / 無 InfiniBand 設備
- **Most r630s series nodes / 大部分 r630s 系列節點** — no InfiniBand cards installed / 未安裝 InfiniBand 卡

### Connection Test Results / 連接測試結果

- **ib0 interface / ib0 介面**: brought up normally with IP configured / 正常啟動並配置 IP
- **Connectivity test / 連接測試**: some nodes unreachable (likely a configuration issue) / 部分節點無法連通（可能是配置問題）
- **Fabric discovery / Fabric 發現**: switch and most nodes are discoverable / 能夠識別交換機和大部分節點

## Network Performance Analysis / 網路效能分析

### Theoretical Performance / 理論效能

- **Bandwidth / 頻寬**: 100 Gb/sec (EDR)
- **Latency / 延遲**: sub-microsecond
- **MTU**: 4096 bytes (Jumbo Frame supported) / 4096 bytes（支援 Jumbo Frame）

### Actual State / 實際狀態

- **Fabric integrity / Fabric 完整性**: good (22/28 nodes visible) / 良好（22/28 節點可見）
- **Switch state / 交換機狀態**: operating normally / 正常運作
- **LID assignment / LID 分配**: normal (SM assigned LID 1 to management node) / 正常（SM 分配 LID 1 給管理節點）

## Issues Identified / 問題識別

### Primary Issues / 主要問題

1. **Insufficient InfiniBand coverage / InfiniBand 覆蓋率不足**: only ~78% of nodes supported (22/28) / 僅約 78% 節點支援（22/28）
2. **Inconsistent network configuration / 網路配置不一致**: some nodes fail IP connectivity / 部分節點 IP 連接失敗
3. **Mixed device models / 設備型號混用**: different HCA models on different nodes / 不同節點使用不同 HCA 型號

### Secondary Issues / 次要問題

1. **MTU mismatch / MTU 不匹配**: network-layer MTU (2044) < IB-layer MTU (4096) / 網路層 MTU (2044) < IB 層 MTU (4096)
2. **Storage node isolation / 儲存節點隔離**: acmt-storage exists but its role is unclear / acmt-storage 存在但用途不明

## Recommended Improvements / 建議改進方案

### Short-term (1-2 weeks) / 短期改進（1-2 週）

1. **Fix network configuration / 修復網路配置**: check ib0 routing and firewall settings / 檢查 ib0 介面路由和防火牆設定
2. **Standardise MTU / 統一 MTU 設定**: raise network-layer MTU to 4096 / 將網路層 MTU 提升至 4096
3. **Re-verify connectivity / 驗證連接性**: retest IB connectivity on all visible nodes / 重新測試所有可見節點的 IB 連接

### Mid-term (1-2 months) / 中期改進（1-2 個月）

1. **Expand IB support / 擴展 IB 支援**: install InfiniBand cards on the remaining 6 nodes / 為剩餘 6 個節點安裝 InfiniBand 卡
2. **Standardise hardware / 設備標準化**: unify on Mellanox ConnectX-4 family / 統一使用 Mellanox ConnectX-4 系列
3. **Monitoring system / 監控系統**: deploy InfiniBand performance monitoring tooling / 部署 InfiniBand 效能監控工具

### Long-term (3-6 months) / 長期規劃（3-6 個月）

1. **Upgrade to HDR / 升級至 HDR**: consider upgrading to 200Gb/sec HDR / 考慮升級至 200Gb/sec HDR 技術
2. **Multipathing support / 多路徑支援**: implement SR-IOV and multipath configuration / 實施 SR-IOV 和多路徑配置
3. **RDMA optimisation / RDMA 最佳化**: tune RDMA settings for HPC applications / 針對 HPC 應用最佳化 RDMA 設定

## Cost-Benefit Analysis / 成本效益分析

### Current Investment Return / 當前投資回報

- **Deployed cost / 已部署成本**: ~$50,000 (estimated) / 約 $50,000（估算）
- **Performance gain / 效能提升**: 5–10× bandwidth improvement vs Ethernet / 相比 Ethernet 5-10 倍頻寬提升
- **Application coverage / 應用覆蓋**: primarily MPI jobs and inter-GPU-node communication / 主要用於 MPI 作業和 GPU 節點間通信

### Expansion Investment Estimate / 擴展投資估算

- **IB cards for remaining nodes / 剩餘節點 IB 卡**: ~$15,000 (6 nodes × $2,500) / 約 $15,000（6 節點 × $2,500）
- **HDR switch upgrade / 升級 HDR 交換機**: ~$30,000 / 約 $30,000
- **Total investment needed / 總投資需求**: ~$45,000 / 約 $45,000

## Conclusion / 結論

ACMT cluster's InfiniBand implementation is in a **partial deployment state** — solid infrastructure but still needs work. Key strengths:

ACMT 集群的 InfiniBand 實現處於**部分部署狀態**，具備良好的基礎設施但需要進一步完善。主要優勢包括：

- **High performance / 高效能**: 100Gb/sec EDR links
- **Stability / 穩定性**: switch and core nodes run stably / 交換機和核心節點運行穩定
- **Scalability / 擴展性**: 36-port switch supports future expansion / 36 端口交換機支援未來擴展

Key challenges / 主要挑戰：

- **Insufficient coverage / 覆蓋率不足**: 22% of nodes lack IB support / 22% 節點缺少 IB 支援
- **Inconsistent configuration / 配置不一致**: network-layer config needs tuning / 網路層配置需要最佳化
- **Missing monitoring / 監控缺失**: lack of systematic monitoring tooling / 缺乏系統化監控工具

**Recommended priorities / 建議優先級**:
1. Fix existing configuration issues (high priority) / 修復現有配置問題（高優先級）
2. Expand IB support to all nodes (medium priority) / 擴展 IB 支援至所有節點（中優先級）
3. Implement monitoring and optimisation (low priority) / 實施監控和最佳化系統（低優先級）

---

**Report version / 報告版本**: 1.0
**Technical review / 技術審核**: System engineer / 系統工程師
**Next review / 下次審查**: Frozen — no further reviews (see SUPERSEDED notice at top) / 已凍結 — 不再審查（見最上方 SUPERSEDED 通知）
