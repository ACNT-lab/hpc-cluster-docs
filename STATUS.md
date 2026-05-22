---
title: ACMT Cluster — Live State & Tracked Issues | ACMT Cluster — 即時狀態與追蹤 issue
type: State
last_updated: 2026-05-22
last_live_scan: 2026-05-22 (ssh admin)
source_of_truth: This file (for issues/TODOs); `acmt`/`sinfo`/`squeue` (for live runtime data)
---

# ACMT HPC Cluster — Status / ACMT HPC Cluster — 狀態

> This file tracks **cluster state that must persist across sessions**: open issues, TODOs, and commands for fetching dynamic data.
>
> 本檔追蹤 **跨會話需保留的 cluster state**：未解的已知問題、待辦事項、與動態資料的取得指令。
>
> **Design principles / 設計原則**
> - **Do not hard-code current node/job/utilisation snapshots** — fetch these dynamically via commands (see §3).
>   **不寫死當前節點/作業/佔用率快照** — 這些用指令動態抓取（見 §3）。
> - **Only record things worth tracking**: open issues, TODOs, observations meaningful across sessions.
>   **只記錄需被追蹤的事**：尚未解決的 issue、待辦、跨會話有意義的觀察。
> - **Tag every issue with `TODO:`** — include target state and next action.
>   **每筆 issue 都標 `TODO:`** — 含目標狀態與下一步動作。
> - Once resolved, move the entry to [maintenance-log.md](maintenance-log.md) and delete from here; for batched workflows see [ansible-runbook.md](ansible-runbook.md).
>   解決後請移至 [maintenance-log.md](maintenance-log.md) 並從此處刪除；批次處理流程見 [ansible-runbook.md](ansible-runbook.md)。

---

## 1. Known Issues (Open) / 已知未解 Issue

### 1.1 Node offline / abnormal / 節點離線 / 異常

> 2026-05-22 live scan confirmed: acmt03/08/12/15/25 have recovered (removed from issue list). Remaining items below.
>
> 2026-05-22 live scan 已確認：acmt03/08/12/15/25 已恢復（從 issue 移除）。剩餘問題如下：

| ID | Node / 節點 | Observed state / 觀測狀態 | Started / 起始時間 | Suspected cause / 推測原因 | Priority / 處理優先序 |
|----|------|---------|---------|---------|-----------|
| ISS-NODE-04 | acmt14 | DRAINED + Prom node_exporter down | 2025-07-20 (Slurm) | RealMemory measured 15786 < slurm.conf value 15787; node_exporter also broken / RealMemory 實測 15786 < slurm.conf 設定 15787；node_exporter 同時故障 | P3 |
| ISS-NODE-06 | acmt16 | DOWN / NOT_RESPONDING | 2025-07-21 | Network or hardware (offline ~10 months) / 網路或硬體（已離線約 10 個月） | P2 |
| ISS-NODE-07 | acmt17 | DOWN / NOT_RESPONDING | 2025-07-21 | Network or hardware (offline ~10 months) / 網路或硬體（已離線約 10 個月） | P2 |
| ISS-NODE-08 | acmt25 | Slurm idle / Prom node_exporter down | 2026-05-22 observed / 2026-05-22 觀測 | Slurm side recovered; node_exporter still not reporting metrics / Slurm 端已恢復；node_exporter 仍未回報 metrics | P3 |
| ISS-NODE-09 | acmt26 | DOWN / NOT_RESPONDING | 2026-03-19 | Network or hardware / 網路或硬體 | P2 |
| ISS-NODE-10 | acmt-gpu | NVML driver/library mismatch | 2026-05-22 discovered / 2026-05-22 發現 | `nvidia-smi` fails: NVML library 535.309 mismatched with current kernel module; 4× P100 still visible via `lspci` / `nvidia-smi` 失敗：NVML library 535.309 與目前 kernel module 不一致；4× P100 透過 `lspci` 仍可見 | P2 |

**TODO actions / TODO 對應動作**

- **TODO (ISS-NODE-06/07/09)**: Batch-check network for acmt16/17/26 — `ping`, switch ports, IPMI; acmt16/17 have been offline ~10 months and may need on-site repair. Target: restore to `idle`. See `troubleshooting.md §1`.
  **TODO (ISS-NODE-06/07/09)**：批次檢查 acmt16/17/26 網路 — `ping`、交換器埠、IPMI；acmt16/17 已離線近 10 個月，可能需要實機現場檢修。目標：恢復至 `idle`。參考 `troubleshooting.md §1`。
- **TODO (ISS-NODE-04)**: Measure acmt14 RealMemory and update the matching field in `/etc/slurm/slurm.conf` (or swap RAM); confirm whether acmt14 node_exporter needs a restart. Target: drain cleared + Prom up.
  **TODO (ISS-NODE-04)**：實測 acmt14 RealMemory 並調整 `/etc/slurm/slurm.conf` 對應欄位（或更換 RAM）；同時確認 acmt14 node_exporter 是否需要重啟。目標：移除 drain 狀態 + Prom up。
- **TODO (ISS-NODE-08)**: Investigate acmt25 node_exporter — `ssh acmt25 "systemctl status node_exporter"` and confirm port 9100. Target: Prometheus back to up.
  **TODO (ISS-NODE-08)**：排查 acmt25 node_exporter — `ssh acmt25 "systemctl status node_exporter"` 並確認 9100 port；目標：Prometheus 回到 up。
- **TODO (ISS-NODE-10)**: Investigate acmt-gpu NVML mismatch — likely a driver upgrade without reboot or wrong kernel-module version. Options: (a) run `nvidia-smi -L` on the node to see if it lists; (b) `modprobe -r nvidia && modprobe nvidia` to reload; (c) if neither works, reboot acmt-gpu (drain first). Target: `nvidia-smi` working so GPU jobs can run.
  **TODO (ISS-NODE-10)**：排查 acmt-gpu NVML 不匹配 — 可能是 driver 升級後沒 reboot 或 kernel module 版本錯。處理選項：(a) `nvidia-smi -L` 在節點上看是否能列舉；(b) `modprobe -r nvidia && modprobe nvidia` 試重載；(c) 不行則 reboot acmt-gpu（先 drain）。目標：`nvidia-smi` 可運作以利 GPU 作業。

### 1.2 Services and configuration / 服務與設定

| ID | Item / 項目 | Current state / 現況 | Target state / 目標狀態 | Priority / 優先序 |
|----|------|------|---------|--------|
| ISS-SVC-01 | Alertmanager SMTP | No smarthost configured; alert email won't send / 未設定 smarthost，告警 email 不會發送 | Configure institution SMTP and verify / 設定機構 SMTP 並驗證 | P2 |
| ISS-SVC-02 | Alert on-call rotation / 告警 on-call rotation | Recipients not defined / 未定義收件人 | Confirm admin email / notification group / 確認管理員 email / 通知群組 | P3 |
| ISS-SVC-03 | NFS mount health alert | Not in alert-rules.yml / 未加入 alert-rules.yml | Add `node_filesystem_avail_bytes{mountpoint="/home"}` rule / 補上 `node_filesystem_avail_bytes{mountpoint="/home"}` 規則 | P3 |
| ISS-SVC-04 | Grafana dashboards | Node Exporter Full / Slurm dashboard not yet imported / Node Exporter Full / Slurm dashboard 尚未匯入 | Import and set as default / 匯入並設 default | P3 |
| ISS-SVC-05 | Slack webhook not configured / Slack webhook 未配置 | `alertmanager.yml` receiver has no Slack webhook URL / `alertmanager.yml` receiver 未設 Slack webhook URL | Obtain Slack incoming webhook and configure receiver / 取得 Slack incoming webhook 並設定 receiver | P4 |
| ISS-CFG-GRES | acmt-gpu GRES count mismatch / acmt-gpu GRES 數量不一致 | `slurm.conf` declares `Gres=gpu:4` but `gres.conf` lists `/dev/nvidia[0-1]` (only 2 device files) / `slurm.conf` 宣告 `Gres=gpu:4` 但 `gres.conf` 為 `/dev/nvidia[0-1]`（只 2 顆 device file） | Confirm actual count via acmt-gpu `lspci \| grep -i nvidia`, then fix whichever side is wrong / 比對 acmt-gpu 實際 `lspci \| grep -i nvidia` 數量，調整其中一份設定 | **P1** |
| ISS-CFG-HOSTS | `update_hosts` ansible role incomplete / `update_hosts` ansible role 不完整 | `roles/update_hosts/vars/main.yml` has only 18 entries; missing acmt16-27 / `roles/update_hosts/vars/main.yml` 只含 18 筆，缺 acmt16-27 | Complete the vars list or switch to inventory-driven generation / 補齊 vars 或改用 inventory 動態生成 | P3 |
| ISS-CFG-PROMTGT | Prometheus target list hard-coded and skips offline nodes / Prometheus target list 硬編碼且跳過離線節點 | `prometheus.yml.j2` skips acmt16/17 — even when nodes recover they won't be auto-monitored / `prometheus.yml.j2` 略過 acmt16/17 — 即使節點復原也不會自動納監控 | Generate targets dynamically from ansible-inventory / 改用 ansible-inventory 動態生成 targets | P3 |
| ISS-CFG-NEWNODE | `acmt-new-node.yml` identical to `acmt.yml` / `acmt-new-node.yml` 與 `acmt.yml` 完全相同 | Two playbooks line-for-line equal — no differentiation / 兩份 playbook 內容逐行一致 — 沒有差異化 | Decide whether to differentiate (new-node adds nvidia driver / infiniband), or delete one / 決定是否分化（new-node 加入 nvidia driver / infiniband），或刪除其中一份 | P4 |
| ISS-CFG-ROLES | `nvidia.nvidia_driver` and `infiniband` roles not in any playbook / `nvidia.nvidia_driver` 與 `infiniband` roles 未在任何 playbook | Both roles exist under `roles/` but are unreferenced — driver install is currently manual / 兩個 role 存在 `roles/` 但不被引用 — 驅動安裝目前是手動 | Add them to an appropriate playbook (or new `acmt-gpu-bootstrap.yml`), document manual steps / 把它們納入適當 playbook（或新增 `acmt-gpu-bootstrap.yml`），記錄手動執行步驟 | P3 |

**TODO actions / TODO 對應動作**

- **TODO (ISS-SVC-01)**: Obtain institutional SMTP relay info → update `smtp_smarthost` in `/etc/alertmanager/alertmanager.yml` → `systemctl reload alertmanager` → send test alert with `amtool`.
  **TODO (ISS-SVC-01)**：取得機構 SMTP relay 資訊 → 更新 `/etc/alertmanager/alertmanager.yml` 的 `smtp_smarthost` → `systemctl reload alertmanager` → 用 `amtool` 送測試 alert。
- **TODO (ISS-SVC-02)**: Confirm alert receiver list with admin; update `alertmanager.yml`.
  **TODO (ISS-SVC-02)**：與管理員確認 alert receiver list，更新 `alertmanager.yml`。
- **TODO (ISS-SVC-03)**: Add NFS rule to `/etc/prometheus/alert-rules.yml`, then `curl -X POST http://localhost:9090/-/reload`.
  **TODO (ISS-SVC-03)**：在 `/etc/prometheus/alert-rules.yml` 新增 NFS 規則，`curl -X POST http://localhost:9090/-/reload`。
- **TODO (ISS-SVC-04)**: Log into Grafana → import 1860 (Node Exporter Full) + Slurm dashboard.
  **TODO (ISS-SVC-04)**：登入 Grafana → import 1860 (Node Exporter Full) + Slurm dashboard。
- **TODO (ISS-SVC-05)**: Obtain Slack incoming webhook URL, add `slack_configs` receiver to `/etc/alertmanager/alertmanager.yml`, then `systemctl reload alertmanager` and verify.
  **TODO (ISS-SVC-05)**：取得 Slack incoming webhook URL，於 `/etc/alertmanager/alertmanager.yml` 新增 `slack_configs` receiver，`systemctl reload alertmanager` 驗證。
- **TODO (ISS-CFG-GRES)**: **P1** — **Fixed in acmt-ansible branch `cluster-state-sync-2026-05-22` commit `a5d2e5d`** (confirmed acmt-gpu actually has 4 P100s; `gres.conf` updated to `[0-3]`). **Pending deploy**: `ansible-playbook acmt-slurm.yml -l acmt-gpu` → `ssh acmt-gpu systemctl restart slurmd` → `scontrol reconfigure` → verify with `srun -p gpu --gres=gpu:4 nvidia-smi -L`.
  **TODO (ISS-CFG-GRES)**：**P1** — **已修正於 acmt-ansible branch `cluster-state-sync-2026-05-22` commit `a5d2e5d`**（已確認 acmt-gpu 實測 4 顆 P100，`gres.conf` 已改為 `[0-3]`）。**待 deploy**：`ansible-playbook acmt-slurm.yml -l acmt-gpu` → `ssh acmt-gpu systemctl restart slurmd` → `scontrol reconfigure` → `srun -p gpu --gres=gpu:4 nvidia-smi -L` 驗證。
- **TODO (ISS-CFG-HOSTS)**: **Fixed in commit `10b6ca2`, deployed 2026-05-22 15:25 UTC** — `ansible-playbook acmt.yml -t update_hosts` ran across all nodes with `ok=1 changed=0` (idempotent confirmation on all reachable nodes); 5 offline nodes skipped (acmt14/16/17/25/26, matching STATUS §1.1).
  **TODO (ISS-CFG-HOSTS)**：**已修正於 commit `10b6ca2`，已 deploy 完成 2026-05-22 15:25 UTC** — `ansible-playbook acmt.yml -t update_hosts` 跑過全部節點 `ok=1 changed=0`（已在所有可達節點 idempotent 確認），5 個離線節點略過（acmt14/16/17/25/26，符合 STATUS §1.1）。
- **TODO (ISS-CFG-PROMTGT)**: **Handled in commits `66d3ef9` + `a23ce2e` (PR #2 awaiting review)**.
  **TODO (ISS-CFG-PROMTGT)**：**已處理於 commits `66d3ef9` + `a23ce2e`（PR #2 待 review）**。
	- Pre-deploy dry-diff revealed the deployed `/etc/prometheus/prometheus.yml` already had manually-added `rule_files` + `alerting:` sections; running the playbook directly would have regressed.
	  預先 dry-diff 發現 `/etc/prometheus/prometheus.yml` 部署版已含手動加的 `rule_files` + `alerting:` 區段，直接跑 playbook 會 regress。
	- Backport branch `prom-template-backport-2026-05-22` (PR #2: https://github.com/AC-T-lab/acmt-ansible/pull/2) restores the alerting config and inline comments into the template.
	  補上 backport branch `prom-template-backport-2026-05-22`（PR #2: https://github.com/AC-T-lab/acmt-ansible/pull/2）把 alerting 設定與 inline comments 拉回 template。
	- After the merge, redeploy won't drop the config. **Long-term follow-up**: use a Jinja loop to generate targets dynamically from `groups['acmt']`.
	  merge 後再 deploy 就不會掉設定。**長期 follow-up**：改用 Jinja loop 從 `groups['acmt']` 動態產生 targets。
- **TODO (ISS-CFG-NEWNODE)**: Team discussion — split the two playbooks? Suggested: keep `acmt.yml` for full redeploy; expand `acmt-new-node.yml` with nvidia driver bootstrap + Slurm DB user create. **Not yet handled.**
  **TODO (ISS-CFG-NEWNODE)**：團隊討論：是否要分化兩份 playbook？建議：保留 `acmt.yml` 為完整重部署，把 `acmt-new-node.yml` 增加 nvidia driver bootstrap + Slurm DB user create。**未處理**。
- **TODO (ISS-CFG-ROLES)**: Add `nvidia.nvidia_driver` to `acmt-new-node.yml` (when `gpu`); add `infiniband` to `acmt.yml`; or create standalone `acmt-gpu-bootstrap.yml` + `acmt-ib.yml` and document manual run steps in README. **Not yet handled.**
  **TODO (ISS-CFG-ROLES)**：把 `nvidia.nvidia_driver` 加入 `acmt-new-node.yml` (when `gpu`)，把 `infiniband` 加入 `acmt.yml`；或者建立獨立 `acmt-gpu-bootstrap.yml` + `acmt-ib.yml` 並在 README 文件化手動執行步驟。**未處理**。

> **acmt-ansible branch awaiting admin review**: `cluster-state-sync-2026-05-22` (5 commits, +93 -43 across 14 files, not yet pushed). Contents: (1) consolidates admin's existing uncommitted WIP; (2) ISS-CFG-GRES P1 fix; (3) ISS-CFG-HOSTS fill-in; (4) restores offline nodes in prometheus targets. Review: `ssh admin "cd /root/acmt-ansible && git log main..HEAD --stat"`; suggested merge: `git merge --ff-only` or PR.
>
> **acmt-ansible branch 待 admin 審核**：`cluster-state-sync-2026-05-22`（5 commits, +93 -43 across 14 files, 未 push）。內容含：(1) 合併 admin 既有未 commit WIP；(2) ISS-CFG-GRES P1 修正；(3) ISS-CFG-HOSTS 補齊；(4) prometheus targets 還原離線節點。審核：`ssh admin "cd /root/acmt-ansible && git log main..HEAD --stat"`；合併方式建議 `git merge --ff-only` 或 PR。

### 1.3 Security hardening (tracking items, see security-policy.md) / 安全強化（追蹤項，詳見 security-policy.md）

| ID | Risk / 風險 | Severity / 嚴重度 | Priority / 優先序 |
|----|------|-------|--------|
| ISS-SEC-01 | SSH PermitRootLogin=yes | HIGH | P2 |
| ISS-SEC-02 | SSH PasswordAuthentication=yes (acmt0) | HIGH | P2 |
| ISS-SEC-03 | LDAP without TLS / LDAP 無 TLS | HIGH | P2 |
| ISS-SEC-04 | NFS no_root_squash | HIGH | P2 |
| ISS-SEC-05 | iptables INPUT/OUTPUT policy = ACCEPT / iptables INPUT/OUTPUT 政策為 ACCEPT | HIGH | P3 |
| ISS-SEC-06 | LDAP bind credential plaintext in /etc/ldap.conf / LDAP bind credential 明碼於 /etc/ldap.conf | MEDIUM | P3 |
| ISS-SEC-07 | auditd not installed / auditd 未安裝 | MEDIUM | P4 |

**TODO**: See the matching sections of `security-policy.md` for recommended handling. Suggested order: SEC-03 (LDAP TLS) → SEC-04 (NFS root_squash) → SEC-01/02 (SSH hardening) → SEC-05/06/07.

**TODO**：見 `security-policy.md` 對應章節的處理建議。導入順序建議：SEC-03 (LDAP TLS) → SEC-04 (NFS root_squash) → SEC-01/02 (SSH 強化) → SEC-05/06/07。

---

## 2. Maintenance Reminders (not issues, but periodic checks) / 維護提醒（非 issue，但需週期性檢查）

| Item / 項目 | Cycle / 週期 | Last check / 上次檢查 | Command / 指令 |
|------|------|---------|------|
| `/home` capacity / `/home` 容量 | Monthly / 月 | — | `df -h /home` |
| Slurm log errors / Slurm 日誌錯誤 | Weekly / 週 | — | `tail -500 /var/log/slurm/slurmctld.log \| grep -i error` |
| Munge service / Munge 服務 | Quarterly / 季 | — | `ansible acmt -a "systemctl is-active munge"` |
| Alertmanager self-test / Alertmanager 自我測試 | Monthly / 月 | — | `amtool alert add testalert severity=warning` |
| NFS mount / NFS 掛載 | Weekly / 週 | — | `ansible acmt -a "mountpoint -q /home && echo OK"` |

> **TODO**: After running a check, update the "Last check" column (date) and move any findings into §1.
>
> **TODO**：完成一次檢查後請更新「上次檢查」欄位（日期），並把發現的問題搬到 §1。

---

## 3. Dynamic Data — Fetch commands / Dynamic Data — 抓取指令清單

> This data **is not snapshotted in this file** — fetch it via the commands below whenever needed.
>
> 這些資料**不在本檔保存快照**，請每次需要時透過下列指令抓取。

### 3.1 Node live state / 節點即時狀態

```bash
# Overall partition and node summary / 整體分區與節點摘要
acmt status

# Full node list with status / 完整節點清單與狀態
sinfo -N -l

# Specific node details (including down/drain reason) / 特定節點細節（含 down/drain reason）
scontrol show node <nodename>

# Known down/drain nodes per Slurm / 對照 Slurm 已知 down/drain 節點
sinfo -R                                  # show down/drain reasons / 顯示 down/drain 原因
sinfo -t down,drain --noheader -o "%N %T %E"
```

### 3.2 Jobs and queue / 作業與佇列

```bash
acmt jobs                                 # summary / 摘要
squeue -o "%.10i %.9P %.8j %.8u %.2t %.10M %.6D %R"
squeue -t PD --start                      # pending jobs estimated start time / pending jobs 預估開始時間
scontrol show job <jobid>                 # single job details / 單一作業細節
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,MaxRSS
```

### 3.3 Resource utilisation snapshot / 資源佔用率快照

```bash
# Cluster CPU allocation (via Prometheus) / Cluster CPU 分配率（透過 Prometheus）
curl -s 'http://localhost:9090/api/v1/query?query=sum(slurm_node_cpu_alloc)/sum(slurm_node_cpu_total)'

# Per-node memory availability percentage / 每節點記憶體可用百分比
curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes'

# Per-node 1-min load / 每節點 1-min load
curl -s 'http://localhost:9090/api/v1/query?query=node_load1'

# /home usage / /home 使用量
df -h /home
```

### 3.4 Service health / 服務健康

```bash
systemctl status slurmctld slurmdbd munge prometheus grafana-server alertmanager
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health}'
curl -s http://localhost:9093/api/v2/status                 # Alertmanager
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts | length'
```

### 3.5 Ansible connectivity check / Ansible 連線檢查

```bash
ansible acmt -m ping -o
```

---

## 4. Change log for this file / 本檔變更記錄

> Log changes to this file itself here (one line each); cluster operational changes belong in [maintenance-log.md](maintenance-log.md).
>
> 本檔變動本身請在此處留短紀錄（一行即可）；實際 cluster 變更請寫到 [maintenance-log.md](maintenance-log.md)。

- 2026-05-22: Split state out of AGENTS.md and ACMT_HPC_Cluster_Nodes_Configuration.md and created this file.
  2026-05-22: 從 AGENTS.md 與 ACMT_HPC_Cluster_Nodes_Configuration.md 拆出 state，建立此檔。
- 2026-05-22: Live SSH scan confirmed acmt03/08/12/15 recovered and acmt25 recovered on the Slurm side; ISS-NODE-01/02/03/05 closed, ISS-NODE-08 rewritten as a node_exporter issue; added ISS-NODE-10 (acmt-gpu NVML); refined start dates for acmt14/16/17/26.
  2026-05-22: 經 live SSH scan 確認 acmt03/08/12/15 已恢復、acmt25 Slurm 端已恢復；ISS-NODE-01/02/03/05 結案，ISS-NODE-08 改寫為 node_exporter 問題；新增 ISS-NODE-10 (acmt-gpu NVML)；更新 acmt14/16/17/26 的精確起始時間。
