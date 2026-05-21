# ACMT HPC Cluster — Tools & Commands Reference

## 命名規範

| 欄位 | 說明 |
|------|------|
| 管理節點 | `acmt0` (192.168.1.10) |
| 儲存節點 | `acmt-storage` (192.168.1.11) |
| 計算節點 | `acmt01`–`acmt27` |
| GPU 節點 | `acmt-gpu` (192.168.1.32), `acmt20` (192.168.1.31) |
| NFS 掛載 | `192.168.1.11:/home` → `/home`, `192.168.1.11:/opt` → `/opt` |

**所有操作須在管理節點 acmt0 上執行，除非另有說明。**

---

## 1. Slurm 命令組

### 1.1 查看分區狀態 — `sinfo`

```bash
# 所有分區摘要
sinfo

# 詳細輸出 (完整節點列表)
sinfo -N -l

# 特定分區
sinfo -p r630s -N -l
sinfo -p gpu
sinfo -p dl360

# 自訂格式
sinfo -o "%n %t %c %m %d %l"
# %n=hostname, %t=state, %c=CPUs, %m=memory, %d=disk, %l=load

# JSON 輸出 (AI 解析用)
sinfo -o "%n|%T|%e|%m|%c|%a|%l|%d" --noheader
```

**預期輸出範例:**
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
r630s*       up 14-00:00:0      5   idle acmt[09-11,13]
r630s*       up 14-00:00:0      2  drain acmt[14-15]
dl360        up 14-00:00:0      4  alloc acmt[21-24]
dl360        up 14-00:00:0      2   idle acmt[25]
```

**錯誤處理:**
- `sinfo: error: ...` → Slurmctld 可能未執行
- 先檢查 `systemctl status slurmctld`

---

### 1.2 查看節點詳情 — `scontrol show node`

```bash
# 單一節點
scontrol show node acmt01

# 所有節點
scontrol show nodes

# 特定分區節點
scontrol show nodes | grep -A 20 "PartitionName=r630s"

# 只看某欄位
scontrol show node acmt01 | grep -E "NodeName|State|CPUs|RealMemory|AllocMem"
```

**預期輸出 (關鍵欄位):**
```
NodeName=acmt01 Arch=x86_64 CoresPerSocket=8
  CPUAlloc=0 CPUTot=16 CPULoad=0.12
  RealMemory=209490 AllocMem=0 FreeMem=203456
  State=IDLE ThreadsPerCore=1
  PartitionName=r620
```

**錯誤處理:**
- `Node acmtXX not found` → 節點未定義於 slurm.conf 或未連線
- State=`DOWN` / `DRAIN` / `NOT_RESPONDING` → 需要故障排除

---

### 1.3 查看作業佇列 — `squeue`

```bash
# 所有作業
squeue

# 詳細資訊
squeue -l

# 特定使用者
squeue -u wlin
squeue -u phat

# 特定分區
squeue -p dl360
squeue -p gpu

# 自訂格式
squeue -o "%i|%P|%u|%j|%T|%M|%N|%m|%D"
# %i=JobID, %P=partition, %u=user, %j=jobname, %T=state
# %M=time, %N=nodelist, %m=min mem, %D=num nodes

# 等待中作業
squeue -t PD -o "%i|%P|%u|%j|%R"
# %R=reason

# JSON 輸出
squeue -o "%i|%P|%u|%j|%T|%M|%N|%R|%m|%D" --noheader -t PD,RUNNING
```

**預期輸出範例:**
```
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST
3103     dl360   jobname     wlin  R      44:52      1 acmt23
3104     r630s   test.sh    phat  PD       0:00      1 (Resources)
```

**錯誤處理:**
- `squeue: error: ...` → 檢查 Slurmctld
- State `PD` + Reason `Resources` → 等待資源釋放
- State `PD` + Reason `Dependency` → 等待上游作業完成

---

### 1.4 作業詳細資訊 — `scontrol show job`

```bash
scontrol show job <JOBID>

# 完整資訊 (含 step)
scontrol show job -d <JOBID>

# JSON-like 輸出
scontrol show job <JOBID> | grep -E "JobId=|JobName=|UserId=|JobState=|Partition=|NodeList=|NumNodes=|NumCPUs=|MinMemoryNode=|TimeLimit=|StartTime=|EndTime=|Command="
```

**關鍵欄位:**
- `JobState=RUNNING` / `PENDING` / `COMPLETED` / `FAILED`
- `Reason=...` (PD 狀態時顯示原因)
- `ExitCode=0:0` (成功退出)
- `WorkDir=...` 工作目錄

---

### 1.5 作業控制

```bash
# 取消作業
scancel <JOBID>

# 取消使用者所有作業
scancel -u wlin

# 取消特定狀態的作業 (如所有 PD 作業)
scancel -t PD -u wlin

# 暫停/恢復
scontrol suspend <JOBID>
scontrol resume <JOBID>

# 修改作業 (僅 PD 狀態)
scontrol update JobId=<JOBID> Partition=gpu
scontrol update JobId=<JOBID> TimeLimit=7-00:00:00
```

---

### 1.6 互動式作業

```bash
# 預設分區
srun --pty /bin/bash

# 指定分區與資源
srun -p dl360 --cpus-per-task=8 --mem=32G --pty /bin/bash

# GPU 節點
srun -p gpu --gres=gpu:1 --pty /bin/bash

# 指定時間
srun -p r630s --time=02:00:00 --pty /bin/bash
```

---

### 1.7 提交批次作業

```bash
# 基本
sbatch job.sh

# 指定分區
sbatch -p dl360 job.sh

# 指定資源
sbatch -p gpu --gres=gpu:2 --cpus-per-task=16 --mem=32G job.sh

# 指定作業名稱
sbatch -J "my_job" -p r630s job.sh

# 相依性 (等待 JOBID 完成後才開始)
sbatch -d afterok:<JOBID> job.sh
```

---

### 1.8 Slurm 帳務

```bash
# 查看使用者用量
sacct -u wlin --format=JobID,JobName,Partition,State,Elapsed,MaxRSS,MaxVMSize,NodeList

# 特定日期範圍
sacct -u wlin -S 2026-03-01 -E 2026-03-19

# 作業效率
sacct -j <JOBID> --format=JobID,JobName,Partition,AllocCPUS,ReqMem,MaxRSS,Elapsed,NodeList
```

---

## 2. 系統監控命令組

### 2.1 slurm-monitor (TUI)

```bash
# 基本使用
cd /root/slurm-monitor && ./slurm-monitor

# 自訂節點模式
./slurm-monitor -pattern "acmt[0-9]+"

# 操作
# 1-4: 切換標籤頁 (Dashboard/Nodes/Jobs/Controller)
# Tab/←/→: 切換標籤頁
# F1/h: 幫助
# q/Ctrl+C: 退出
```

**資料來源與更新頻率:**
- 快速路徑 (3 秒): `sinfo`, `squeue`
- 慢速路徑 (15 秒): `sdiag`, `systemctl`
- Telemetry (30 秒): SSH 採集 CPU/記憶體/磁碟/負載

---

### 2.2 系統資源即時查詢

```bash
# 透過 SSH 查詢單節點
ssh acmt01 "free -h && echo '---' && df -h / /home /opt && echo '---' && uptime && echo '---' && nproc"

# CPU 使用率
ssh acmt01 "top -bn1 | head -5"

# 記憶體詳情
ssh acmt01 "free -m"

# 磁碟 I/O
ssh acmt01 "iostat -x 1 3"

# 網路
ssh acmt01 "ip addr show && echo '---' && ping -c 2 acmt0"
```

---

### 2.3 InfiniBand 狀態

```bash
# IB 設備狀態
ibstat

# IB 埠狀態
ibstatus

# fabric 發現
ibnetdiscover

# 切換機狀態
ibswitches

# 節點 GUID 查詢
ibhosts

# 效能測試
ib_write_bw -d mlx5_0
ib_read_lat -d mlx5_0
```

---

### 2.4 GPU 狀態

```bash
# 基本狀態
nvidia-smi

# 查詢型號與記憶體
nvidia-smi --query-gpu=name,memory.total,memory.used,memory.free --format=csv,noheader

# 程序使用情況
nvidia-smi pmon -c 1

# 從管理節點遠端查詢
ssh acmt20 nvidia-smi
ssh acmt-gpu nvidia-smi
```

---

## 3. 使用者管理命令組

### 3.1 Slurm 使用者管理 (slurm.py)

```bash
# 新增使用者到 Slurm (預設帳號 lab)
python3 /root/acmt-ansible/scripts/slurm.py -u <username>

# 指定帳號
python3 slurm.py -u <username> -a <account>

# 刪除使用者
python3 slurm.py -u <username> -d

# 指定帳號刪除
python3 slurm.py -u <username> -a <account> -d
```

**執行位置:** acmt0
**前置條件:** 使用者已存在於 Linux 系統 + LDAP
**成功訊息:** `User <username> has been added to <account>`

---

### 3.2 Sacctmgr 直接操作 (需要時使用)

```bash
# 查現有使用者
sacctmgr list users

# 查帳號
sacctmgr list accounts

# 新增使用者
sacctmgr add user <username> Account=lab --immediate

# 刪除使用者
sacctmgr remove user <username> Account=lab --immediate

# 新增帳號
sacctmgr add account lab --immediate

# 設定 QoS
sacctmgr modify user <username> set qos=normal
```

---

## 4. 系統維護命令組

### 4.1 節點狀態管理

```bash
# Drain 節點 (維護模式)
scontrol update NodeName=acmt08 State=DRAIN Reason="Maintenance"

# Resume 節點 (恢復)
scontrol update NodeName=acmt08 State=RESUME

# 將節點標為 DOWN
scontrol update NodeName=acmt14 State=DOWN Reason="Hardware issue"

# 節點空閒後自動 Drain (不中斷現有作業)
scontrol update NodeName=acmt08 State=DRAIN Reason="Maintenance"

# 強制 Drain (中斷作業)
scontrol update NodeName=acmt08 State=DRAIN Reason="Emergency" Force=YES
```

---

### 4.2 Slurm 服務管理 (acmt0)

```bash
# Controller
systemctl status slurmctld
systemctl restart slurmctld
systemctl stop slurmctld
systemctl start slurmctld

# DB Account daemon
systemctl status slurmdbd
systemctl restart slurmdbd

# Munge (認證)
systemctl status munge
systemctl restart munge
```

**重啟順序:** munge → slurmdbd → slurmctld
**檢查重啟成功:**
```bash
systemctl is-active slurmctld && echo "OK" || echo "FAIL"
tail -20 /var/log/slurm/slurmctld.log
```

---

### 4.3 NFS 狀態檢查

```bash
# 掛載檢查 (所有節點)
mount | grep -E "192.168.1.11|nfs"

# 匯出檢查 (acmt-storage)
showmount -e 192.168.1.11

# NFS 伺服器狀態 (acmt-storage)
ssh acmt-storage "systemctl status nfs-server"

# 掛載效能測試
time dd if=/dev/zero of=/home/test_io bs=1M count=1024
# 寫入速度應 > 50MB/s (網路 NFS)
```

---

### 4.4 Prometheus & Grafana (acmt0)

```bash
# Prometheus
systemctl status prometheus
curl -s http://localhost:9090/api/v1/query?query=up | python3 -m json.tool

# Grafana (Web UI: http://acmt0:3000, 預設 admin/admin)
systemctl status grafana-server

# Node Exporter (所有節點)
curl -s http://acmt01:9100/metrics | head -20

# Slurm Exporter (僅 acmt0)
curl -s http://localhost:8080/metrics | head -20
```

---

## 5. 網路連線檢查

```bash
# ICMP 測試
ping -c 2 -W 2 acmt01

# SSH 測試
ssh -o ConnectTimeout=5 acmt01 "hostname"

# 批量測試所有節點
for node in acmt0{1..27} acmt-gpu acmt-storage; do
  ping -c 1 -W 2 $node >/dev/null 2>&1 \
    && echo "$node: OK" \
    || echo "$node: FAIL"
done

# 特定埠測試 (Slurm)
nc -zv acmt01 6818
nc -zv acmt0 6817
```

---

## 6. 日誌查詢

```bash
# Slurmctld 日誌
tail -100 /var/log/slurm/slurmctld.log
grep -i error /var/log/slurm/slurmctld.log

# Slurmd 日誌 (在對應節點上)
ssh acmt01 "tail -50 /var/log/slurm/slurmd.log"

# 系統日誌 (節點問題排查)
ssh acmt01 "journalctl -n 50 --no-pager"

# 認證日誌
journalctl -u munge -n 20 --no-pager
```

---

## 命令執行速查表

| 任務 | 命令 | 執行位置 |
|------|------|----------|
| 查分區狀態 | `sinfo -N -l` | acmt0 |
| 查節點詳情 | `scontrol show node acmtXX` | acmt0 |
| 查作業 | `squeue -l` | acmt0 |
| 取消作業 | `scancel <JOBID>` | acmt0 |
| 提交作業 | `sbatch job.sh` | 任意節點 |
| 互動 shell | `srun --pty /bin/bash` | acmt0 |
| 查使用者用量 | `sacct -u wlin` | acmt0 |
| 新增 Slurm 用戶 | `python3 slurm.py -u name` | acmt0 |
| Drain 節點 | `scontrol update ... DRAIN` | acmt0 |
| 重啟 Slurmctld | `systemctl restart slurmctld` | acmt0 |
| 檢查 NFS 掛載 | `mount \| grep nfs` | 各節點 |
| 查看 GPU 狀態 | `nvidia-smi` | GPU 節點 |
| 檢查 IB 網路 | `ibstat` | 有 IB 的節點 |
| 檢查網路連通 | `ping acmtXX` | acmt0 |
| 啟動監控 TUI | `./slurm-monitor` | acmt0 |
