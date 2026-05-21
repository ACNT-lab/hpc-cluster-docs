# ACMT HPC Cluster — Troubleshooting Decision Tree

通用原則:
1. 先確認問題範圍: 單一節點？部分節點？全部節點？
2. 由外而內檢查: 網路 → 服務 → 設定 → 硬體
3. 記錄操作前狀態，以便復原

---

## 1. 節點離線 (NODE NOT_RESPONDING / DOWN)

### 決策樹

```
節點在 sinfo 顯示 DOWN 或 NOT_RESPONDING?
│
├─ 是 →
│   ├─ ping 節點 IP 成功？
│   │   ├─ 否 → 網路或硬體問題
│   │   │   ├─ 檢查交換器埠狀態
│   │   │   ├─ 檢查 IPMI/BMC (若可存取)
│   │   │   └─ 機房實體檢查 (電源、網路線)
│   │   │
│   │   └─ 是 → SSH 可連線？
│   │       ├─ 否 → SSH 服務問題
│   │       │   ├─ sshd 是否在運行: ssh acmtXX "systemctl status sshd"
│   │       │   ├─ 防火牆: ssh acmtXX "ufw status" 或 iptables -L
│   │       │   └─ hosts.deny: ssh acmtXX "cat /etc/hosts.deny"
│   │       │
│   │       └─ 是 → Slurmd 問題
│   │           ├─ systemctl status slurmd 是否 active?
│   │           │   ├─ 否 → 啟動 slurmd: systemctl start slurmd
│   │           │   │   └─ 啟動失敗?
│   │           │   │       ├─ tail -50 /var/log/slurm/slurmd.log
│   │           │   │       ├─ 檢查 munge: systemctl status munge
│   │           │   │       └─ 檢查 slurm.conf 正確性
│   │           │   │
│   │           │   └─ 是 → 但 Slurmctld 仍回報 DOWN
│   │           │       ├─ 在節點上重啟 slurmd: systemctl restart slurmd
│   │           │       ├─ 在管理節點上: scontrol update NodeName=acmtXX State=RESUME
│   │           │       └─ 等待 30 秒，再次 sinfo 確認
│   │           │
│   │           └─ slurmd 日誌有錯誤?
│   │               ├─ "No route to host" → 防火牆阻擋 port 6818
│   │               ├─ "Invalid authentication" → Munge key 不一致
│   │               │   └─ scp /etc/munge/munge.key acmtXX:/etc/munge/
│   │               │       └─ systemctl restart munge slurmd
│   │               ├─ "slurm.conf not found" → 設定檔遺失
│   │               │   └─ scp /etc/slurm/slurm.conf acmtXX:/etc/slurm/
│   │               └─ "Protocol version mismatch" → Slurm 版本不一致
│   │                   └─ 全部節點需統一版本
│   │
│   └─ 其他檢查
│       ├─ 檢查時鐘同步: ssh acmtXX "chronyc tracking | grep Stratum"
│       ├─ 資源耗盡: ssh acmtXX "df -h / && free -h"
│       └─ 核心凍結: ssh acmtXX "dmesg | tail -20"
│
└─ 否 → 狀態是 DRAIN?
    ├─ scontrol show node acmtXX | grep Reason
    │   ├─ "Low Memory" → 記憶體不足，無法排程
    │   │   ├─ 檢查 free -h 實際記憶體
    │   │   ├─ 有作業佔用過多記憶體尚未釋放?
    │   │   └─ 考慮 RESUME 或重新開機
    │   │
    │   ├─ "Maintenance" → 人為標記維護
    │   │   └─ 完成維護後: scontrol update NodeName=acmtXX State=RESUME
    │   │
    │   └─ "Not Responding" → 節點無回應後自動 Drain
    │       └─ 按上方 NOT_RESPONDING 流程處理
    │
    └─ 節點狀態是 IDLE 但應該有作業在跑?
        └─ 作業可能已完成或被取消，檢查 squeue
```

### 已知離線節點 (不需處理)
| 節點 | IP | 原因 |
|------|-----|------|
| acmt08 | 192.168.1.19 | 網路無回應 |
| acmt16 | 192.168.1.27 | 網路無回應 |
| acmt17 | 192.168.1.28 | 網路無回應 |
| acmt26 | 192.168.1.38 | 網路無回應 |

### 已知 Drain 節點
| 節點 | IP | 原因 |
|------|-----|------|
| acmt14 | 192.168.1.25 | 記憶體不足 |
| acmt15 | 192.168.1.26 | 記憶體不足 |

---

## 2. Slurmctld 服務異常

### 決策樹

```
scontrol 或 sinfo 命令回傳 Connection refused 或 Timeout?
│
├─ systemctl status slurmctld
│   ├─ active (running) →
│   │   ├─ 檢查 port: ss -tlnp | grep 6817
│   │   │   └─ 無 → slurmctld 可能 bind 失敗
│   │   │       └─ journalctl -u slurmctld -n 50
│   │   │
│   │   └─ 有 → 防火牆問題
│   │       └─ iptables -L -n | grep 6817
│   │
│   ├─ failed →
│   │   ├─ journalctl -u slurmctld -n 100
│   │   ├─ 檢查 slurm.conf 語法: slurmctld -t
│   │   ├─ 檢查 slurmdbd.conf 語法: slurmdbd -t
│   │   ├─ 檢查 MySQL/MariaDB: systemctl status mysql
│   │   │   └─ MySQL 掛掉 → slurmdbd 無法啟動 → slurmctld 可能也失敗
│   │   │       ├─ systemctl start mysql
│   │   │       └─ 檢查: mysql -u root -e "SELECT 1"
│   │   │
│   │   ├─ 檢查權限: ls -la /etc/slurm/slurmdbd.conf (應為 0600)
│   │   ├─ 檢查 /var/log/slurm/ 目錄權限
│   │   └─ 嘗試啟動: systemctl start slurmctld
│   │       └─ 啟動順序: munge → mysql → slurmdbd → slurmctld
│   │
│   └─ inactive (dead) →
│       └─ 手動啟動: systemctl start slurmctld
│           └─ 啟動失敗? 同上 failed 流程
│
└─ 查看日誌
    tail -100 /var/log/slurm/slurmctld.log
    # 常見錯誤:
    # "fatal: No configuration file" → slurm.conf 遺失
    # "fatal: Munge authentication" → munge 問題
    # "error: mysql" → 資料庫連線問題
```

### 修復指令匯總

```bash
# 完整重啟順序 (在 acmt0 上)
systemctl restart munge
systemctl restart mysql       # 或 mariadb
sleep 2
systemctl restart slurmdbd
sleep 2
systemctl restart slurmctld

# 確認每一步都成功
systemctl is-active munge mysql slurmdbd slurmctld
# 應全部回傳 active
```

---

## 3. Slurmd (計算節點) 異常

### 決策樹

```
特定節點無法加入集群 (sinfo 顯示 down 或 not responding)?
│
├─ 節點可 ping 通?
│   └─ 否 → 處理網路問題 (見 1. 節點離線)
│
├─ SSH 可連線?
│   └─ 否 → SSH 服務問題
│
├─ systemctl status slurmd
│   ├─ active (running) →
│   │   ├─ 檢查 slurmd 連線到 acmt0
│   │   │   scontrol show node acmtXX | grep State
│   │   │   └─ 回報 down? → scontrol update NodeName=acmtXX State=RESUME
│   │   │
│   │   └─ 檢查 port 6818: ss -tlnp | grep 6818
│   │
│   ├─ failed →
│   │   ├─ journalctl -u slurmd -n 50
│   │   ├─ slurmd -C 確認節點硬體資訊 (CPUs, RealMemory 等)
│   │   ├─ 比對 slurm.conf 中的 NodeName 設定
│   │   └─ 嘗試啟動: systemctl start slurmd
│   │
│   └─ inactive (dead) →
│       └─ systemctl start slurmd
│
└─ 檢查 munge (常見原因)
    systemctl status munge
    # 若 munge 掛了，slurmd 無法認證
    systemctl restart munge && systemctl restart slurmd
```

### 批量修復

```bash
# 使用 Ansible 在所有節點重啟 slurmd
ansible acmt -m shell -a "systemctl restart slurmd" --limit '!acmt0,!acmt-storage'

# 或特定節點
ansible acmtXX -m shell -a "systemctl restart slurmd && systemctl is-active slurmd"
```

---

## 4. NFS 掛載異常

### 決策樹

```
df -h /home 或 /opt 顯示 stale 或掛載遺失?
│
├─ 確認 NFS 伺服器
│   ├─ ping acmt-storage (192.168.1.11)
│   ├─ showmount -e 192.168.1.11
│   │   ├─ Export list for 192.168.1.11:
│   │   │   /home 192.168.1.0/24
│   │   │   /opt 192.168.1.0/24
│   │   │   → 正常
│   │   │
│   │   └─ Error: mount export: RPC Error → NFS 服務異常
│   │       └─ ssh acmt-storage "systemctl status nfs-server"
│   │           └─ 重啟: ssh acmt-storage "systemctl restart nfs-server"
│   │
│   └─ ssh acmt-storage "ls -la /home" (確認匯出目錄存在)
│
├─ 檢查用戶端掛載
│   ├─ mount | grep nfs
│   │   ├─ 有掛載但操作卡住 → stale file handle
│   │   │   ├─ umount -f /home (強制卸載)
│   │   │   │   └─ 失敗? → umount -l /home (懶卸載)
│   │   │   └─ mount /home
│   │   │
│   │   └─ 無掛載 → 檢查 systemd mount unit
│   │       ├─ systemctl status home.mount
│   │       ├─ systemctl status opt.mount
│   │       └─ systemctl restart home.mount opt.mount
│   │
│   └─ 檢查 /etc/fstab
│       grep nfs /etc/fstab
│
└─ 檢查 InfiniBand (若使用 RDMA)
    ibstat | grep state
    # PORT_ACTIVE 表示正常
    # 若 DOWN → 檢查 IB 交換機和纜線
```

### 常用修復

```bash
# 在每個受影響的節點上
umount -l /home 2>/dev/null
umount -l /opt 2>/dev/null
mount /home
mount /opt

# 檢查掛載成功
df -h /home /opt

# 如果不能卸載，重新開機
```

---

## 5. 作業卡住 (Job STUCK / SUSPENDED)

### 決策樹

```
作業長時間在 RUNNING 狀態但無進度?
│
├─ scontrol show job <JOBID>
│   ├─ JobState=SUSPENDED?
│   │   ├─ 原因: 優先權較低的作業被暫停
│   │   ├─ scontrol resume <JOBID> 恢復 (需管理員權限)
│   │   └─ 或等待高優先權作業完成後自動恢復
│   │
│   ├─ JobState=RUNNING 但無 CPU 使用
│   │   ├─ 檢查該作業的節點
│   │   │   sacct -j <JOBID> --format=JobID,NodeList,State,ExitCode
│   │   │
│   │   ├─ 節點上無該使用者行程?
│   │   │   ssh acmtXX "ps aux | grep <username> | wc -l"
│   │   │   ├─ 無行程 → 作業已掛掉但 Slurm 未偵測
│   │   │   │   └─ scancel <JOBID> 並重送
│   │   │   └─ 有行程 → 程式本身問題
│   │   │       └─ ssh acmtXX "strace -p <PID> -e trace=all -c" 需 root
│   │   │
│   │   └─ NFS hang 導致 I/O 卡住
│   │       └─ 檢查 NFS 狀態 (見 4. NFS 掛載異常)
│   │
│   └─ JobState=PENDING 很久?
│       ├─ squeue -j <JOBID> -o "%R"
│       │   ├─ Reason=Resources → 等待資源釋放
│       │   │   ├─ sinfo -p <partition> 檢查資源
│       │   │   └─ 考慮提高優先權或換分區
│       │   │
│       │   ├─ Reason=Dependency → 等待上游作業
│       │   │   └─ scontrol show job <JOBID> | grep Dependency
│       │   │
│       │   ├─ Reason=QOSMaxCpuPerUserLimit → QoS 限制
│       │   │   ├─ sacctmgr show user <username> format=User,QOS
│       │   │   └─ 檢查使用者總 CPU 用量
│       │   │
│       │   ├─ Reason=AssocGrpCPUMinutesLimit → 帳號配額用完
│       │   │   └─ sacctmgr show associations format=User,Account,GrpTRESMins
│       │   │
│       │   └─ Reason=PartitionNodeDown → 分區節點全離線
│       │       └─ sinfo -p <partition> 檢查狀態
│       │
│       └─ 優先權太低?
│           sprio -j <JOBID>
│           # 查看 priority components (fairshare, age, job_size, partition)
```

---

## 6. GPU 問題

### 決策樹

```
GPU 作業送不出去或執行失敗?
│
├─ nvidia-smi (在 GPU 節點上)
│   ├─ "No devices were found"
│   │   ├─ NVIDIA 驅動未安裝或掛載
│   │   │   ├─ lsmod | grep nvidia
│   │   │   ├─ dkms status
│   │   │   └─ reboot (驅動更新後需要重新開機)
│   │   │
│   │   └─ 硬體問題: dmesg | grep -i nvidia
│   │
│   ├─ GPU 記憶體耗盡
│   │   ├─ nvidia-smi --query-gpu=memory.used,memory.free --format=csv
│   │   └─ 清除殘留程序: fuser -v /dev/nvidia*
│   │
│   └─ GPU 全部被佔用 (2/2 used)
│       ├─ squeue -p gpu 檢查是否有排隊作業
│       └─ 或在 r740 分區查看: squeue -p r740
│
├─ Slurm 無法分配 GPU
│   ├─ scontrol show node acmt-gpu | grep Gres
│   │   ├─ 應顯示: Gres=gpu:4
│   │   ├─ 無 Gres → gres.conf 遺失或不正確
│   │   └─ 檢查 gres.conf: cat /etc/slurm/gres.conf
│   │
│   ├─ 測試 GPU 分配
│   │   srun -p gpu --gres=gpu:1 --pty nvidia-smi
│   │
│   └─ 檢查 GPU job 正確語法
│       #SBATCH --gres=gpu:2  # 指定 2 張 GPU
│       #SBATCH --partition=gpu
│
└─ CUDA 環境
    ├─ nvcc --version (版本)
    ├─ ls -la /opt/cuda/
    └─ module avail | grep cuda (透過 Environment Modules)
```

---

## 7. InfiniBand 異常

### 決策樹

```
IB 網路不通或效能低落?
│
├─ ibstat
│   ├─ state: DOWN → 硬體或驅動問題
│   │   ├─ dmesg | grep -i mlx5
│   │   ├─ lspci | grep Mellanox (確認 PCI 裝置)
│   │   └─ 重啟 opensm: systemctl restart opensmd (acmt0)
│   │
│   └─ state: ACTIVE → 檢查 IP 設定
│       ├─ ip addr show ib0
│       │   └─ 應有 10.0.0.10/24 (acmt0)
│       │
│       └─ IB 節點間互通
│           ping 10.0.0.X (IB IP)
│
├─ ibnetdiscover
│   ├─ 交換機可見?
│   └─ 節點 LID 正確分配?
│
└─ 效能測試
    ib_write_bw -d mlx5_0
    # 預期: ~100 Gb/sec (EDR)
    # 若遠低於預期:
    ├─ 檢查 PCIe 速率: lspci -vvv -s af:00.0 | grep Speed
    ├─ 檢查 MTU: ip link show ib0 | grep mtu
    └─ 檢查纜線/收發器
```

---

## 8. 無法送出作業

```
sbatch job.sh 失敗?
│
├─ "Invalid account or account/partition combination specified"
│   ├─ 使用者未加入 Slurm
│   │   └─ python3 /root/acmt-ansible/scripts/slurm.py -u <username>
│   │
│   └─ 使用者不在群組 lab 中
│       └─ usermod -aG lab <username>
│
├─ "Invalid partition specified"
│   └─ squeue 確認分區名稱 (區分大小寫)
│
├─ "Too many jobs"
│   └─ QOS 限制，等待部分作業完成
│
└─ "Unable to contact slurm controller"
    └─ Slurmctld 異常 (見 2. Slurmctld 服務異常)
```

---

## 9. 日誌快速查詢

| 問題類型 | 日誌位置 | 查詢命令 |
|----------|----------|----------|
| Slurmctld 問題 | `/var/log/slurm/slurmctld.log` | `tail -100 /var/log/slurm/slurmctld.log` |
| Slurmd 問題 | `/var/log/slurm/slurmd.log` | `ssh acmtXX "tail -50 /var/log/slurm/slurmd.log"` |
| Slurmdbd 問題 | `/var/log/slurm/slurmdbd.log` | `tail -50 /var/log/slurm/slurmdbd.log` |
| Munge 認證問題 | `journalctl -u munge` | `journalctl -u munge -n 30 --no-pager` |
| 系統核心訊息 | `dmesg` | `dmesg \| tail -30` |
| 所有系統日誌 | `journalctl` | `journalctl -n 50 --no-pager` |
| NFS 問題 | `journalctl` | `journalctl -u home.mount -n 20` |
| GPU 驅動問題 | `dmesg` | `dmesg \| grep -i nvidia` |

---

## 10. 健康檢查腳本

以下腳本可一鍵檢查集群整體健康狀態。在 acmt0 執行：

```bash
#!/bin/bash
# acmt-healthcheck.sh — 集群健康檢查

echo "=== 1. Slurm Controller ==="
systemctl is-active slurmctld && echo "OK" || echo "FAIL"

echo "=== 2. Slurm DB Daemon ==="
systemctl is-active slurmdbd && echo "OK" || echo "FAIL"

echo "=== 3. Munge ==="
systemctl is-active munge && echo "OK" || echo "FAIL"

echo "=== 4. MySQL ==="
systemctl is-active mysql && echo "OK" || echo "FAIL"

echo "=== 5. Prometheus ==="
systemctl is-active prometheus && echo "OK" || echo "FAIL"

echo "=== 6. Grafana ==="
systemctl is-active grafana-server && echo "OK" || echo "FAIL"

echo "=== 7. Partition Status ==="
sinfo -o "%P|%a|%D|%t" --noheader

echo "=== 8. Node Status Count ==="
sinfo -o "%t" --noheader | sort | uniq -c

echo "=== 9. Job Queue Summary ==="
squeue -o "%T" --noheader | sort | uniq -c

echo "=== 10. Node Ping Test ==="
for node in acmt0{1..27} acmt-gpu acmt-storage acmt0; do
  ping -c 1 -W 2 $node >/dev/null 2>&1 \
    && echo "$node: OK" \
    || echo "$node: FAIL"
done

echo "=== 11. NFS Mount Check ==="
for node in acmt0{1..15} acmt{18..27} acmt-gpu; do
  ssh -o ConnectTimeout=3 $node "mount | grep -q nfs && echo '$node: OK' || echo '$node: FAIL'" 2>/dev/null \
    || echo "$node: UNREACHABLE"
done
```
