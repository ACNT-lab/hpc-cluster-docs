---
title: Slurm Monitor (TUI) — Tool Documentation
type: Reference (tool)
last_updated: 2026-05-22
source_of_truth: This file (feature overview); `/root/slurm-monitor/` on acmt0 (source code)
---

# Slurm Monitor

TUI 工具監控 Slurm/HPC cluster 狀態，使用 Go + Bubble Tea 實作。命令列等價指令（`sinfo`、`squeue`、`scontrol show node` 等）見 [tools-commands.md](tools-commands.md)。

## 功能

### Dashboard 摘要
- **Cluster 總覽**：總節點數、在線狀態、GPU 節點統計
- **資源分配**：CPU 分配率、空閒 CPU 比例
- **資源使用率**：平均 CPU、記憶體、磁碟使用率（帶顏色告警）
- **網路與連線**：總 SSH 連線數、平均延遲
- **作業摘要**：總作業數、運行中、排隊中
- **Controller 狀態**：Slurmctld 運行狀態

### Slurm 層監控
- Partitions 監控 (idle/alloc/down/drain)
- Nodes 狀態（帶顏色編碼）
- Jobs 管理 (pending/running)
- Controller 狀態 (slurmctld + scheduler)

### Node Telemetry 層監控
- **CPU 使用率**：實時 CPU 使用百分比，高使用率（>80%）顯示紅色警告
- **系統負載**：load average (1/5/15 min)
- **記憶體使用率**：記憶體使用百分比，高使用率（>90%）顯示紅色警告
- **磁碟使用率**：磁碟空間使用，高使用率（>95%）顯示紅色警告
- **GPU 檢測**：自動檢測 GPU 節點並顯示 GPU 數量
- **網路連線數**：SSH 連線數量
- **SSH 連線狀態**：連線延遲，高延遲（>500ms）顯示紅色
- **系統運行時間**：運行時間
- **進程數量**：系統進程總數

### 視覺化功能
- **顏色編碼**：綠色（正常）、黃色（警告）、紅色（危險）
- **狀態高亮**：節點狀態顏色區分（idle=綠色、down=紅色、mixed=青色等）
- **實時數據**：每 3 秒自動刷新
- **狀態欄**：顯示在線節點數、平均延遲、最後刷新時間

## 安裝

```bash
cd slurm-monitor
go build ./cmd/slurm-monitor
```

## 使用

### 基本使用（默認自動發現所有 acmt 節點）
```bash
./slurm-monitor
```

### 自定義節點模式
```bash
./slurm-monitor -pattern "node[0-9]+"
```

使用正則表達式匹配 `/etc/hosts` 中的節點名稱，自動發現並添加到監控。

支持的範例模式：
- `acmt.*` - 匹配所有以 acmt 開頭的節點（默認），包含 acmt0, acmt01, acmt-gpu 等
- `acmt[0-9]+` - 只匹配數字結尾的 acmt 節點
- `node[0-9]{2}` - 匹配兩位數的 node00-node99
- `compute-[a-z]+` - 匹配 compute-alpha, compute-beta 等

自動發現會跳過本地迴路地址（127.0.0.1, ::1）。

## SSH 連線

程式使用系統默認的 SSH 配置進行連線：
- 預設使用 `~/.ssh/id_rsa` 作為私鑰
- 支持通過 `SSH_AUTH_SOCK` 使用 SSH agent
- 連線命令：`ssh acmt[0-9]`

確保您可以通過 SSH 連接到集群節點：
```bash
ssh acmt0
ssh acmt01
# etc.
```

## 操作

- `1-4`：快速切換標籤頁（Dashboard/Nodes/Jobs/Controller）
- `Tab` / `→` / `←`：切換標籤頁
- `F1` / `h`：顯示/隱藏鍵盤快捷鍵幫助面板
- `q` / `Ctrl+C`：退出

## 🎨 UI 增強

### 視覺效果
- **進度條**：資源使用率視覺化，自動顏色變化（綠→黃→紅）
- **圖標系統**：使用 Emoji 圖標標識不同類型資源（📊、✅、❌、🎮、🖥️、💻、🧠、💾、📀、🔌、📋、▶️、⏳）
- **方框佈局**：圓角方框（┌─┐）分隔不同信息面板
- **幫助面板**：按 F1 顯示/隱藏鍵盤快捷鍵說明
- **狀態欄**：實時顯示在線節點、平均延遲、最後刷新時間

### 顏色系統
- **綠色**（#50FA7B）：正常、在線、成功
- **黃色**（#FFAF00）：警告、中等使用率
- **紅色**（#FF5F56）：危險、高使用率、離線
- **青色**（#8BE9FD）：信息、空閒狀態
- **紫色**（#7D56F4）：標題、頭部
- **灰色**（#6272A4）：背景、空閒狀態

### 快捷鍵面板
按 `F1` 或 `h` 鍵顯示/隱藏鍵盤快捷鍵幫助：

```
┌─────────────────────────────┐
│   Keyboard Shortcuts         │
│                             │
│ 1-4 Switch tabs...           │
│ ←/→/Tab Switch tabs          │
│ F1 / h Toggle this help     │
│ q / Ctrl+C Quit              │
│                             │
│ Press F1 or h to close      │
└─────────────────────────────┘
```

## 標籤頁說明

### Dashboard（總覽）
顯示集群整體狀態摘要，包括：
- 節點在線/離線統計（帶圖標）
- GPU 節點數量和 GPU 總數
- CPU 資源分配情況（帶進度條）
- 平均資源使用率（CPU、記憶體、磁碟）帶可視化進度條
- 網路連線和延遲統計
- 作業運行狀態
- Controller 運行狀態

**視覺元素**：
- 圓角方框分隔各個面板
- 圖標標識不同資源類型（📊、✅、❌、🎮、🖥️、💻、🧠、💾、📀、🔌、📋、▶️、⏳）
- 資源使用進度條，顏色變化（綠色→黃色→紅色）

### Nodes
顯示所有節點的詳細狀態：
- 節點名稱和 Slurm 狀態
- CPU 使用率（顏色告警）
- 系統負載
- 記憶體使用率（顏色告警）
- 磁碟使用率（顏色告警）
- GPU 狀態（如果有）
- SSH 延遲（顏色告警）
- 系統運行時間
- 進程數量

### Jobs
顯示所有作業狀態

### Controller
顯示 Slurm controller 狀態和調度器統計

## Refresh 策略


- 快速路徑 (3 秒): `sinfo`, `squeue`
- 慢速路徑 (15 秒): `sdiag`, `systemctl`
- Telemetry (30 秒): SSH 採集
