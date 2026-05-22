---
title: ACMT HPC Cluster — Ansible Runbook
type: Operations
last_updated: 2026-05-22
source_of_truth: This file (procedures); `/root/acmt-ansible/ansible/` on acmt0 (actual deployed playbooks); https://github.com/AC-T-lab/acmt-ansible (canonical git repo, private)
---

# ACMT HPC Cluster — Ansible Runbook

## 環境概覽

- **管理節點執行程式路徑:** `/root/acmt-ansible/ansible/`
- **設定檔:** `ansible.cfg`
- **主機清單:** `hosts`
- **角色目錄:** `roles/` (13 個角色)
- **Playbook 清單:**
  - `acmt.yml` — 完整部署
  - `acmt-slurm.yml` — 僅 Slurm 設定
  - `acmt-new-node.yml` — 新節點部署
  - `acmt-upgrade.yml` — 系統更新
  - `acmt-monitoring.yml` — 監控系統部署

---

## 通用前置檢查

在任何 playbook 執行前，一律執行：

```bash
# 切換到 Ansible 目錄
cd /root/acmt-ansible/ansible

# 測試連線
ansible acmt -m ping -o

# 預期結果範例:
# 192.168.1.10 | SUCCESS => {"ping": "pong"}
# 192.168.1.12 | SUCCESS => {"ping": "pong"}
# 192.168.1.19 | UNREACHABLE! => 離線節點 (正常現象；see STATUS.md §1 for current offline nodes)

# 檢查無法連線的節點
ansible acmt -m ping -o 2>&1 | grep UNREACHABLE

# 僅對在線節點執行
ansible acmt -m ping -o 2>&1 | grep SUCCESS | cut -d' ' -f1
```

**通用注意事項:**
- 離線節點 (see STATUS.md §1 for current offline nodes) 會回報 UNREACHABLE，這是預期行為
- 若有非預期的 UNREACHABLE 節點，先執行故障排除
- 需 root SSH 金鑰已複製到所有節點

---

## Playbook 1: `acmt.yml` — 完整集群部署

### 用途
首次部署整個 ACMT 集群時使用。安裝所有基礎套件、環境模組、NFS 掛載、/etc/hosts、Slurm、LDAP client、Docker。

### 執行角色順序

| 順序 | 角色 | 條件 | 用途 |
|------|------|------|------|
| 1 | `base-package` | 全部 | 基礎套件 (build-essential, git, mysql-server) |
| 2 | `env-modules` | 全部 | Environment Modules 設定 |
| 3 | `nfs` | 全部 | NFS export (storage) + mount (其他節點) |
| 4 | `update_hosts` | 全部 | /etc/hosts IP 對應 |
| 5 | `slurm` | 全部 | Slurm (slurmctld/slurmdbd on head, slurmd on others) |
| 6 | `ldap-client` | 非 head | LDAP 認證 (跳過 acmt0) |
| 7 | `docker` | 非 storage | Docker + NVIDIA Container Toolkit (跳過 acmt-storage) |

### 執行命令

```bash
ansible-playbook acmt.yml
```

### 預期執行時間
- 首次: 15–30 分鐘 (取決於網路速度與節點數)
- 後續: 5–10 分鐘 (套件已安裝)

### 事前檢查

```bash
# 1. 確認所有目標節點在線
ansible acmt -m ping

# 2. 確認 NFS 伺服器 (acmt-storage) 正常
ssh acmt-storage "hostname && df -h /home /opt"

# 3. 確認管理節點 MySQL 正常
systemctl status mysql

# 4. 確認 Hosts 檔案中無衝突
grep acmt /etc/hosts
```

### 事後驗證

```bash
# 1. NFS 掛載檢查
ansible acmt -m shell -a "mount | grep nfs"

# 2. Slurm 狀態
sinfo
scontrol show nodes

# 3. LDAP 認證 (非 head 節點)
ansible acmt -m shell -a "getent passwd | tail -5" --limit '!acmt0'

# 4. Docker (非 storage 節點)
ansible acmt -m shell -a "docker --version" --limit '!acmt-storage'

# 5. Env Modules
ansible acmt -m shell -a "module avail 2>&1 | head -10"
```

### 已知問題與處理

| 問題 | 原因 | 處理方式 |
|------|------|----------|
| `mysql-server` 安裝失敗 | 非 head 節點不會安裝，這是正常的 | 無需處理 |
| `munge.key` 權限錯誤 | 非 head 節點缺少 munge.key | 手動複製: `scp /etc/munge/munge.key acmtXX:/etc/munge/` |
| 離線節點錯誤 | see STATUS.md §1 for current offline nodes | `--limit` 排除，或忽略錯誤 |

---

## Playbook 2: `acmt-slurm.yml` — Slurm 部署/更新

### 用途
僅更新 Slurm 設定。修改 slurm.conf 後透過此 playbook 發布。

### 執行命令

```bash
ansible-playbook acmt-slurm.yml
```

### 事前檢查

```bash
# 1. 確認 slurm.conf 語法正確
slurmctld -t
# 回傳 slurmctld: configuration ok 表示正確

# 2. 確認 slurmdbd.conf 語法
slurmdbd -t

# 3. 記錄目前狀態
sinfo -N -l > /tmp/sinfo_before.txt
squeue -l > /tmp/squeue_before.txt
```

### 事後驗證

```bash
# 1. 服務狀態
systemctl status slurmctld
systemctl status slurmdbd
systemctl status slurmd  # 各節點

# 2. 確認 Slurm 正常運作
sinfo -N -l
scontrol show nodes | grep State

# 3. 比對事前事後差異
diff /tmp/sinfo_before.txt <(sinfo -N -l)
```

### 注意事項
- 若有 `slurm.conf` 變更，slurmctld 會自動 reload (不需要 restart)
- 非 head 節點的 slurmd 重啟會短暫中斷該節點的作業
- 建議在無作業運行時執行

---

## Playbook 3: `acmt-new-node.yml` — 新節點部署

### 用途
新增計算節點到集群時使用。

<callout icon="⚠️" color="yellow_bg">
**目前 `acmt-new-node.yml` 與 `acmt.yml` 完全相同**（兩份檔案逐行一致）— 它們執行完全相同的 7 個角色。建議透過 `-l acmtXX` 限定新節點即可，或日後分化兩份檔案（例如 new-node 加入 nvidia driver / infiniband bootstrap）。追蹤於 STATUS.md ISS-CFG-NEWNODE。
</callout>

### 前置作業

```bash
# 1. 確認新節點已安裝 Ubuntu 22.04 且可連線
ping acmtXX
ssh acmtXX "hostname && cat /etc/os-release | grep VERSION"

# 2. 複製 SSH 金鑰 (若尚未設定)
ssh-copy-id root@acmtXX

# 3. 更新 Ansible hosts 檔案 (若 IP 不在範圍內)
vim /root/acmt-ansible/ansible/hosts

# 4. 確認新節點已加入 slurm.conf (若需要)
# 編輯 roles/slurm/files/slurm.conf 新增 NodeName
```

### 執行命令

```bash
# 僅對新節點執行
ansible-playbook acmt-new-node.yml -l acmtXX

# 若有多台新節點
ansible-playbook acmt-new-node.yml -l "acmtXX,acmtYY"
```

### 事後驗證

```bash
# 1. Slurm 識別新節點
scontrol show node acmtXX

# 2. 節點狀態應為 IDLE
sinfo -N -l | grep acmtXX

# 3. NFS 掛載
ansible acmtXX -m shell -a "df -h /home /opt"

# 4. 核心與記憶體正確
scontrol show node acmtXX | grep -E "CPUs|RealMemory"
```

### 已知問題
- 若節點型號不同，需手動編輯 `slurm.conf` 的硬體參數 (CPUs, RealMemory, ThreadsPerCore)
- `update_hosts` 角色中的 `ip_host_mappings` 若缺少新節點，需手動補上

---

## Playbook 4: `acmt-upgrade.yml` — 系統更新

### 用途
對所有節點執行 `apt upgrade`。

### 執行命令

```bash
ansible-playbook acmt-upgrade.yml
```

### 事前檢查

```bash
# 1. 確認無重要作業在執行
squeue -t RUNNING

# 2. 確認磁碟空間充足 (更新需要 > 2GB 可用)
ansible acmt -m shell -a "df -h / | tail -1"
```

### 事後驗證

```bash
# 1. 確認套件更新完成
ansible acmt -m shell -a "apt list --upgradable 2>/dev/null | wc -l"
# 應回傳 1 (只有 header, 沒有可更新套件)

# 2. 確認需要重新開機
ansible acmt -m shell -a "[ -f /var/run/reboot-required ] && echo REBOOT || echo OK"

# 3. 若需要重新開機
# 使用 Slurm 維護程序執行滾動重啟
```

### 注意事項
- 核心更新可能需要重新開機
- 重新開機會中斷該節點上的作業
- 建議使用 Drain 後再重啟

---

## Playbook 5: `acmt-monitoring.yml` — 監控系統部署

### 用途
部署 Prometheus + Grafana + Node Exporters + Slurm Exporter。告警規則、dashboard 列表與已知監控 gap 見 [monitoring-alerting.md](monitoring-alerting.md)；當前未解告警/服務問題見 [STATUS.md §1.2](STATUS.md)。

### 執行角色順序

| 順序 | 角色 | 條件 | 用途 |
|------|------|------|------|
| 1 | `node_exporter` | 全部 | 每節點安裝 (port 9100) |
| 2 | `slurm_exporter` | head only | Slurm 指標 (port 8080) |
| 3 | `prometheus` | head only | Prometheus + Grafana |

### 執行命令

```bash
ansible-playbook acmt-monitoring.yml
```

### 事前檢查

```bash
# 1. 確認 Go 已安裝 (slurm_exporter 需要編譯)
which go || echo "Go not found"
```

### 事後驗證

```bash
# 1. Node Exporter (所有節點)
ansible acmt -m shell -a "curl -s http://localhost:9100/metrics | head -5"

# 2. Slurm Exporter (僅 head)
curl -s http://localhost:8080/metrics | head -5

# 3. Prometheus
curl -s http://localhost:9090/api/v1/query?query=up

# 4. Grafana
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# 應回傳 200 或 302

# 5. Prometheus Target 狀態
curl -s http://localhost:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); [print(t['labels']['instance'], t['health']) for t in d['data']['activeTargets']]"
```

### 已知問題
- `slurm_exporter` 需要從 GitHub 下載 Source 並編譯，需確保 acmt0 有網路連線
- `prometheus.yml.j2` 中的目標節點列表為靜態，新增節點後須手動更新

---

## 角色獨立執行

若需單獨執行某個角色而不跑整個 playbook：

```bash
# 基本語法
ansible acmt -m include_role -a name=<role_name>

# 範例: 僅更新 slurm 設定
ansible acmt -m include_role -a name=slurm

# 範例: 僅更新 LDAP 設定
ansible acmt -m include_role -a name=ldap-client

# 限制特定節點
ansible acmt -m include_role -a name=nfs -l acmt03
```

---

## 角色詳情速查

依實際 `roles/` 目錄共 13 個角色。**Playbook 是否使用**欄位反映 2026-05-22 對 `/root/acmt-ansible/ansible/*.yml` 的掃描結果。

| 角色 | 功能摘要 | 關鍵變數/檔案 | Playbook 是否使用 |
|------|----------|---------------|----------|
| `base-package` | 基礎套件 + MySQL (head) + Ansys deps + libldap 2.4 backport | 無變數 | acmt.yml, acmt-new-node.yml |
| `env-modules` | Environment Modules + `/etc/profile.d/modules.sh` | files/modules.sh | acmt.yml, acmt-new-node.yml |
| `nfs` | NFS export (storage 節點) + mount (其他節點) | `nfs_network`, `nfs_home_server`, templates: `home.mount`, `opt.mount` | acmt.yml, acmt-new-node.yml |
| `update_hosts` | /etc/hosts 管理；**目前只涵蓋 acmt0/storage/01-15/gpu（18 筆）** | `ip_host_mappings` (vars/main.yml) | acmt.yml, acmt-new-node.yml |
| `slurm` | Slurm 完整安裝設定 + munge key + slurm DB user | files: `slurm.conf`, `slurmdbd.conf`, `gres.conf`, `cgroup.conf` | acmt.yml, acmt-new-node.yml, acmt-slurm.yml |
| `ldap-client` | LDAP 認證 (伺服器 192.168.1.10, base `dc=acmt`) | files: `nslcd.conf`, `nsswitch.conf`, `common-password`, `ldap.conf`, **`ldap.secret` (mode 0600)** | acmt.yml, acmt-new-node.yml (when `not head`) |
| `docker` | Docker CE + NVIDIA Container Toolkit repo | 無變數 | acmt.yml, acmt-new-node.yml (when `not storage`) |
| `apt-upgrade` | `apt upgrade` (one-day cache valid) | 無 | acmt-upgrade.yml |
| `node_exporter` | Prometheus Node Exporter (port 9100) | `node_exporter_version: 1.8.2` | acmt-monitoring.yml |
| `slurm_exporter` | Prometheus Slurm Exporter (port 8080，從 source 編譯) | `slurm_exporter_version: 0.20`, `slurm_exporter_port: 8080` | acmt-monitoring.yml (head only) |
| `prometheus` | Prometheus v2.53.1 (含 24 個 hardcoded node_exporter target) | template: `prometheus.yml.j2` | acmt-monitoring.yml (head only) |
| `infiniband` | 僅 `apt install rdma-core` + `opensm` (head only) | 無 | **未在任何 playbook（手動執行）** |
| `nvidia.nvidia_driver` | NVIDIA 驅動完整安裝 (Galaxy role) | `nvidia_driver_branch: 515`, `nvidia_driver_persistence_mode_on` | **未在任何 playbook（手動執行）** |

---

## 新增節點完整流程 (SOP)

```bash
# Step 1: 確認新節點已安裝 OS 並設定網路
ping acmtXX
ssh-copy-id root@acmtXX

# Step 2: 編輯 slurm.conf (若硬體規格不同)
vim /root/acmt-ansible/ansible/roles/slurm/files/slurm.conf

# Step 3: 編輯 update_hosts 變數 (若 IP 不在現有清單)
vim /root/acmt-ansible/ansible/roles/update_hosts/vars/main.yml

# Step 4: 編輯 hosts (若 IP 範圍不涵蓋)
vim /root/acmt-ansible/ansible/hosts

# Step 5: 編輯 prometheus targets (若需納入監控)
vim /root/acmt-ansible/ansible/roles/prometheus/templates/prometheus.yml.j2

# Step 6: 執行完整部署
ansible-playbook acmt-new-node.yml -l acmtXX

# Step 7: 驗證
scontrol show node acmtXX
sinfo -N -l | grep acmtXX
```

---

## Known Gaps / Reality Check

2026-05-22 對 `/root/acmt-ansible/` 深度檢視後發現以下落差（追蹤於 STATUS.md ISS-CFG-NN）：

### 1. `update_hosts` vars 不完整 — `ISS-CFG-HOSTS`
- `roles/update_hosts/vars/main.yml` 的 `ip_host_mappings` 僅含 acmt0、acmt-storage、acmt01–15、acmt-gpu（共 18 筆）
- 實際 `/etc/hosts` 已含 acmt16–27（10 筆額外）— 應由其他途徑加入
- **影響**：跑 `acmt-new-node.yml` 對 acmt16+ 節點不會同步 hosts；新增的節點若不在 vars 中，整個叢集的 `/etc/hosts` 也不會更新
- **修補**：在 `vars/main.yml` 補齊所有節點，或改用 inventory 自動生成

### 2. `prometheus.yml.j2` target 名單跳過離線節點 — `ISS-CFG-PROMTGT`
- 模板中硬編碼 24 個 `node_exporter` target，且**直接跳過 acmt16（192.168.1.27）與 acmt17（192.168.1.28）**
- **影響**：即使 acmt16/17 復原，Prometheus 也不會自動納入監控 — 必須先編輯模板再 rerun playbook
- **修補**：改用 inventory 動態生成 targets（`ansible-inventory` plugin），或定期重跑 `acmt-monitoring.yml` 並維護 target 清單

### 3. `gres.conf` 與 `slurm.conf` GPU 數量不一致 — `ISS-CFG-GRES`
- `slurm.conf`: `NodeName=acmt-gpu ... Gres=gpu:4`
- `gres.conf`: `NodeName=acmt-gpu Name=gpu File=/dev/nvidia[0-1]` — **只宣告 2 顆**
- **影響**：Slurm 認為有 4 顆 GPU 可調度，但 cgroup 只能正確隔離 2 顆 — 第 3、4 顆作業會在沒有 device file 的情況下啟動，可能 silently fail 或共享 GPU
- **修補**：把 `gres.conf` 改為 `File=/dev/nvidia[0-3]`（若真有 4 顆物理 GPU），或把 `slurm.conf` 的 `Gres=gpu:4` 改回 `gpu:2`（需先確認實際硬體配置）

### 4. `infiniband` 與 `nvidia.nvidia_driver` roles 未在任何 playbook
- 兩個 role 都存在於 `roles/` 但不被任何 `*.yml` 引用
- 意味著 **IB 子網路管理 (opensm) 與 NVIDIA driver 安裝都是手動執行**
- 新 GPU 節點透過 `acmt-new-node.yml` 部署後不會自動安裝 driver；要手動跑 `ansible <node> -m include_role -a name=nvidia.nvidia_driver`

### 5. `update-table` 腳本是 dead code
- `/root/acmt-ansible/update-table` (top-level) 硬編碼 `host_roles = {'apollo': dict(), 'hades': dict()}`
- 實際 inventory 只有 `[acmt]` group — 跑這支腳本會在 README 寫入空表
- **修補**：要嘛改寫腳本以支援 `acmt`，要嘛刪除

### 6. `nfs` exports 為 `no_root_squash` — `ISS-SEC-NFS`
- `nfs/tasks/main.yml`：`/home {{ nfs_network }}(rw,no_root_squash,async)` 同樣設定於 `/opt`
- 任何 compute node 的 root 可對 NFS 完全讀寫 — 安全議題（[security-policy.md §6](security-policy.md) 已記錄）

### 7. `slurm` role 一律 `restart` 而非 `reload`
- `slurmctld`、`slurmdbd`、`slurmd` 全部使用 `state: restarted` — 每次 playbook 跑都會踢掉執行中的 jobs
- **修補**：對於只改 `slurm.conf` 的情況，使用 `scontrol reconfigure` 而非 restart；compute node 的 `slurmd` 才需要 restart

