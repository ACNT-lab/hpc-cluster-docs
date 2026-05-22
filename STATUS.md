---
title: ACMT Cluster — Live State & Tracked Issues
type: State
last_updated: 2026-05-22
last_live_scan: 2026-05-22 (ssh admin)
source_of_truth: This file (for issues/TODOs); `acmt`/`sinfo`/`squeue` (for live runtime data)
---

# ACMT HPC Cluster — Status

> 本檔追蹤 **跨會話需保留的 cluster state**：未解的已知問題、待辦事項、與動態資料的取得指令。
>
> **設計原則**
> - **不寫死當前節點/作業/佔用率快照** — 這些用指令動態抓取（見 §3）。
> - **只記錄需被追蹤的事**：尚未解決的 issue、待辦、跨會話有意義的觀察。
> - **每筆 issue 都標 `TODO:`** — 含目標狀態與下一步動作。
> - 解決後請移至 [maintenance-log.md](maintenance-log.md) 並從此處刪除；批次處理流程見 [ansible-runbook.md](ansible-runbook.md)。

---

## 1. Known Issues (Open)

### 1.1 節點離線 / 異常

> 2026-05-22 live scan 已確認：acmt03/08/12/15/25 已恢復（從 issue 移除）。剩餘問題如下：

| ID | 節點 | 觀測狀態 | 起始時間 | 推測原因 | 處理優先序 |
|----|------|---------|---------|---------|-----------|
| ISS-NODE-04 | acmt14 | DRAINED + Prom node_exporter down | 2025-07-20 (Slurm) | RealMemory 實測 15786 < slurm.conf 設定 15787；node_exporter 同時故障 | P3 |
| ISS-NODE-06 | acmt16 | DOWN / NOT_RESPONDING | 2025-07-21 | 網路或硬體（已離線 ~10 個月） | P2 |
| ISS-NODE-07 | acmt17 | DOWN / NOT_RESPONDING | 2025-07-21 | 網路或硬體（已離線 ~10 個月） | P2 |
| ISS-NODE-08 | acmt25 | Slurm idle / Prom node_exporter down | 2026-05-22 觀測 | Slurm 端已恢復；node_exporter 仍未回報 metrics | P3 |
| ISS-NODE-09 | acmt26 | DOWN / NOT_RESPONDING | 2026-03-19 | 網路或硬體 | P2 |
| ISS-NODE-10 | acmt-gpu | NVML driver/library mismatch | 2026-05-22 發現 | `nvidia-smi` 失敗：NVML library 535.309 與目前 kernel module 不一致；4× P100 透過 `lspci` 仍可見 | P2 |

**TODO 對應動作**

- **TODO (ISS-NODE-06/07/09)**：批次檢查 acmt16/17/26 網路 — `ping`、交換器埠、IPMI；acmt16/17 已離線近 10 個月，可能需要實機現場檢修。目標：恢復至 `idle`。參考 `troubleshooting.md §1`。
- **TODO (ISS-NODE-04)**：實測 acmt14 RealMemory 並調整 `/etc/slurm/slurm.conf` 對應欄位（或更換 RAM）；同時確認 acmt14 node_exporter 是否需要重啟。目標：移除 drain 狀態 + Prom up。
- **TODO (ISS-NODE-08)**：排查 acmt25 node_exporter — `ssh acmt25 "systemctl status node_exporter"` 並確認 9100 port；目標：Prometheus 回到 up。
- **TODO (ISS-NODE-10)**：排查 acmt-gpu NVML 不匹配 — 可能是 driver 升級後沒 reboot 或 kernel module 版本錯。處理選項：(a) `nvidia-smi -L` 在節點上看是否能列舉；(b) `modprobe -r nvidia && modprobe nvidia` 試重載；(c) 不行則 reboot acmt-gpu（先 drain）。目標：`nvidia-smi` 可運作以利 GPU 作業。

### 1.2 服務與設定

| ID | 項目 | 現況 | 目標狀態 | 優先序 |
|----|------|------|---------|--------|
| ISS-SVC-01 | Alertmanager SMTP | 未設定 smarthost，告警 email 不會發送 | 設定機構 SMTP 並驗證 | P2 |
| ISS-SVC-02 | 告警 on-call rotation | 未定義收件人 | 確認管理員 email / 通知群組 | P3 |
| ISS-SVC-03 | NFS mount health alert | 未加入 alert-rules.yml | 補上 `node_filesystem_avail_bytes{mountpoint="/home"}` 規則 | P3 |
| ISS-SVC-04 | Grafana dashboards | Node Exporter Full / Slurm dashboard 尚未匯入 | 匯入並設 default | P3 |
| ISS-SVC-05 | Slack webhook 未配置 | `alertmanager.yml` receiver 未設 Slack webhook URL | 取得 Slack incoming webhook 並設定 receiver | P4 |
| ISS-CFG-GRES | acmt-gpu GRES 數量不一致 | `slurm.conf` 宣告 `Gres=gpu:4` 但 `gres.conf` 為 `/dev/nvidia[0-1]`（只 2 顆 device file） | 比對 acmt-gpu 實際 `lspci \| grep -i nvidia` 數量，調整其中一份設定 | **P1** |
| ISS-CFG-HOSTS | `update_hosts` ansible role 不完整 | `roles/update_hosts/vars/main.yml` 只含 18 筆，缺 acmt16-27 | 補齊 vars 或改用 inventory 動態生成 | P3 |
| ISS-CFG-PROMTGT | Prometheus target list 硬編碼且跳過離線節點 | `prometheus.yml.j2` 略過 acmt16/17 — 即使節點復原也不會自動納監控 | 改用 ansible-inventory 動態生成 targets | P3 |
| ISS-CFG-NEWNODE | `acmt-new-node.yml` 與 `acmt.yml` 完全相同 | 兩份 playbook 內容逐行一致 — 沒有差異化 | 決定是否分化（new-node 加入 nvidia driver / infiniband），或刪除其中一份 | P4 |
| ISS-CFG-ROLES | `nvidia.nvidia_driver` 與 `infiniband` roles 未在任何 playbook | 兩個 role 存在 `roles/` 但不被引用 — 驅動安裝目前是手動 | 把它們納入適當 playbook（或新增 `acmt-gpu-bootstrap.yml`），記錄手動執行步驟 | P3 |

**TODO 對應動作**

- **TODO (ISS-SVC-01)**：取得機構 SMTP relay 資訊 → 更新 `/etc/alertmanager/alertmanager.yml` 的 `smtp_smarthost` → `systemctl reload alertmanager` → 用 `amtool` 送測試 alert。
- **TODO (ISS-SVC-02)**：與管理員確認 alert receiver list，更新 `alertmanager.yml`。
- **TODO (ISS-SVC-03)**：在 `/etc/prometheus/alert-rules.yml` 新增 NFS 規則，`curl -X POST http://localhost:9090/-/reload`。
- **TODO (ISS-SVC-04)**：登入 Grafana → import 1860 (Node Exporter Full) + Slurm dashboard。
- **TODO (ISS-SVC-05)**：取得 Slack incoming webhook URL，於 `/etc/alertmanager/alertmanager.yml` 新增 `slack_configs` receiver，`systemctl reload alertmanager` 驗證。
- **TODO (ISS-CFG-GRES)**：**P1** — **已修正於 acmt-ansible branch `cluster-state-sync-2026-05-22` commit `a5d2e5d`**（已確認 acmt-gpu 實測 4 顆 P100，`gres.conf` 已改為 `[0-3]`）。**待 deploy**：`ansible-playbook acmt-slurm.yml -l acmt-gpu` → `ssh acmt-gpu systemctl restart slurmd` → `scontrol reconfigure` → `srun -p gpu --gres=gpu:4 nvidia-smi -L` 驗證。
- **TODO (ISS-CFG-HOSTS)**：**已修正於 commit `10b6ca2`，已 deploy 完成 2026-05-22 15:25 UTC** — `ansible-playbook acmt.yml -t update_hosts` 跑過全部節點 `ok=1 changed=0`（已在所有可達節點 idempotent 確認），5 個離線節點略過（acmt14/16/17/25/26，符合 STATUS §1.1）。
- **TODO (ISS-CFG-PROMTGT)**：**已處理於 commits `66d3ef9` + `a23ce2e`（PR #2 待 review）**。
	- 預先 dry-diff 發現 `/etc/prometheus/prometheus.yml` 部署版已含手動加的 `rule_files` + `alerting:` 區段，直接跑 playbook 會 regress。
	- 補上 backport branch `prom-template-backport-2026-05-22`（PR #2: https://github.com/AC-T-lab/acmt-ansible/pull/2）把 alerting 設定與 inline comments 拉回 template。
	- merge 後再 deploy 就不會掉設定。**長期 follow-up**：改用 Jinja loop 從 `groups['acmt']` 動態產生 targets。
- **TODO (ISS-CFG-NEWNODE)**：團隊討論：是否要分化兩份 playbook？建議：保留 `acmt.yml` 為完整重部署，把 `acmt-new-node.yml` 增加 nvidia driver bootstrap + Slurm DB user create。**未處理**。
- **TODO (ISS-CFG-ROLES)**：把 `nvidia.nvidia_driver` 加入 `acmt-new-node.yml` (when `gpu`)，把 `infiniband` 加入 `acmt.yml`；或者建立獨立 `acmt-gpu-bootstrap.yml` + `acmt-ib.yml` 並在 README 文件化手動執行步驟。**未處理**。

> **acmt-ansible branch 待 admin 審核**：`cluster-state-sync-2026-05-22`（5 commits, +93 -43 across 14 files, 未 push）。內容含：(1) 合併 admin 既有未 commit WIP；(2) ISS-CFG-GRES P1 修正；(3) ISS-CFG-HOSTS 補齊；(4) prometheus targets 還原離線節點。審核：`ssh admin "cd /root/acmt-ansible && git log main..HEAD --stat"`；合併方式建議 `git merge --ff-only` 或 PR。

### 1.3 安全強化（追蹤項，詳見 security-policy.md）

| ID | 風險 | 嚴重度 | 優先序 |
|----|------|-------|--------|
| ISS-SEC-01 | SSH PermitRootLogin=yes | HIGH | P2 |
| ISS-SEC-02 | SSH PasswordAuthentication=yes (acmt0) | HIGH | P2 |
| ISS-SEC-03 | LDAP 無 TLS | HIGH | P2 |
| ISS-SEC-04 | NFS no_root_squash | HIGH | P2 |
| ISS-SEC-05 | iptables INPUT/OUTPUT 政策為 ACCEPT | HIGH | P3 |
| ISS-SEC-06 | LDAP bind credential 明碼於 /etc/ldap.conf | MEDIUM | P3 |
| ISS-SEC-07 | auditd 未安裝 | MEDIUM | P4 |

**TODO**：見 `security-policy.md` 對應章節的處理建議。導入順序建議：SEC-03 (LDAP TLS) → SEC-04 (NFS root_squash) → SEC-01/02 (SSH 強化) → SEC-05/06/07。

---

## 2. Maintenance Reminders（非 issue，但需週期性檢查）

| 項目 | 週期 | 上次檢查 | 指令 |
|------|------|---------|------|
| `/home` 容量 | 月 | — | `df -h /home` |
| Slurm 日誌錯誤 | 週 | — | `tail -500 /var/log/slurm/slurmctld.log \| grep -i error` |
| Munge 服務 | 季 | — | `ansible acmt -a "systemctl is-active munge"` |
| Alertmanager 自我測試 | 月 | — | `amtool alert add testalert severity=warning` |
| NFS 掛載 | 週 | — | `ansible acmt -a "mountpoint -q /home && echo OK"` |

> **TODO**：完成一次檢查後請更新「上次檢查」欄位（日期），並把發現的問題搬到 §1。

---

## 3. Dynamic Data — 抓取指令清單

> 這些資料**不在本檔保存快照**，請每次需要時透過下列指令抓取。

### 3.1 節點即時狀態

```bash
# 整體分區與節點摘要
acmt status

# 完整節點清單與狀態
sinfo -N -l

# 特定節點細節（含 down/drain reason）
scontrol show node <nodename>

# 對照 Slurm 已知 down/drain 節點
sinfo -R                                  # 顯示 down/drain 原因
sinfo -t down,drain --noheader -o "%N %T %E"
```

### 3.2 作業與佇列

```bash
acmt jobs                                 # 摘要
squeue -o "%.10i %.9P %.8j %.8u %.2t %.10M %.6D %R"
squeue -t PD --start                      # pending jobs 預估開始時間
scontrol show job <jobid>                 # 單一作業細節
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,MaxRSS
```

### 3.3 資源佔用率快照

```bash
# Cluster CPU 分配率（透過 Prometheus）
curl -s 'http://localhost:9090/api/v1/query?query=sum(slurm_node_cpu_alloc)/sum(slurm_node_cpu_total)'

# 每節點記憶體可用百分比
curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes'

# 每節點 1-min load
curl -s 'http://localhost:9090/api/v1/query?query=node_load1'

# /home 使用量
df -h /home
```

### 3.4 服務健康

```bash
systemctl status slurmctld slurmdbd munge prometheus grafana-server alertmanager
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health}'
curl -s http://localhost:9093/api/v2/status                 # Alertmanager
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts | length'
```

### 3.5 Ansible 連線檢查

```bash
ansible acmt -m ping -o
```

---

## 4. 變更記錄

> 本檔變動本身請在此處留短紀錄（一行即可）；實際 cluster 變更請寫到 [maintenance-log.md](maintenance-log.md)。

- 2026-05-22: 從 AGENTS.md 與 ACMT_HPC_Cluster_Nodes_Configuration.md 拆出 state，建立此檔。
- 2026-05-22: 經 live SSH scan 確認 acmt03/08/12/15 已恢復、acmt25 Slurm 端已恢復；ISS-NODE-01/02/03/05 結案，ISS-NODE-08 改寫為 node_exporter 問題；新增 ISS-NODE-10 (acmt-gpu NVML)；更新 acmt14/16/17/26 的精確起始時間。
