---
title: ACMT HPC Cluster — Ansible Runbook | ACMT HPC 集群 — Ansible Runbook
type: Operations
last_updated: 2026-05-22
source_of_truth: This file (procedures); `/root/acmt-ansible/ansible/` on acmt0 (actual deployed playbooks); https://github.com/AC-T-lab/acmt-ansible (canonical git repo, private)
---

# ACMT HPC Cluster — Ansible Runbook / ACMT HPC 集群 — Ansible Runbook

## Environment Overview / 環境概覽

- **Ansible working directory on headnode / 管理節點執行程式路徑:** `/root/acmt-ansible/ansible/`
- **Config file / 設定檔:** `ansible.cfg`
- **Inventory / 主機清單:** `hosts`
- **Roles directory / 角色目錄:** `roles/` (13 roles / 13 個角色)
- **Playbooks / Playbook 清單:**
  - `acmt.yml` — full deployment / 完整部署
  - `acmt-slurm.yml` — Slurm config only / 僅 Slurm 設定
  - `acmt-new-node.yml` — new node deployment / 新節點部署
  - `acmt-upgrade.yml` — system upgrade / 系統更新
  - `acmt-monitoring.yml` — monitoring stack deployment / 監控系統部署

---

## Common Pre-flight Checks / 通用前置檢查

Before running any playbook, always perform these checks:

在任何 playbook 執行前，一律執行：

```bash
# Switch to Ansible directory / 切換到 Ansible 目錄
cd /root/acmt-ansible/ansible

# Test connectivity / 測試連線
ansible acmt -m ping -o

# Expected output example / 預期結果範例:
# 192.168.1.10 | SUCCESS => {"ping": "pong"}
# 192.168.1.12 | SUCCESS => {"ping": "pong"}
# 192.168.1.19 | UNREACHABLE! => offline node (expected; see STATUS.md §1 for current offline nodes)

# Check unreachable nodes / 檢查無法連線的節點
ansible acmt -m ping -o 2>&1 | grep UNREACHABLE

# Run only against online nodes / 僅對在線節點執行
ansible acmt -m ping -o 2>&1 | grep SUCCESS | cut -d' ' -f1
```

**General notes / 通用注意事項:**
- Offline nodes (see STATUS.md §1 for current offline nodes) will report UNREACHABLE — this is expected / 離線節點會回報 UNREACHABLE，這是預期行為
- If an unexpected node is UNREACHABLE, run troubleshooting first / 若有非預期的 UNREACHABLE 節點，先執行故障排除
- The root SSH key must already be copied to all nodes / 需 root SSH 金鑰已複製到所有節點

---

## Playbook 1: `acmt.yml` — Full Cluster Deployment / 完整集群部署

### Purpose / 用途

Used when deploying the entire ACMT cluster for the first time. Installs all base packages, environment modules, NFS mounts, /etc/hosts, Slurm, LDAP client, and Docker.

首次部署整個 ACMT 集群時使用。安裝所有基礎套件、環境模組、NFS 掛載、/etc/hosts、Slurm、LDAP client、Docker。

### Role Execution Order / 執行角色順序

| Order / 順序 | Role / 角色 | Condition / 條件 | Purpose / 用途 |
|------|------|------|------|
| 1 | `base-package` | all / 全部 | Base packages (build-essential, git, mysql-server) / 基礎套件 |
| 2 | `env-modules` | all / 全部 | Environment Modules setup / Environment Modules 設定 |
| 3 | `nfs` | all / 全部 | NFS export (storage) + mount (others) / NFS export 與掛載 |
| 4 | `update_hosts` | all / 全部 | /etc/hosts IP mappings / /etc/hosts IP 對應 |
| 5 | `slurm` | all / 全部 | Slurm (slurmctld/slurmdbd on head, slurmd on others) / Slurm 完整部署 |
| 6 | `ldap-client` | non-head / 非 head | LDAP authentication (skips acmt0) / LDAP 認證（跳過 acmt0） |
| 7 | `docker` | non-storage / 非 storage | Docker + NVIDIA Container Toolkit (skips acmt-storage) / Docker 與 NVIDIA toolkit |

### Execution Command / 執行命令

```bash
ansible-playbook acmt.yml
```

### Expected Runtime / 預期執行時間
- First run / 首次: 15–30 minutes (depends on network speed and node count) / 15–30 分鐘
- Subsequent runs / 後續: 5–10 minutes (packages already installed) / 5–10 分鐘

### Pre-checks / 事前檢查

```bash
# 1. Verify all target nodes are online / 確認所有目標節點在線
ansible acmt -m ping

# 2. Verify NFS server (acmt-storage) is healthy / 確認 NFS 伺服器正常
ssh acmt-storage "hostname && df -h /home /opt"

# 3. Verify headnode MySQL is healthy / 確認管理節點 MySQL 正常
systemctl status mysql

# 4. Ensure no conflicting entries in hosts file / 確認 Hosts 檔案中無衝突
grep acmt /etc/hosts
```

### Post-checks / 事後驗證

```bash
# 1. NFS mount check / NFS 掛載檢查
ansible acmt -m shell -a "mount | grep nfs"

# 2. Slurm status / Slurm 狀態
sinfo
scontrol show nodes

# 3. LDAP authentication (non-head nodes) / LDAP 認證（非 head 節點）
ansible acmt -m shell -a "getent passwd | tail -5" --limit '!acmt0'

# 4. Docker (non-storage nodes) / Docker（非 storage 節點）
ansible acmt -m shell -a "docker --version" --limit '!acmt-storage'

# 5. Env Modules
ansible acmt -m shell -a "module avail 2>&1 | head -10"
```

### Known Issues / 已知問題與處理

| Issue / 問題 | Cause / 原因 | Handling / 處理方式 |
|------|------|----------|
| `mysql-server` install fails / 安裝失敗 | Non-head nodes don't install it — this is normal / 非 head 節點不會安裝，這是正常的 | No action needed / 無需處理 |
| `munge.key` permission error / 權限錯誤 | Non-head node missing munge.key / 非 head 節點缺少 munge.key | Copy manually / 手動複製: `scp /etc/munge/munge.key acmtXX:/etc/munge/` |
| Offline node errors / 離線節點錯誤 | see STATUS.md §1 for current offline nodes | Use `--limit` to exclude, or ignore errors / `--limit` 排除，或忽略錯誤 |

---

## Playbook 2: `acmt-slurm.yml` — Slurm Deployment/Update / Slurm 部署/更新

### Purpose / 用途

Updates Slurm configuration only. Use this playbook to publish changes to slurm.conf.

僅更新 Slurm 設定。修改 slurm.conf 後透過此 playbook 發布。

### Execution Command / 執行命令

```bash
ansible-playbook acmt-slurm.yml
```

### Pre-checks / 事前檢查

```bash
# 1. Verify slurm.conf syntax / 確認 slurm.conf 語法正確
slurmctld -t
# Returns "slurmctld: configuration ok" if correct / 回傳 slurmctld: configuration ok 表示正確

# 2. Verify slurmdbd.conf syntax / 確認 slurmdbd.conf 語法
slurmdbd -t

# 3. Capture current state / 記錄目前狀態
sinfo -N -l > /tmp/sinfo_before.txt
squeue -l > /tmp/squeue_before.txt
```

### Post-checks / 事後驗證

```bash
# 1. Service status / 服務狀態
systemctl status slurmctld
systemctl status slurmdbd
systemctl status slurmd  # each node / 各節點

# 2. Confirm Slurm is functioning / 確認 Slurm 正常運作
sinfo -N -l
scontrol show nodes | grep State

# 3. Diff before/after / 比對事前事後差異
diff /tmp/sinfo_before.txt <(sinfo -N -l)
```

### Notes / 注意事項
- If only `slurm.conf` changed, slurmctld auto-reloads (no restart needed) / 若有 `slurm.conf` 變更，slurmctld 會自動 reload（不需要 restart）
- Restarting slurmd on non-head nodes briefly interrupts jobs on that node / 非 head 節點的 slurmd 重啟會短暫中斷該節點的作業
- Recommended to run when no jobs are running / 建議在無作業運行時執行

---

## Playbook 3: `acmt-new-node.yml` — New Node Deployment / 新節點部署

### Purpose / 用途

Used when adding a new compute node to the cluster.

新增計算節點到集群時使用。

<callout icon="⚠️" color="yellow_bg">
**`acmt-new-node.yml` is currently identical to `acmt.yml`** (the two files are line-for-line the same) — they execute the same 7 roles. Recommendation: just scope with `-l acmtXX` to limit to the new node, or differentiate the two files later (e.g., have new-node also bootstrap nvidia driver / infiniband). Tracked in STATUS.md ISS-CFG-NEWNODE.

**目前 `acmt-new-node.yml` 與 `acmt.yml` 完全相同**（兩份檔案逐行一致）— 它們執行完全相同的 7 個角色。建議透過 `-l acmtXX` 限定新節點即可，或日後分化兩份檔案（例如 new-node 加入 nvidia driver / infiniband bootstrap）。追蹤於 STATUS.md ISS-CFG-NEWNODE。
</callout>

### Prerequisites / 前置作業

```bash
# 1. Verify new node has Ubuntu 22.04 and is reachable / 確認新節點已安裝 Ubuntu 22.04 且可連線
ping acmtXX
ssh acmtXX "hostname && cat /etc/os-release | grep VERSION"

# 2. Copy SSH key (if not already set up) / 複製 SSH 金鑰（若尚未設定）
ssh-copy-id root@acmtXX

# 3. Update Ansible hosts file (if IP not in range) / 更新 Ansible hosts 檔案
vim /root/acmt-ansible/ansible/hosts

# 4. Confirm new node added to slurm.conf (if needed) / 確認新節點已加入 slurm.conf（若需要）
# Edit roles/slurm/files/slurm.conf and add NodeName / 編輯 roles/slurm/files/slurm.conf 新增 NodeName
```

### Execution Command / 執行命令

```bash
# Run only against the new node / 僅對新節點執行
ansible-playbook acmt-new-node.yml -l acmtXX

# For multiple new nodes / 若有多台新節點
ansible-playbook acmt-new-node.yml -l "acmtXX,acmtYY"
```

### Post-checks / 事後驗證

```bash
# 1. Slurm recognizes new node / Slurm 識別新節點
scontrol show node acmtXX

# 2. Node state should be IDLE / 節點狀態應為 IDLE
sinfo -N -l | grep acmtXX

# 3. NFS mount / NFS 掛載
ansible acmtXX -m shell -a "df -h /home /opt"

# 4. Correct CPUs and memory / 核心與記憶體正確
scontrol show node acmtXX | grep -E "CPUs|RealMemory"
```

### Known Issues / 已知問題
- If the new node's hardware model differs, manually edit `slurm.conf` hardware params (CPUs, RealMemory, ThreadsPerCore) / 若節點型號不同，需手動編輯 `slurm.conf` 的硬體參數
- If the `update_hosts` role's `ip_host_mappings` lacks the new node, add it manually / `update_hosts` 角色中的 `ip_host_mappings` 若缺少新節點，需手動補上

---

## Playbook 4: `acmt-upgrade.yml` — System Upgrade / 系統更新

### Purpose / 用途

Runs `apt upgrade` on all nodes.

對所有節點執行 `apt upgrade`。

### Execution Command / 執行命令

```bash
ansible-playbook acmt-upgrade.yml
```

### Pre-checks / 事前檢查

```bash
# 1. Verify no important jobs are running / 確認無重要作業在執行
squeue -t RUNNING

# 2. Verify sufficient disk space (upgrade needs > 2GB free) / 確認磁碟空間充足
ansible acmt -m shell -a "df -h / | tail -1"
```

### Post-checks / 事後驗證

```bash
# 1. Verify package upgrade is complete / 確認套件更新完成
ansible acmt -m shell -a "apt list --upgradable 2>/dev/null | wc -l"
# Should return 1 (header only, no upgradable packages) / 應回傳 1（只有 header, 沒有可更新套件）

# 2. Check whether a reboot is required / 確認需要重新開機
ansible acmt -m shell -a "[ -f /var/run/reboot-required ] && echo REBOOT || echo OK"

# 3. If a reboot is needed / 若需要重新開機
# Use the Slurm maintenance procedure to do a rolling restart / 使用 Slurm 維護程序執行滾動重啟
```

### Notes / 注意事項
- Kernel updates may require a reboot / 核心更新可能需要重新開機
- A reboot interrupts jobs running on that node / 重新開機會中斷該節點上的作業
- Recommended to drain the node before rebooting / 建議使用 Drain 後再重啟

---

## Playbook 5: `acmt-monitoring.yml` — Monitoring Stack Deployment / 監控系統部署

### Purpose / 用途

Deploys Prometheus + Grafana + Node Exporters + Slurm Exporter. For alert rules, dashboard list, and known monitoring gaps see [monitoring-alerting.md](monitoring-alerting.md); current open alerts/service issues see [STATUS.md §1.2](STATUS.md).

部署 Prometheus + Grafana + Node Exporters + Slurm Exporter。告警規則、dashboard 列表與已知監控 gap 見 [monitoring-alerting.md](monitoring-alerting.md)；當前未解告警/服務問題見 [STATUS.md §1.2](STATUS.md)。

### Role Execution Order / 執行角色順序

| Order / 順序 | Role / 角色 | Condition / 條件 | Purpose / 用途 |
|------|------|------|------|
| 1 | `node_exporter` | all / 全部 | Installed on every node (port 9100) / 每節點安裝 |
| 2 | `slurm_exporter` | head only / 僅 head | Slurm metrics (port 8080) / Slurm 指標 |
| 3 | `prometheus` | head only / 僅 head | Prometheus + Grafana |

### Execution Command / 執行命令

```bash
ansible-playbook acmt-monitoring.yml
```

### Pre-checks / 事前檢查

```bash
# 1. Verify Go is installed (slurm_exporter needs to compile) / 確認 Go 已安裝
which go || echo "Go not found"
```

### Post-checks / 事後驗證

```bash
# 1. Node Exporter (all nodes) / Node Exporter（所有節點）
ansible acmt -m shell -a "curl -s http://localhost:9100/metrics | head -5"

# 2. Slurm Exporter (head only) / Slurm Exporter（僅 head）
curl -s http://localhost:8080/metrics | head -5

# 3. Prometheus
curl -s http://localhost:9090/api/v1/query?query=up

# 4. Grafana
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Should return 200 or 302 / 應回傳 200 或 302

# 5. Prometheus target status / Prometheus Target 狀態
curl -s http://localhost:9090/api/v1/targets | python3 -c "import sys,json; d=json.load(sys.stdin); [print(t['labels']['instance'], t['health']) for t in d['data']['activeTargets']]"
```

### Known Issues / 已知問題
- `slurm_exporter` needs to download source from GitHub and compile — make sure acmt0 has internet access / `slurm_exporter` 需要從 GitHub 下載 Source 並編譯，需確保 acmt0 有網路連線
- The target list in `prometheus.yml.j2` is static — must be manually updated when adding new nodes / `prometheus.yml.j2` 中的目標節點列表為靜態，新增節點後須手動更新

---

## Running a Single Role / 角色獨立執行

To run an individual role without the full playbook:

若需單獨執行某個角色而不跑整個 playbook：

```bash
# Basic syntax / 基本語法
ansible acmt -m include_role -a name=<role_name>

# Example: only update slurm config / 範例: 僅更新 slurm 設定
ansible acmt -m include_role -a name=slurm

# Example: only update LDAP config / 範例: 僅更新 LDAP 設定
ansible acmt -m include_role -a name=ldap-client

# Limit to a specific node / 限制特定節點
ansible acmt -m include_role -a name=nfs -l acmt03
```

---

## Role Reference / 角色詳情速查

The `roles/` directory holds 13 roles in total. The **Used by Playbook** column reflects a 2026-05-22 scan of `/root/acmt-ansible/ansible/*.yml`.

依實際 `roles/` 目錄共 13 個角色。**Playbook 是否使用**欄位反映 2026-05-22 對 `/root/acmt-ansible/ansible/*.yml` 的掃描結果。

| Role / 角色 | Function / 功能摘要 | Key vars/files / 關鍵變數/檔案 | Used by Playbook / Playbook 是否使用 |
|------|----------|---------------|----------|
| `base-package` | Base packages + MySQL (head) + Ansys deps + libldap 2.4 backport / 基礎套件 + MySQL (head) + Ansys deps + libldap 2.4 backport | no vars / 無變數 | acmt.yml, acmt-new-node.yml |
| `env-modules` | Environment Modules + `/etc/profile.d/modules.sh` | files/modules.sh | acmt.yml, acmt-new-node.yml |
| `nfs` | NFS export (storage node) + mount (other nodes) / NFS export 與掛載 | `nfs_network`, `nfs_home_server`, templates: `home.mount`, `opt.mount` | acmt.yml, acmt-new-node.yml |
| `update_hosts` | /etc/hosts management; **currently covers only acmt0/storage/01-15/gpu (18 entries)** / **目前只涵蓋 acmt0/storage/01-15/gpu（18 筆）** | `ip_host_mappings` (vars/main.yml) | acmt.yml, acmt-new-node.yml |
| `slurm` | Full Slurm install + munge key + slurm DB user / Slurm 完整安裝設定 + munge key + slurm DB user | files: `slurm.conf`, `slurmdbd.conf`, `gres.conf`, `cgroup.conf` | acmt.yml, acmt-new-node.yml, acmt-slurm.yml |
| `ldap-client` | LDAP auth (server 192.168.1.10, base `dc=acmt`) / LDAP 認證（伺服器 192.168.1.10，base `dc=acmt`） | files: `nslcd.conf`, `nsswitch.conf`, `common-password`, `ldap.conf`, **`ldap.secret` (mode 0600)** | acmt.yml, acmt-new-node.yml (when `not head`) |
| `docker` | Docker CE + NVIDIA Container Toolkit repo | no vars / 無變數 | acmt.yml, acmt-new-node.yml (when `not storage`) |
| `apt-upgrade` | `apt upgrade` (one-day cache valid) | none / 無 | acmt-upgrade.yml |
| `node_exporter` | Prometheus Node Exporter (port 9100) | `node_exporter_version: 1.8.2` | acmt-monitoring.yml |
| `slurm_exporter` | Prometheus Slurm Exporter (port 8080, compiled from source) / Prometheus Slurm Exporter（從 source 編譯） | `slurm_exporter_version: 0.20`, `slurm_exporter_port: 8080` | acmt-monitoring.yml (head only) |
| `prometheus` | Prometheus v2.53.1 (with 24 hardcoded node_exporter targets) / Prometheus v2.53.1（含 24 個 hardcoded node_exporter target） | template: `prometheus.yml.j2` | acmt-monitoring.yml (head only) |
| `infiniband` | Only `apt install rdma-core` + `opensm` (head only) / 僅 `apt install rdma-core` + `opensm`（head only） | none / 無 | **Not used in any playbook (manual run) / 未在任何 playbook（手動執行）** |
| `nvidia.nvidia_driver` | Full NVIDIA driver install (Galaxy role) / NVIDIA 驅動完整安裝（Galaxy role） | `nvidia_driver_branch: 515`, `nvidia_driver_persistence_mode_on` | **Not used in any playbook (manual run) / 未在任何 playbook（手動執行）** |

---

## Full New-Node SOP / 新增節點完整流程 (SOP)

```bash
# Step 1: Verify OS installed and network configured on new node / 確認新節點已安裝 OS 並設定網路
ping acmtXX
ssh-copy-id root@acmtXX

# Step 2: Edit slurm.conf (if hardware spec differs) / 編輯 slurm.conf（若硬體規格不同）
vim /root/acmt-ansible/ansible/roles/slurm/files/slurm.conf

# Step 3: Edit update_hosts vars (if IP not in current list) / 編輯 update_hosts 變數（若 IP 不在現有清單）
vim /root/acmt-ansible/ansible/roles/update_hosts/vars/main.yml

# Step 4: Edit inventory (if IP range doesn't cover it) / 編輯 hosts（若 IP 範圍不涵蓋）
vim /root/acmt-ansible/ansible/hosts

# Step 5: Edit prometheus targets (if monitoring required) / 編輯 prometheus targets（若需納入監控）
vim /root/acmt-ansible/ansible/roles/prometheus/templates/prometheus.yml.j2

# Step 6: Run full deployment / 執行完整部署
ansible-playbook acmt-new-node.yml -l acmtXX

# Step 7: Verify / 驗證
scontrol show node acmtXX
sinfo -N -l | grep acmtXX
```

---

## Known Gaps / Reality Check

A deep review of `/root/acmt-ansible/` on 2026-05-22 surfaced the following gaps (tracked in STATUS.md ISS-CFG-NN):

2026-05-22 對 `/root/acmt-ansible/` 深度檢視後發現以下落差（追蹤於 STATUS.md ISS-CFG-NN）：

### 1. `update_hosts` vars incomplete — `ISS-CFG-HOSTS` / `update_hosts` vars 不完整

- `roles/update_hosts/vars/main.yml`'s `ip_host_mappings` contains only acmt0, acmt-storage, acmt01–15, acmt-gpu (18 entries total).
- The live `/etc/hosts` already contains acmt16–27 (10 additional entries) — these must have been added via another route.
- **Impact**: Running `acmt-new-node.yml` against acmt16+ nodes won't sync hosts; if a newly added node isn't in vars, the cluster-wide `/etc/hosts` won't be updated either.
- **Fix**: Add all nodes to `vars/main.yml`, or switch to generating hosts dynamically from inventory.

- `roles/update_hosts/vars/main.yml` 的 `ip_host_mappings` 僅含 acmt0、acmt-storage、acmt01–15、acmt-gpu（共 18 筆）
- 實際 `/etc/hosts` 已含 acmt16–27（10 筆額外）— 應由其他途徑加入
- **影響**：跑 `acmt-new-node.yml` 對 acmt16+ 節點不會同步 hosts；新增的節點若不在 vars 中，整個叢集的 `/etc/hosts` 也不會更新
- **修補**：在 `vars/main.yml` 補齊所有節點，或改用 inventory 自動生成

### 2. `prometheus.yml.j2` target list skips offline nodes — `ISS-CFG-PROMTGT` / target 名單跳過離線節點

- The template hardcodes 24 `node_exporter` targets and **explicitly skips acmt16 (192.168.1.27) and acmt17 (192.168.1.28)**.
- **Impact**: Even if acmt16/17 come back online, Prometheus won't automatically monitor them — you must edit the template first and rerun the playbook.
- **Fix**: Use the inventory to generate targets dynamically (via the `ansible-inventory` plugin), or periodically rerun `acmt-monitoring.yml` while maintaining the target list.

- 模板中硬編碼 24 個 `node_exporter` target，且**直接跳過 acmt16（192.168.1.27）與 acmt17（192.168.1.28）**
- **影響**：即使 acmt16/17 復原，Prometheus 也不會自動納入監控 — 必須先編輯模板再 rerun playbook
- **修補**：改用 inventory 動態生成 targets（`ansible-inventory` plugin），或定期重跑 `acmt-monitoring.yml` 並維護 target 清單

### 3. `gres.conf` and `slurm.conf` GPU count mismatch — `ISS-CFG-GRES` / `gres.conf` 與 `slurm.conf` GPU 數量不一致

- `slurm.conf`: `NodeName=acmt-gpu ... Gres=gpu:4`
- `gres.conf`: `NodeName=acmt-gpu Name=gpu File=/dev/nvidia[0-1]` — **only 2 GPUs declared**.
- **Impact**: Slurm thinks 4 GPUs are schedulable, but cgroup can only properly isolate 2 — jobs landing on GPU 3 or 4 start without a device file and may silently fail or share a GPU.
- **Fix**: Change `gres.conf` to `File=/dev/nvidia[0-3]` (if there really are 4 physical GPUs), or change `slurm.conf`'s `Gres=gpu:4` back to `gpu:2` (verify actual hardware configuration first).

- `slurm.conf`: `NodeName=acmt-gpu ... Gres=gpu:4`
- `gres.conf`: `NodeName=acmt-gpu Name=gpu File=/dev/nvidia[0-1]` — **只宣告 2 顆**
- **影響**：Slurm 認為有 4 顆 GPU 可調度，但 cgroup 只能正確隔離 2 顆 — 第 3、4 顆作業會在沒有 device file 的情況下啟動，可能 silently fail 或共享 GPU
- **修補**：把 `gres.conf` 改為 `File=/dev/nvidia[0-3]`（若真有 4 顆物理 GPU），或把 `slurm.conf` 的 `Gres=gpu:4` 改回 `gpu:2`（需先確認實際硬體配置）

### 4. `infiniband` and `nvidia.nvidia_driver` roles not in any playbook / 未在任何 playbook

- Both roles exist under `roles/` but are not referenced by any `*.yml`.
- This means **IB subnet management (opensm) and NVIDIA driver install are both manual**.
- New GPU nodes deployed via `acmt-new-node.yml` won't get the driver installed automatically; you must manually run `ansible <node> -m include_role -a name=nvidia.nvidia_driver`.

- 兩個 role 都存在於 `roles/` 但不被任何 `*.yml` 引用
- 意味著 **IB 子網路管理 (opensm) 與 NVIDIA driver 安裝都是手動執行**
- 新 GPU 節點透過 `acmt-new-node.yml` 部署後不會自動安裝 driver；要手動跑 `ansible <node> -m include_role -a name=nvidia.nvidia_driver`

### 5. `update-table` script is dead code / `update-table` 腳本是 dead code

- `/root/acmt-ansible/update-table` (top-level) hardcodes `host_roles = {'apollo': dict(), 'hades': dict()}`.
- The actual inventory only has the `[acmt]` group — running this script writes an empty table into the README.
- **Fix**: Either rewrite the script to support `acmt`, or delete it.

- `/root/acmt-ansible/update-table` (top-level) 硬編碼 `host_roles = {'apollo': dict(), 'hades': dict()}`
- 實際 inventory 只有 `[acmt]` group — 跑這支腳本會在 README 寫入空表
- **修補**：要嘛改寫腳本以支援 `acmt`，要嘛刪除

### 6. `nfs` exports use `no_root_squash` — `ISS-SEC-NFS`

- `nfs/tasks/main.yml`: `/home {{ nfs_network }}(rw,no_root_squash,async)`, with the same setting for `/opt`.
- Any compute node's root has full read/write to NFS — a security concern (already documented in [security-policy.md §6](security-policy.md)).

- `nfs/tasks/main.yml`：`/home {{ nfs_network }}(rw,no_root_squash,async)` 同樣設定於 `/opt`
- 任何 compute node 的 root 可對 NFS 完全讀寫 — 安全議題（[security-policy.md §6](security-policy.md) 已記錄）

### 7. `slurm` role always uses `restart`, never `reload` / `slurm` role 一律 `restart` 而非 `reload`

- `slurmctld`, `slurmdbd`, and `slurmd` all use `state: restarted` — every playbook run kicks off any currently executing jobs.
- **Fix**: For `slurm.conf`-only changes, use `scontrol reconfigure` instead of restart; compute-node `slurmd` is the only thing that needs an actual restart.

- `slurmctld`、`slurmdbd`、`slurmd` 全部使用 `state: restarted` — 每次 playbook 跑都會踢掉執行中的 jobs
- **修補**：對於只改 `slurm.conf` 的情況，使用 `scontrol reconfigure` 而非 restart；compute node 的 `slurmd` 才需要 restart
