---
title: ACMT HPC Cluster — Tools & Commands Reference | ACMT HPC 集群 — 工具與命令參考
type: Reference
last_updated: 2026-05-22
source_of_truth: This file (command reference); each tool's own `--help`
---

# ACMT HPC Cluster — Tools & Commands Reference / ACMT HPC 集群 — 工具與命令參考

## Naming Conventions / 命名規範

| Field / 欄位 | Description / 說明 |
|------|------|
| Headnode / 管理節點 | `acmt0` (192.168.1.10) |
| Storage node / 儲存節點 | `acmt-storage` (192.168.1.11) |
| Compute nodes / 計算節點 | `acmt01`–`acmt27` |
| GPU nodes / GPU 節點 | `acmt-gpu` (192.168.1.32), `acmt20` (192.168.1.31) |
| NFS mounts / NFS 掛載 | `192.168.1.11:/home` → `/home`, `192.168.1.11:/opt` → `/opt` |

**All operations must be performed on the headnode `acmt0` unless otherwise stated.**

**所有操作須在管理節點 acmt0 上執行，除非另有說明。**

---

## 1. Slurm Commands / Slurm 命令組

### 1.1 Partition State — `sinfo` / 查看分區狀態 — `sinfo`

Common variants for inspecting partition and node availability.

查看分區與節點可用狀態的常用變體。

```bash
# All partitions summary / 所有分區摘要
sinfo

# Detailed output (full node list) / 詳細輸出 (完整節點列表)
sinfo -N -l

# Specific partition / 特定分區
sinfo -p r630s -N -l
sinfo -p gpu
sinfo -p dl360

# Custom format / 自訂格式
sinfo -o "%n %t %c %m %d %l"
# %n=hostname, %t=state, %c=CPUs, %m=memory, %d=disk, %l=load

# JSON-friendly output (for AI parsing) / JSON 輸出 (AI 解析用)
sinfo -o "%n|%T|%e|%m|%c|%a|%l|%d" --noheader
```

**Expected output example / 預期輸出範例:**
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
r630s*       up 14-00:00:0      5   idle acmt[09-11,13]
r630s*       up 14-00:00:0      2  drain acmt[14-15]
dl360        up 14-00:00:0      4  alloc acmt[21-24]
dl360        up 14-00:00:0      2   idle acmt[25]
```

**Error handling / 錯誤處理:**
- `sinfo: error: ...` — slurmctld may not be running / Slurmctld 可能未執行
- First check `systemctl status slurmctld` / 先檢查 `systemctl status slurmctld`

---

### 1.2 Node Details — `scontrol show node` / 查看節點詳情 — `scontrol show node`

Inspect a single node or all nodes for state, CPU/memory, and partition assignment.

檢視單一節點或所有節點的狀態、CPU/記憶體、所屬分區。

```bash
# Single node / 單一節點
scontrol show node acmt01

# All nodes / 所有節點
scontrol show nodes

# Nodes in a specific partition / 特定分區節點
scontrol show nodes | grep -A 20 "PartitionName=r630s"

# Only selected fields / 只看某欄位
scontrol show node acmt01 | grep -E "NodeName|State|CPUs|RealMemory|AllocMem"
```

**Expected output (key fields) / 預期輸出 (關鍵欄位):**
```
NodeName=acmt01 Arch=x86_64 CoresPerSocket=8
  CPUAlloc=0 CPUTot=16 CPULoad=0.12
  RealMemory=209490 AllocMem=0 FreeMem=203456
  State=IDLE ThreadsPerCore=1
  PartitionName=r620
```

**Error handling / 錯誤處理:**
- `Node acmtXX not found` — node not defined in slurm.conf or offline / 節點未定義於 slurm.conf 或未連線
- State=`DOWN` / `DRAIN` / `NOT_RESPONDING` — needs troubleshooting / 需要故障排除

---

### 1.3 Job Queue — `squeue` / 查看作業佇列 — `squeue`

List running and pending jobs, filter by user or partition.

列出執行中與等待中的作業，可依使用者或分區過濾。

```bash
# All jobs / 所有作業
squeue

# Detailed / 詳細資訊
squeue -l

# By user / 特定使用者
squeue -u wlin
squeue -u phat

# By partition / 特定分區
squeue -p dl360
squeue -p gpu

# Custom format / 自訂格式
squeue -o "%i|%P|%u|%j|%T|%M|%N|%m|%D"
# %i=JobID, %P=partition, %u=user, %j=jobname, %T=state
# %M=time, %N=nodelist, %m=min mem, %D=num nodes

# Pending jobs only / 等待中作業
squeue -t PD -o "%i|%P|%u|%j|%R"
# %R=reason

# JSON-friendly output / JSON 輸出
squeue -o "%i|%P|%u|%j|%T|%M|%N|%R|%m|%D" --noheader -t PD,RUNNING
```

**Expected output example / 預期輸出範例:**
```
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST
3103     dl360   jobname     wlin  R      44:52      1 acmt23
3104     r630s   test.sh    phat  PD       0:00      1 (Resources)
```

**Error handling / 錯誤處理:**
- `squeue: error: ...` — check slurmctld / 檢查 Slurmctld
- State `PD` + reason `Resources` — waiting for resources to free / 等待資源釋放
- State `PD` + reason `Dependency` — waiting for an upstream job / 等待上游作業完成

---

### 1.4 Job Details — `scontrol show job` / 作業詳細資訊 — `scontrol show job`

Inspect a specific job's full state, including pending reason and exit code.

檢視特定作業的完整狀態，包含等待原因與退出碼。

```bash
scontrol show job <JOBID>

# Full info (including steps) / 完整資訊 (含 step)
scontrol show job -d <JOBID>

# Filter key fields / JSON-like 輸出
scontrol show job <JOBID> | grep -E "JobId=|JobName=|UserId=|JobState=|Partition=|NodeList=|NumNodes=|NumCPUs=|MinMemoryNode=|TimeLimit=|StartTime=|EndTime=|Command="
```

**Key fields / 關鍵欄位:**
- `JobState=RUNNING` / `PENDING` / `COMPLETED` / `FAILED`
- `Reason=...` — shown when `PD` / PD 狀態時顯示原因
- `ExitCode=0:0` — clean exit / 成功退出
- `WorkDir=...` — working directory / 工作目錄

---

### 1.5 Job Control / 作業控制

Cancel, suspend, resume, and edit jobs.

取消、暫停、恢復、修改作業。

```bash
# Cancel job / 取消作業
scancel <JOBID>

# Cancel all jobs for a user / 取消使用者所有作業
scancel -u wlin

# Cancel jobs in a state (e.g. all PD) / 取消特定狀態的作業 (如所有 PD 作業)
scancel -t PD -u wlin

# Suspend / resume / 暫停/恢復
scontrol suspend <JOBID>
scontrol resume <JOBID>

# Modify job (PD state only) / 修改作業 (僅 PD 狀態)
scontrol update JobId=<JOBID> Partition=gpu
scontrol update JobId=<JOBID> TimeLimit=7-00:00:00
```

---

### 1.6 Interactive Jobs / 互動式作業

Launch an interactive shell on a compute node.

在計算節點上啟動互動式 shell。

```bash
# Default partition / 預設分區
srun --pty /bin/bash

# Specific partition + resources / 指定分區與資源
srun -p dl360 --cpus-per-task=8 --mem=32G --pty /bin/bash

# GPU node / GPU 節點
srun -p gpu --gres=gpu:1 --pty /bin/bash

# Time-limited session / 指定時間
srun -p r630s --time=02:00:00 --pty /bin/bash
```

---

### 1.7 Batch Job Submission / 提交批次作業

Submit a script-based job, with optional resource and dependency constraints.

提交腳本作業，可附加資源與相依性參數。

```bash
# Basic / 基本
sbatch job.sh

# Specific partition / 指定分區
sbatch -p dl360 job.sh

# Resource constraints / 指定資源
sbatch -p gpu --gres=gpu:2 --cpus-per-task=16 --mem=32G job.sh

# Job name / 指定作業名稱
sbatch -J "my_job" -p r630s job.sh

# Dependency (wait for upstream JOBID) / 相依性 (等待 JOBID 完成後才開始)
sbatch -d afterok:<JOBID> job.sh
```

---

### 1.8 Slurm Accounting / Slurm 帳務

Query historical usage data via `sacct`.

透過 `sacct` 查詢歷史用量資料。

```bash
# Per-user usage / 查看使用者用量
sacct -u wlin --format=JobID,JobName,Partition,State,Elapsed,MaxRSS,MaxVMSize,NodeList

# Date range / 特定日期範圍
sacct -u wlin -S 2026-03-01 -E 2026-03-19

# Job efficiency / 作業效率
sacct -j <JOBID> --format=JobID,JobName,Partition,AllocCPUS,ReqMem,MaxRSS,Elapsed,NodeList
```

---

## 2. System Monitoring / 系統監控命令組

### 2.1 slurm-monitor (TUI)

Curses-based TUI dashboard combining `sinfo`, `squeue`, and per-node telemetry.

整合 `sinfo`、`squeue` 與節點 telemetry 的 curses TUI 儀表板。

```bash
# Basic usage / 基本使用
cd /root/slurm-monitor && ./slurm-monitor

# Custom node-name pattern / 自訂節點模式
./slurm-monitor -pattern "acmt[0-9]+"

# Keys / 操作
# 1-4: switch tabs (Dashboard/Nodes/Jobs/Controller) / 切換標籤頁
# Tab/←/→: switch tabs / 切換標籤頁
# F1/h: help / 幫助
# q/Ctrl+C: quit / 退出
```

**Data sources and refresh cadence / 資料來源與更新頻率:**
- Fast path (3 s): `sinfo`, `squeue` / 快速路徑 (3 秒): `sinfo`, `squeue`
- Slow path (15 s): `sdiag`, `systemctl` / 慢速路徑 (15 秒): `sdiag`, `systemctl`
- Telemetry (30 s): SSH-collected CPU / memory / disk / load / Telemetry (30 秒): SSH 採集 CPU/記憶體/磁碟/負載

---

### 2.2 Realtime System Resource Queries / 系統資源即時查詢

Probe a node over SSH for memory, disk, load, CPU, and network state.

透過 SSH 查詢節點的記憶體、磁碟、負載、CPU、網路狀態。

```bash
# One-shot multi-metric query via SSH / 透過 SSH 查詢單節點
ssh acmt01 "free -h && echo '---' && df -h / /home /opt && echo '---' && uptime && echo '---' && nproc"

# CPU utilization / CPU 使用率
ssh acmt01 "top -bn1 | head -5"

# Memory detail / 記憶體詳情
ssh acmt01 "free -m"

# Disk I/O / 磁碟 I/O
ssh acmt01 "iostat -x 1 3"

# Network / 網路
ssh acmt01 "ip addr show && echo '---' && ping -c 2 acmt0"
```

---

### 2.3 InfiniBand Status / InfiniBand 狀態

Query IB device, fabric, switches, and performance.

查詢 IB 裝置、fabric、switch 與效能。

```bash
# IB device status / IB 設備狀態
ibstat

# IB port status / IB 埠狀態
ibstatus

# Fabric discovery / fabric 發現
ibnetdiscover

# Switch status / 切換機狀態
ibswitches

# Node GUID query / 節點 GUID 查詢
ibhosts

# Performance tests / 效能測試
ib_write_bw -d mlx5_0
ib_read_lat -d mlx5_0
```

---

### 2.4 GPU Status / GPU 狀態

> GPU hardware specs, partition mapping, and CUDA capability are in [ACMT_HPC_Cluster_Nodes_Configuration.md §5](ACMT_HPC_Cluster_Nodes_Configuration.md).
>
> GPU 硬體規格、partition 對應、CUDA capability 見 [ACMT_HPC_Cluster_Nodes_Configuration.md §5](ACMT_HPC_Cluster_Nodes_Configuration.md)。

```bash
# Basic status / 基本狀態
nvidia-smi

# Model + memory / 查詢型號與記憶體
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader

# Per-process usage / 程序使用情況
nvidia-smi pmon -c 1

# Remote query from headnode / 從管理節點遠端查詢
ssh acmt20 nvidia-smi
ssh acmt-gpu nvidia-smi
```

---

## 3. User Management / 使用者管理命令組

### 3.1 Slurm User Management (slurm.py) / Slurm 使用者管理 (slurm.py)

Wrapper script for adding/removing users from Slurm accounts.

新增或移除 Slurm 帳號使用者的封裝腳本。

```bash
# Add user to Slurm (default account: lab) / 新增使用者到 Slurm (預設帳號 lab)
python3 /root/acmt-ansible/scripts/slurm.py -u <username>

# Specify account / 指定帳號
python3 slurm.py -u <username> -a <account>

# Remove user / 刪除使用者
python3 slurm.py -u <username> -d

# Remove user from specific account / 指定帳號刪除
python3 slurm.py -u <username> -a <account> -d
```

**Run on / 執行位置:** acmt0
**Prerequisite / 前置條件:** User exists in Linux + LDAP / 使用者已存在於 Linux 系統 + LDAP
**Success message / 成功訊息:** `User <username> has been added to <account>`

---

### 3.2 Direct `sacctmgr` Operations (when needed) / Sacctmgr 直接操作 (需要時使用)

Lower-level user/account/QoS management.

更底層的 user/account/QoS 管理。

```bash
# List existing users / 查現有使用者
sacctmgr list users

# List accounts / 查帳號
sacctmgr list accounts

# Add user / 新增使用者
sacctmgr add user <username> Account=lab --immediate

# Remove user / 刪除使用者
sacctmgr remove user <username> Account=lab --immediate

# Add account / 新增帳號
sacctmgr add account lab --immediate

# Set QoS / 設定 QoS
sacctmgr modify user <username> set qos=normal
```

---

## 4. System Maintenance / 系統維護命令組

### 4.1 Node State Management / 節點狀態管理

Take a node in/out of service.

切換節點的服務狀態。

```bash
# Drain node (maintenance mode) / Drain 節點 (維護模式)
scontrol update NodeName=acmt08 State=DRAIN Reason="Maintenance"

# Resume node / Resume 節點 (恢復)
scontrol update NodeName=acmt08 State=RESUME

# Mark node DOWN / 將節點標為 DOWN
scontrol update NodeName=acmt14 State=DOWN Reason="Hardware issue"

# Drain after current jobs finish (non-disruptive) / 節點空閒後自動 Drain (不中斷現有作業)
scontrol update NodeName=acmt08 State=DRAIN Reason="Maintenance"

# Force drain (kills current jobs) / 強制 Drain (中斷作業)
scontrol update NodeName=acmt08 State=DRAIN Reason="Emergency" Force=YES
```

---

### 4.2 Slurm Service Management (acmt0) / Slurm 服務管理 (acmt0)

Manage slurmctld, slurmdbd, and munge daemons.

管理 slurmctld、slurmdbd、munge 服務。

```bash
# Controller
systemctl status slurmctld
systemctl restart slurmctld
systemctl stop slurmctld
systemctl start slurmctld

# DB account daemon / DB Account daemon
systemctl status slurmdbd
systemctl restart slurmdbd

# Munge (authentication) / Munge (認證)
systemctl status munge
systemctl restart munge
```

**Restart order / 重啟順序:** munge → slurmdbd → slurmctld

**Verify restart success / 檢查重啟成功:**

```bash
systemctl is-active slurmctld && echo "OK" || echo "FAIL"
tail -20 /var/log/slurm/slurmctld.log
```

---

### 4.3 NFS Status Checks / NFS 狀態檢查

Verify NFS mounts, exports, and server health.

驗證 NFS 掛載、export 與 server 健康狀態。

```bash
# Mount check (all nodes) / 掛載檢查 (所有節點)
mount | grep -E "192.168.1.11|nfs"

# Export check (acmt-storage) / 匯出檢查 (acmt-storage)
showmount -e 192.168.1.11

# NFS server status (acmt-storage) / NFS 伺服器狀態 (acmt-storage)
ssh acmt-storage "systemctl status nfs-server"

# Mount throughput test / 掛載效能測試
time dd if=/dev/zero of=/home/test_io bs=1M count=1024
# Expect > 50 MB/s on NFS / 寫入速度應 > 50MB/s (網路 NFS)
```

---

### 4.4 Prometheus & Grafana (acmt0)

Query monitoring stack health.

查詢監控堆疊狀態。

```bash
# Prometheus
systemctl status prometheus
curl -s http://localhost:9090/api/v1/query?query=up | python3 -m json.tool

# Grafana (Web UI: http://acmt0:3000, default admin/admin) / Grafana (Web UI: http://acmt0:3000, 預設 admin/admin)
systemctl status grafana-server

# Node Exporter (all nodes) / Node Exporter (所有節點)
curl -s http://acmt01:9100/metrics | head -20

# Slurm Exporter (acmt0 only) / Slurm Exporter (僅 acmt0)
curl -s http://localhost:8080/metrics | head -20
```

---

## 5. Network Connectivity Checks / 網路連線檢查

ICMP, SSH, batch reachability, port probes.

ICMP、SSH、批量檢查、埠探測。

```bash
# ICMP test / ICMP 測試
ping -c 2 -W 2 acmt01

# SSH test / SSH 測試
ssh -o ConnectTimeout=5 acmt01 "hostname"

# Batch reachability of all nodes / 批量測試所有節點
for node in acmt{01..27} acmt-gpu acmt-storage; do
  ping -c 1 -W 2 $node >/dev/null 2>&1 \
    && echo "$node: OK" \
    || echo "$node: FAIL"
done

# Specific port test (Slurm) / 特定埠測試 (Slurm)
nc -zv acmt01 6818
nc -zv acmt0 6817
```

---

## 6. Log Lookup / 日誌查詢

Tail and grep Slurm, system, and auth logs.

檢視與搜尋 Slurm、系統與認證日誌。

```bash
# Slurmctld log / Slurmctld 日誌
tail -100 /var/log/slurm/slurmctld.log
grep -i error /var/log/slurm/slurmctld.log

# Slurmd log (on the node itself) / Slurmd 日誌 (在對應節點上)
ssh acmt01 "tail -50 /var/log/slurm/slurmd.log"

# System log (node-side troubleshooting) / 系統日誌 (節點問題排查)
ssh acmt01 "journalctl -n 50 --no-pager"

# Auth log / 認證日誌
journalctl -u munge -n 20 --no-pager
```

---

## Quick Command Cheatsheet / 命令執行速查表

| Task / 任務 | Command / 命令 | Run on / 執行位置 |
|------|------|----------|
| Partition state / 查分區狀態 | `sinfo -N -l` | acmt0 |
| Node details / 查節點詳情 | `scontrol show node acmtXX` | acmt0 |
| Job queue / 查作業 | `squeue -l` | acmt0 |
| Cancel job / 取消作業 | `scancel <JOBID>` | acmt0 |
| Submit job / 提交作業 | `sbatch job.sh` | Any node / 任意節點 |
| Interactive shell / 互動 shell | `srun --pty /bin/bash` | acmt0 |
| User usage / 查使用者用量 | `sacct -u wlin` | acmt0 |
| Add Slurm user / 新增 Slurm 用戶 | `python3 slurm.py -u name` | acmt0 |
| Drain node / Drain 節點 | `scontrol update ... DRAIN` | acmt0 |
| Restart slurmctld / 重啟 Slurmctld | `systemctl restart slurmctld` | acmt0 |
| Check NFS mount / 檢查 NFS 掛載 | `mount \| grep nfs` | Each node / 各節點 |
| GPU status / 查看 GPU 狀態 | `nvidia-smi` | GPU node / GPU 節點 |
| IB network check / 檢查 IB 網路 | `ibstat` | IB-enabled node / 有 IB 的節點 |
| Network reachability / 檢查網路連通 | `ping acmtXX` | acmt0 |
| Launch monitoring TUI / 啟動監控 TUI | `./slurm-monitor` | acmt0 |
