---
title: ACMT HPC Network Topology | ACMT HPC 網路拓樸
type: Reference
last_updated: 2026-05-22
source_of_truth: This file (physical topology, IP mapping); `/etc/netplan/` on each host (live config)
---

# ACMT HPC Cluster — Network Topology / ACMT HPC 集群 — 網路拓樸

## 1. Physical Topology Overview / 實體拓樸概觀

The diagram below shows how the headnode, compute nodes, storage, and GPU nodes connect through the two MikroTik management switches and the Mellanox InfiniBand fabric.

下圖呈現 headnode、計算節點、儲存節點與 GPU 節點如何透過兩台 MikroTik 管理交換器與 Mellanox InfiniBand fabric 串接。

```
                    ┌──────────────────────┐
                    │   Academic Network    │  (1Gbps+, upstream)
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    │  MikroTik CRS #1     │  ← Gateway: 192.168.1.1
                    │  (Management Switch) │     MAC: d4:01:c3:ec:5a:0d
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    │  MikroTik CRS #2     │  (Stack / cascaded with #1)
                    │  (Management Switch) │
                    └──┬───┬───┬───┬───┬──┘
         ┌─────────────┘   │   │   │   └──────────────┐
         ▼                 ▼   ▼   ▼                  ▼
   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │  acmt0   │   │ acmt01-27│   │acmt-gpu  │   │acmt-stg  │
   │ (head)   │   │(compute) │   │(GPU)     │   │(storage) │
   │ .10      │   │.12-.39   │   │.32       │   │.11       │
   └─────┬────┘   └──────────┘   └──────────┘   └─────┬────┘
         │                                             │
         └──────────┬──────────────────────────────────┘
                    │
         ┌──────────┴───────────┐
         │  Mellanox MSB7700    │  InfiniBand Fabric
         │  36-port, 100Gb EDR │  10.0.0.0/24
         └──────────────────────┘
```

---

## 2. Network Segments / 網段配置

| Network / 網段 | Subnet / 子網 | Interface / 介面 | Speed / 速度 | Purpose / 用途 |
|---------|--------|-----------|-------|---------|
| Management / 管理 | 192.168.1.0/24 | eno1 | 1Gbps | SSH, NFS, LDAP, Slurm, monitoring / SSH、NFS、LDAP、Slurm、監控 |
| InfiniBand | 10.0.0.0/24 | ib0 | 100Gbps | MPI/RDMA, high-speed IPC / MPI/RDMA、高速 IPC |
| Docker | 172.17.0.0/16 | docker0 | virtual | Container networking (acmt0 only) / 容器網路（僅 acmt0） |

---

## 3. Management Network (192.168.1.0/24) / 管理網段

### 3.1 Switches / 交換器

| Switch / 交換器 | Role / 角色 | Model / 型號 | Ports / 連接埠 | Uplink / 上聯 |
|--------|------|-------|-------|--------|
| MikroTik CRS #1 | Gateway + Core / 閘道 + 核心 | CRS3xx/5xx | 48+ | Upstream to academic network / 上聯學術網路 |
| MikroTik CRS #2 | Access / 接入 | CRS3xx/5xx | 48+ | Cascaded to CRS #1 / 串接至 CRS #1 |

### 3.2 Node IP Assignments / 節點 IP 配置

> **Note / 註記**: Node operational state lives in [STATUS.md §1](STATUS.md) (live scan). The Status column is removed from this table to avoid drift; this file tracks only the static IP/MAC mapping.
>
> **註記**: 節點即時運行狀態見 [STATUS.md §1](STATUS.md)（live scan）。此處刻意不放 Status 欄位以避免漂移；本檔僅維護靜態 IP/MAC 對應。

| Hostname / 主機名 | IP | MAC | Switch port / 交換器埠 |
|----------|----|-----|-------------|
| **acmt0** (head) | 192.168.1.10 | — | TBD |
| **acmt-storage** | 192.168.1.11 | 38:63:bb:3b:c5:28 | TBD |
| **acmt-gpu** | 192.168.1.32 | 74:56:3c:07:43:85 | TBD |
| acmt01 | 192.168.1.12 | c8:1f:66:d8:62:e3 | TBD |
| acmt02 | 192.168.1.13 | c8:1f:66:f0:ea:4f | TBD |
| acmt03 | 192.168.1.14 | — | TBD |
| acmt04 | 192.168.1.15 | ec:f4:bb:de:ed:e0 | TBD |
| acmt05 | 192.168.1.16 | ec:f4:bb:df:9a:d4 | TBD |
| acmt06 | 192.168.1.17 | ec:f4:bb:e8:2b:64 | TBD |
| acmt07 | 192.168.1.18 | 18:66:da:e6:bb:20 | TBD |
| acmt08 | 192.168.1.19 | b8:2a:72:e1:13:2e | TBD |
| acmt09 | 192.168.1.20 | f4:8e:38:c3:19:e4 | TBD |
| acmt10 | 192.168.1.21 | f4:8e:38:c3:13:44 | TBD |
| acmt11 | 192.168.1.22 | f4:8e:38:c3:0a:c8 | TBD |
| acmt12 | 192.168.1.23 | — | TBD |
| acmt13 | 192.168.1.24 | f4:8e:38:c3:17:6c | TBD |
| acmt14 | 192.168.1.25 | — | TBD |
| acmt15 | 192.168.1.26 | f4:8e:38:c3:0a:84 | TBD |
| acmt16 | 192.168.1.27 | — | TBD |
| acmt17 | 192.168.1.28 | — | TBD |
| acmt18 | 192.168.1.29 | 98:f2:b3:0b:5a:1c | TBD |
| acmt19 | 192.168.1.30 | 98:f2:b3:0b:58:84 | TBD |
| acmt20 | 192.168.1.31 | 20:04:0f:f1:2f:ac | TBD |
| acmt21 | 192.168.1.33 | 80:30:e0:39:9d:28 | TBD |
| acmt22 | 192.168.1.34 | 20:67:7c:ef:ce:5c | TBD |
| acmt23 | 192.168.1.35 | 20:67:7c:e3:fe:dc | TBD |
| acmt24 | 192.168.1.36 | 20:67:7c:f1:1a:44 | TBD |
| acmt25 | 192.168.1.37 | 20:67:7c:e3:81:80 | TBD |
| acmt26 | 192.168.1.38 | — | TBD |
| acmt27 | 192.168.1.39 | 20:67:7c:e0:1c:10 | TBD |

> **Note / 註記**: Switch port columns are TBD — fill in after physical inspection. Some entries have no MAC in ARP table (offline/unreachable at last scan; see STATUS.md §1).
>
> **註記**: Switch port 欄位目前為 TBD，需要實機巡檢後補齊。部分節點在 ARP 表內無 MAC（最近一次掃描時 offline 或無法到達；見 STATUS.md §1）。

---

## 4. InfiniBand Fabric (10.0.0.0/24) / InfiniBand 結構

### 4.1 Switch / 交換器

| Model / 型號 | Ports / 連接埠 | Firmware / 韌體 | GUID | Speed / 速度 |
|-------|-------|----------|------|-------|
| Mellanox MSB7700/U1 | 36 | — | 0x248a070300bc2ad0 | 100Gb EDR |

### 4.2 Node-to-Switch Port Mapping / 節點對交換器埠對應

| Switch port / 交換器埠 | Node / 節點 | IB device / IB 裝置 | LID | Speed / 速度 | Hostname / 主機名 |
|-------------|------|-----------|-----|-------|----------|
| 1 | acmt0 | mlx5_0 | 1 | 4x EDR | Headnode |
| 2 | acmt-storage | ConnectX-4 | 3 | 4x EDR | Storage |
| 4 | acmt04 | ibp129s0 | 5 | 4x EDR | r630a |
| 5 | acmt05 | ibp129s0 | 6 | 4x EDR | r630b |
| 6 | acmt06 | ibp3s0 | 7 | 4x EDR | r630b |
| 7 | acmt07 | ibp4s0 | 8 | 4x EDR | r630c |
| 8 | acmt08 | ibp4s0 | 9 | 4x EDR | r630l (DOWN) |
| 9 | acmt20 | ibp216s0 | 10 | 4x EDR | r740 GPU |
| 10 | acmt-gpu | ConnectX-4 | 11 | 4x EDR | GPU node |
| 11 | acmt01 | ibp4s0 | 12 | 4x EDR | r620 |
| 12 | acmt02 | ibp4s0 | 13 | 4x EDR | r620 |
| 13 | **UNKNOWN** | ConnectX-4 | 14 | **4x SDR** | see §4.3 / 見 §4.3 |
| 14 | acmt22 | ibp18s0 | 15 | 4x EDR | dl360 |
| 15 | acmt23 | ibp18s0 | 16 | 4x EDR | dl360 |
| 16 | acmt21 | ibp18s0 | 17 | 4x EDR | dl360 |
| 17 | acmt09 | ibp129s0 | 18 | 4x EDR | r630s |
| 18 | acmt11 | ibp129s0 | 20 | 4x EDR | r630s |
| 19 | acmt10 | ibp129s0 | 19 | 4x EDR | r630s |
| 20 | acmt13 | ibp129s0 | 21 | 4x EDR | r630s |
| 22 | acmt15 | ibp129s0 | 23 | 4x EDR | r630s (DRAINED) |
| 23 | acmt24 | ibp18s0 | 24 | 4x EDR | dl360 |
| 3, 21, 24-36 | **unused / 未使用** | — | — | — | — |

### 4.3 Unknown Node on Port 13 / 第 13 埠的未知節點

Switch port 13 has a ConnectX-4 connected at **4x SDR** (not EDR), suggesting a cabling issue or an older IB card. Likely candidates are listed below.

交換器第 13 埠連接的 ConnectX-4 速度為 **4x SDR**（非 EDR），推測為線材問題或較舊的 IB 卡。可能候選節點列於下表。

| Candidate / 候選節點 | IP | Status / 狀態 | Reason / 推測理由 |
|-----------|----|--------|--------|
| acmt03 | 192.168.1.14 | DOWN | r630m, 154GB RAM |
| acmt12 | 192.168.1.23 | DOWN | r630m, 154GB RAM |

Both candidate nodes are offline, so the IB link on port 13 cannot be confirmed remotely.

兩個候選節點皆 offline，故無法遠端確認第 13 埠的 IB link 對應節點。

### 4.4 Nodes NOT on InfiniBand / 不在 InfiniBand 上的節點

| Node / 節點 | Reason / 原因 |
|------|--------|
| acmt03, acmt12 | Offline (possibly on port 13) / 離線（可能對應第 13 埠） |
| acmt14 | Drained, not detected on fabric / 已 drain，fabric 上偵測不到 |
| acmt16, acmt17 | Offline (Apollo nodes, network down) / 離線（Apollo 節點，網路 down） |
| acmt18, acmt19 | Online but not on IB fabric / 上線但未接 IB fabric |
| acmt25 | Drained, not detected on fabric / 已 drain，fabric 上偵測不到 |
| acmt26 | Offline / 離線 |
| acmt27 | Online but not on IB fabric / 上線但未接 IB fabric |

---

## 5. Routing & Gateway / 路由與閘道

### 5.1 Default Route / 預設路由

```
default via 192.168.1.1 dev eno1    # MikroTik CRS #1 → Academic Network
```

### 5.2 Direct Routes / 直連路由

```
192.168.1.0/24   dev eno1    # Management LAN
10.0.0.0/24      dev ib0     # InfiniBand fabric
172.17.0.0/16    dev docker0 # Docker bridge (acmt0 only)
```

### 5.3 GPU Node NAT (acmt20) / GPU 節點 NAT

acmt20 (192.168.1.31) has nftables masquerade for Docker bridge traffic. iptables FORWARD rules permit traffic to/from 192.168.1.31 only.

acmt20（192.168.1.31）使用 nftables masquerade 處理 Docker bridge 流量。iptables FORWARD 規則僅允許進出 192.168.1.31 的流量。

---

## 6. Services & Ports / 服務與連接埠

| Service / 服務 | Port(s) / 連接埠 | Host / 主機 | Network / 網段 |
|---------|---------|------|---------|
| SSH | 22/TCP | All nodes / 所有節點 | Management |
| LDAP | 389/TCP | acmt0 | Management |
| Slurmctld | 6817/TCP | acmt0 | Management |
| Slurmd | 6818/TCP | Compute nodes / 計算節點 | Management |
| SlurmDBD | 6819/TCP | acmt0 | Management |
| MySQL | 3306/TCP | acmt0 (localhost) | Management |
| NFS | 111,2049/TCP,UDP | acmt-storage | Management |
| Prometheus | 9090/TCP | acmt0 | Management |
| Grafana | 3000/TCP | acmt0 | Management |
| node_exporter | 9100/TCP | All nodes / 所有節點 | Management |
| slurm_exporter | 8080/TCP | acmt0 | Management |
| Chrony (NTP) | 123/UDP | acmt0 | Management + External |
| OpenSM | — | acmt0 | InfiniBand |

---

## 7. Rack Layout / 機櫃配置

Two 42U racks. The diagrams below are OCR-derived from the physical photos `server.png` / `server2.png`.

兩台 42U 機櫃。下方配置圖由實體照片 `server.png` / `server2.png` OCR 辨識而得。

### Rack 1 — Main Rack (`server.png`) / 主機櫃

```
 U Position | Equipment
------------|-----------------------------------------------------
      ↑     | (top of rack)
     42     | Power Supply / PDU
     41     |
     40     | [MikroTik CRS #1]   — Ethernet Switch
     39     |
     38     | [Mellanox MSB7700]  — InfiniBand Switch (36-port)
     37     |
     36     | [KVM Switch]
     35     |
     34     | [Dell R740]         — Head Node (acmt0)
     33     |
     32     | [HP DL380 Gen9]     — Storage Node (acmt-storage)
     31     |
     30-29  | [Dell R620] x2      — acmt01, acmt02 (r620 partition)
     28-27  |
     26-22  | [Dell R630] x~7     — acmt04~15 (r630a/b/c/l/m/s)
     21-18  |
     17-14  | [Apollo 2000] x4    — acmt16~19 (apollo partition)
     13-11  |
     10-9   | [Dell R740]         — acmt20 (r740, GPU node)
     8-7    |
     6-4    | [Gigabyte]          — acmt-gpu (gpu partition)
     3-1    |
      ↓     | (bottom of rack)
```

### Rack 2 — Secondary Rack (`server2.png`) / 副機櫃

```
 U Position | Equipment
------------|-----------------------------------------------------
      ↑     | (top of rack)
     42     | Power Supply / PDU
     41     |
     40     | [MikroTik CRS #2]   — Ethernet Switch
     39     |
     ...    | (empty space)
     20-8   | [HP DL360] x7       — acmt21~27 (dl360/dl360s partitions)
     7-1    |
      ↓     | (bottom of rack)
```

### Equipment Summary / 設備總覽

| Type / 類型 | Model / 型號 | Count / 數量 | Rack / 機櫃 | U space / U 空間 |
|------|-------|-------|------|---------|
| Ethernet Switch | MikroTik CRS | 2 | Rack1 (top), Rack2 (top) | 1U each |
| InfiniBand Switch | Mellanox MSB7700 | 1 | Rack1 | 1U |
| KVM Switch | — | 1 | Rack1 | 1U |
| Head Node | Dell R740 | 1 | Rack1 | 1U |
| Storage Node | HP DL380 Gen9 | 1 | Rack1 | 2U |
| Compute (r620) | Dell R620 | 2 | Rack1 | 2U |
| Compute (r630) | Dell R630 | ~7 | Rack1 | ~7U |
| Compute (apollo) | Apollo 2000 | 4 | Rack1 | 4U |
| GPU Node (r740) | Dell R740 | 1 | Rack1 | 2U |
| GPU Node (gigabyte) | Gigabyte | 1 | Rack1 | 2U |
| Compute (dl360) | HP DL360 | 7 | Rack2 | ~14U |

---

## 8. Notes & Action Items / 備註與待辦事項

- [ ] Fill in switch port mapping (confirm which MikroTik CRS port each node connects to) / 填寫交換器 port mapping（確認每個節點接 MikroTik CRS 哪個 port）
- [ ] Confirm whether IB switch ports 3, 21, 24-36 are empty / 填寫 IB switch 剩餘 port 3, 21, 24-36 是否為空
- [ ] Identify the unknown node on IB port 13 (acmt03 or acmt12?) / 確認 IB port 13 的未知節點（acmt03 或 acmt12？）
- [ ] Confirm node IPMI/BMC IP and segment / 確認節點 IPMI/BMC IP 和網段
- [ ] Integrate physical rack-layout diagram / 整合機櫃佈局圖
- [ ] Confirm the stack/cascade method between the two MikroTik CRS units / 確認兩台 MikroTik CRS 之間的串接方式（stack/cascade）
- [ ] Confirm upstream academic-network bandwidth (1Gbps or more?) / 確認上游學術網路頻寬（1Gbps 或更高？）
