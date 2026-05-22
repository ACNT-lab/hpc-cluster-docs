---
title: Slurm Monitor (TUI) — Tool Documentation | Slurm Monitor (TUI) — 工具文件
type: Reference (tool)
last_updated: 2026-05-22
source_of_truth: This file (feature overview); `/root/slurm-monitor/` on acmt0 (source code)
---

# Slurm Monitor

A TUI tool for monitoring Slurm/HPC cluster state, implemented in Go with Bubble Tea. Equivalent shell commands (`sinfo`, `squeue`, `scontrol show node`, etc.) are documented in [tools-commands.md](tools-commands.md).

TUI 工具監控 Slurm/HPC cluster 狀態，使用 Go + Bubble Tea 實作。命令列等價指令（`sinfo`、`squeue`、`scontrol show node` 等）見 [tools-commands.md](tools-commands.md)。

## Features / 功能

### Dashboard Summary / Dashboard 摘要

- **Cluster overview / Cluster 總覽**: total node count, online status, GPU node stats / 總節點數、在線狀態、GPU 節點統計
- **Resource allocation / 資源分配**: CPU allocation rate, idle CPU ratio / CPU 分配率、空閒 CPU 比例
- **Resource utilization / 資源使用率**: average CPU, memory, disk usage with color alerts / 平均 CPU、記憶體、磁碟使用率（帶顏色告警）
- **Network and connectivity / 網路與連線**: total SSH connections, average latency / 總 SSH 連線數、平均延遲
- **Job summary / 作業摘要**: total jobs, running, pending / 總作業數、運行中、排隊中
- **Controller status / Controller 狀態**: slurmctld run state / Slurmctld 運行狀態

### Slurm-Layer Monitoring / Slurm 層監控

- Partitions monitoring (idle/alloc/down/drain) / Partitions 監控 (idle/alloc/down/drain)
- Node states with color coding / Nodes 狀態（帶顏色編碼）
- Job management (pending/running) / Jobs 管理 (pending/running)
- Controller state (slurmctld + scheduler) / Controller 狀態 (slurmctld + scheduler)

### Node Telemetry Monitoring / Node Telemetry 層監控

- **CPU utilization / CPU 使用率**: live CPU percentage; >80% shows red warning / 實時 CPU 使用百分比，高使用率（>80%）顯示紅色警告
- **System load / 系統負載**: load average (1/5/15 min)
- **Memory usage / 記憶體使用率**: memory percentage; >90% shows red warning / 記憶體使用百分比，高使用率（>90%）顯示紅色警告
- **Disk usage / 磁碟使用率**: disk-space usage; >95% shows red warning / 磁碟空間使用，高使用率（>95%）顯示紅色警告
- **GPU detection / GPU 檢測**: auto-detects GPU nodes and shows count / 自動檢測 GPU 節點並顯示 GPU 數量
- **Network connections / 網路連線數**: SSH connection count / SSH 連線數量
- **SSH state / SSH 連線狀態**: connection latency; >500ms shows red / 連線延遲，高延遲（>500ms）顯示紅色
- **System uptime / 系統運行時間**: uptime / 運行時間
- **Process count / 進程數量**: total system processes / 系統進程總數

### Visualization / 視覺化功能

- **Color coding / 顏色編碼**: green (normal), yellow (warning), red (danger) / 綠色（正常）、黃色（警告）、紅色（危險）
- **State highlights / 狀態高亮**: node-state colors (idle=green, down=red, mixed=cyan, etc.) / 節點狀態顏色區分（idle=綠色、down=紅色、mixed=青色等）
- **Live data / 實時數據**: auto-refresh every 3 seconds / 每 3 秒自動刷新
- **Status bar / 狀態欄**: online node count, average latency, last refresh time / 顯示在線節點數、平均延遲、最後刷新時間

## Installation / 安裝

```bash
cd slurm-monitor
go build ./cmd/slurm-monitor
```

## Usage / 使用

### Default — auto-discover all `acmt` nodes / 基本使用（默認自動發現所有 acmt 節點）

```bash
./slurm-monitor
```

### Custom node pattern / 自定義節點模式

```bash
./slurm-monitor -pattern "node[0-9]+"
```

Use a regular expression to match node names from `/etc/hosts`; matches are added to the monitor automatically.

使用正則表達式匹配 `/etc/hosts` 中的節點名稱，自動發現並添加到監控。

Supported example patterns / 支持的範例模式:

- `acmt.*` — matches all nodes starting with `acmt` (default): `acmt0`, `acmt01`, `acmt-gpu`, etc. / 匹配所有以 acmt 開頭的節點（默認），包含 acmt0、acmt01、acmt-gpu 等
- `acmt[0-9]+` — only `acmt` nodes ending in digits / 只匹配數字結尾的 acmt 節點
- `node[0-9]{2}` — two-digit `node00`–`node99` / 匹配兩位數的 node00-node99
- `compute-[a-z]+` — `compute-alpha`, `compute-beta`, etc. / 匹配 compute-alpha, compute-beta 等

Auto-discovery skips loopback addresses (127.0.0.1, ::1).

自動發現會跳過本地迴路地址（127.0.0.1, ::1）。

## SSH Connectivity / SSH 連線

The program uses the system's default SSH config:

程式使用系統默認的 SSH 配置進行連線：

- Default private key: `~/.ssh/id_rsa` / 預設使用 `~/.ssh/id_rsa` 作為私鑰
- SSH agent supported via `SSH_AUTH_SOCK` / 支持通過 `SSH_AUTH_SOCK` 使用 SSH agent
- Connection command: `ssh acmt[0-9]` / 連線命令：`ssh acmt[0-9]`

Make sure SSH to the cluster nodes works first:

確保您可以通過 SSH 連接到集群節點：

```bash
ssh acmt0
ssh acmt01
# etc.
```

## Operations / 操作

- `1-4`: quick-switch tabs (Dashboard / Nodes / Jobs / Controller) / 快速切換標籤頁
- `Tab` / `→` / `←`: cycle tabs / 切換標籤頁
- `F1` / `h`: toggle keyboard shortcut help panel / 顯示/隱藏鍵盤快捷鍵幫助面板
- `q` / `Ctrl+C`: quit / 退出

## UI Enhancements / UI 增強

### Visual effects / 視覺效果

- **Progress bars / 進度條**: resource utilization visualized with auto color shift (green → yellow → red) / 資源使用率視覺化，自動顏色變化（綠→黃→紅）
- **Icon system / 圖標系統**: emoji icons identify resource types (📊、✅、❌、🎮、🖥️、💻、🧠、💾、📀、🔌、📋、▶️、⏳) / 使用 Emoji 圖標標識不同類型資源
- **Box layout / 方框佈局**: rounded boxes (┌─┐) separate information panels / 圓角方框（┌─┐）分隔不同信息面板
- **Help panel / 幫助面板**: press F1 to toggle keyboard shortcut help / 按 F1 顯示/隱藏鍵盤快捷鍵說明
- **Status bar / 狀態欄**: live online node count, average latency, last refresh / 實時顯示在線節點、平均延遲、最後刷新時間

### Color palette / 顏色系統

- **Green (#50FA7B)**: normal, online, success / 綠色：正常、在線、成功
- **Yellow (#FFAF00)**: warning, moderate usage / 黃色：警告、中等使用率
- **Red (#FF5F56)**: danger, high usage, offline / 紅色：危險、高使用率、離線
- **Cyan (#8BE9FD)**: info, idle state / 青色：信息、空閒狀態
- **Purple (#7D56F4)**: titles, headers / 紫色：標題、頭部
- **Gray (#6272A4)**: background, idle / 灰色：背景、空閒狀態

### Keyboard Shortcuts / 快捷鍵面板

Press `F1` or `h` to toggle the keyboard shortcut help panel.

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

## Tabs / 標籤頁說明

### Dashboard

Shows the overall cluster summary, including / 顯示集群整體狀態摘要，包括：

- Node online/offline stats (with icons) / 節點在線/離線統計（帶圖標）
- GPU node count and total GPU count / GPU 節點數量和 GPU 總數
- CPU allocation with progress bar / CPU 資源分配情況（帶進度條）
- Average resource utilization (CPU, memory, disk) with progress bars / 平均資源使用率（CPU、記憶體、磁碟）帶可視化進度條
- Network connections and latency stats / 網路連線和延遲統計
- Job run state / 作業運行狀態
- Controller run state / Controller 運行狀態

**Visual elements / 視覺元素**:

- Rounded boxes separating panels / 圓角方框分隔各個面板
- Icons identifying resource types (📊、✅、❌、🎮、🖥️、💻、🧠、💾、📀、🔌、📋、▶️、⏳) / 圖標標識不同資源類型
- Resource-usage progress bars with color transitions (green → yellow → red) / 資源使用進度條，顏色變化（綠色→黃色→紅色）

### Nodes

Detailed state for every node / 顯示所有節點的詳細狀態：

- Node name and Slurm state / 節點名稱和 Slurm 狀態
- CPU usage (color alert) / CPU 使用率（顏色告警）
- System load / 系統負載
- Memory usage (color alert) / 記憶體使用率（顏色告警）
- Disk usage (color alert) / 磁碟使用率（顏色告警）
- GPU state if present / GPU 狀態（如果有）
- SSH latency (color alert) / SSH 延遲（顏色告警）
- System uptime / 系統運行時間
- Process count / 進程數量

### Jobs

Shows the state of every job / 顯示所有作業狀態。

### Controller

Shows Slurm controller state and scheduler statistics / 顯示 Slurm controller 狀態和調度器統計。

## Refresh Strategy / Refresh 策略

- Fast path (3 s) / 快速路徑 (3 秒): `sinfo`, `squeue`
- Slow path (15 s) / 慢速路徑 (15 秒): `sdiag`, `systemctl`
- Telemetry (30 s) / Telemetry (30 秒): SSH collection / SSH 採集
