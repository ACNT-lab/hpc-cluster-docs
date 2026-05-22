---
title: ACMT HPC Cluster — Maintenance Log | ACMT HPC Cluster — 維護紀錄
type: Log (append-only)
last_updated: 2026-05-22
source_of_truth: This file (canonical history of cluster changes)
---

# ACMT HPC Cluster — Maintenance Log / ACMT HPC Cluster — 維護紀錄

> New events go at the top with the latest date, following the template below. Once an issue is resolved, remove it from [`STATUS.md`](STATUS.md) and record it here.
>
> 新事件請以最新日期為頂，沿用本檔下方的 Template 格式。已解決的 issue 請從 [`STATUS.md`](STATUS.md) 移除並在此留紀錄。

## Format / 格式

Every entry follows this template:

每筆紀錄使用以下 template：

```markdown
### YYYY-MM-DD: [Brief title]

**Category**: config-change | software-install | hardware | incident | update | other
**Author**: <name>
**Duration**: <start> → <end> (or N/A)
**Nodes affected**: <list>
**Services affected**: <list>
**Summary**: What was done and why
**Details**:
- Step 1
- Step 2
**Rollback**: How to undo this change
**Verification**: How to confirm it's working
```

---

## 2026-05-22: Documentation reorg + LDAP password redaction / 文件重整 + LDAP 密碼遮蔽

**Category**: other (documentation)
**Author**: claude+latteine
**Duration**: same session
**Nodes affected**: none (docs only)
**Services affected**: none (docs only; LDAP password rotation still pending on admin side — see CHANGELOG.md)

**Summary**: Repo-wide doc reorg + Notion server-manual rewrite; redacted leaked LDAP bind password from security-policy.md; applied 14 prioritized markdown fixes (see CHANGELOG.md).

**摘要**：整個 repo 的文件重整 + Notion server manual 重寫；遮蔽 security-policy.md 中外洩的 LDAP bind password；套用 14 項 markdown 修正（見 CHANGELOG.md）。

**Details / 細節**:
- Reconciled stale node states across `network-topology.md`, `troubleshooting.md`, `ansible-runbook.md`, `AGENTS.md` — STATUS.md is now the single source-of-truth for node state.
  將 `network-topology.md`、`troubleshooting.md`、`ansible-runbook.md`、`AGENTS.md` 中過期的節點狀態統一處理 — STATUS.md 現為節點狀態的唯一 source-of-truth。
- Fixed brace-expansion bug `acmt0{1..27}` → `acmt{01..27}` in health-check loops.
  修正 health-check 迴圈中的 brace 展開 bug `acmt0{1..27}` → `acmt{01..27}`。
- Resolved `ISS-SVC-04` ID collision (Slack moved to `ISS-SVC-05`).
  處理 `ISS-SVC-04` ID 衝突（Slack 改編為 `ISS-SVC-05`）。
- Marked `ACMT_InfiniBand_Analysis_Report.md` as SUPERSEDED.
  將 `ACMT_InfiniBand_Analysis_Report.md` 標記為 SUPERSEDED。
- Deduplicated keyboard-shortcut sections in `slurm-monitor-README.md`; closed unbalanced code fence in `ansible-runbook.md`.
  `slurm-monitor-README.md` 重複的快捷鍵段落去重；`ansible-runbook.md` 不對稱的 code fence 補齊。
- Added cross-references across previously orphan files.
  為先前無連結的檔案補上交叉引用。

**Rollback**: `git revert <commit-hash>` (hash unknown at draft time; check `git log` after commit lands).

**Rollback**：`git revert <commit-hash>`（草稿階段尚不知 hash；commit 進 main 後從 `git log` 查）。

**Verification**: `scripts/check-secrets.sh` exits 0 on the working tree (covers the historical bind password + other generic secret patterns); code fences in `ansible-runbook.md` are balanced (even count via `awk` line-counter).

**驗證**：`scripts/check-secrets.sh` 對 working tree 回傳 0（涵蓋歷史 bind password 與其他通用 secret 樣式）；`ansible-runbook.md` 的 code fence 對稱（以 `awk` 行數計算為偶數）。

---

## 2026-05-21: GSL 2.8 installation / GSL 2.8 安裝

**Category**: software-install
**Author**: root
**Duration**: 30min
**Nodes affected**: all (via NFS /opt)
**Services affected**: none

**Summary**: Installed GNU Scientific Library 2.8 as test of software-installation-sop.md.

**摘要**：安裝 GNU Scientific Library 2.8，作為 software-installation-sop.md 的測試案例。

**Details / 細節**:
- Downloaded gsl-2.8.tar.gz to /opt/src/ / 下載 gsl-2.8.tar.gz 到 /opt/src/
- Built with `./configure --prefix=/opt/gsl/2.8 CC=gcc CXX=g++ FC=gfortran` / 以該設定編譯
- `make -j$(nproc) && make install`
- Created modulefile: /opt/modulefiles/gsl/2.8 / 建立 modulefile：/opt/modulefiles/gsl/2.8
- Tested: module load, gsl-config, test C program compilation, Slurm job 3582 on acmt09 / 測試：module load、gsl-config、測試 C 程式編譯、acmt09 上的 Slurm job 3582

**Known issue / 已知問題**: `module` command not available in Slurm batch jobs — requires `source /usr/share/modules/init/bash`.

`module` 指令在 Slurm batch job 中不可用 — 需要先 `source /usr/share/modules/init/bash`。

**Rollback**: `rm -rf /opt/gsl/2.8 /opt/modulefiles/gsl/2.8`

**Verification**: `module load gsl/2.8 && gsl-config --version` returns 2.8.

**驗證**：`module load gsl/2.8 && gsl-config --version` 回傳 2.8。

---

## 2026-05-21: Software Installation SOP documented / Software Installation SOP 文件化

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all

**Summary**: Created /root/software-installation-sop.md covering standard build procedures, modulefile templates, and Slurm testing. Verified by installing GSL 2.8.

**摘要**：建立 /root/software-installation-sop.md，涵蓋標準編譯流程、modulefile 範本、Slurm 測試方式；以安裝 GSL 2.8 驗證。

---

## 2026-05-21: Security Policy documented / 安全政策文件化

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all

**Summary**: Created /root/security-policy.md covering firewall, SSH, LDAP, NFS, password policy, incident response.

**摘要**：建立 /root/security-policy.md，涵蓋防火牆、SSH、LDAP、NFS、密碼政策、事故應變。

---

## 2026-05-21: Network Topology documented / 網路拓撲文件化

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all

**Summary**: Created /root/network-topology.md with IP→MAC mapping, IB fabric port mapping, routing table, rack layout from server.png/server2.png.

**摘要**：建立 /root/network-topology.md，內含 IP→MAC 對應、IB fabric 端口對應、路由表、根據 server.png/server2.png 整理的 rack 配置。

---

## 2026-05-21: Prometheus monitoring — full setup / Prometheus 監控 — 完整設置

**Category**: config-change
**Author**: root
**Duration**: 30min
**Nodes affected**: all
**Services affected**: Prometheus (restarted)

**Summary**: Completed monitoring infrastructure: added missing nodes to scrape config, created alert rules, installed Alertmanager.

**摘要**：完成監控基礎建設：scrape 設定補入缺失節點、建立 alert rule、安裝 Alertmanager。

**Details / 細節**:
- Added acmt16-27 (12 nodes) to `/etc/prometheus/prometheus.yml` / 在 `/etc/prometheus/prometheus.yml` 加入 acmt16-27（12 個節點）
- Created `/etc/prometheus/alert-rules.yml` with 9 rules (NodeDown, DiskFull, Memory, CPU, SlurmNodeDown, etc.) / 建立 `/etc/prometheus/alert-rules.yml`，包含 9 條規則（NodeDown、DiskFull、Memory、CPU、SlurmNodeDown 等）
- Downloaded and installed Alertmanager v0.27.0 / 下載並安裝 Alertmanager v0.27.0
- Created `/etc/alertmanager/alertmanager.yml` with email receivers (SMTP not configured — placeholder only) / 建立 `/etc/alertmanager/alertmanager.yml` 並設定 email receiver（SMTP 未設定 — 僅為 placeholder）
- Created systemd service and enabled on boot / 建立 systemd service 並設為開機啟動
- Wired Alertmanager into Prometheus alerting config / 在 Prometheus 的 alerting 設定中串入 Alertmanager

**Known issue / 已知問題**: Email alerts require SMTP server — set `smtp_smarthost` in `/etc/alertmanager/alertmanager.yml`.

Email 告警需要 SMTP 伺服器 — 請於 `/etc/alertmanager/alertmanager.yml` 設定 `smtp_smarthost`。

**Rollback**: `systemctl stop alertmanager && systemctl disable alertmanager`; revert prometheus.yml.

**Rollback**：`systemctl stop alertmanager && systemctl disable alertmanager`；還原 prometheus.yml。

**Verification**: `curl -s http://localhost:9090/api/v1/alerts` shows 19 pending alerts.

**驗證**：`curl -s http://localhost:9090/api/v1/alerts` 顯示 19 個 pending alerts。

---

## 2024-03-18: Initial Cluster Deployment / Cluster 初次部署

**Category**: install
**Author**: kc-lin / kerwin
**Duration**: unknown
**Nodes affected**: all

**Summary**: Initial deployment of ACMT HPC cluster. Set up acmt0 (headnode), acmt-storage, 25 compute nodes. Installed Slurm, LDAP, NFS, InfiniBand.

**摘要**：ACMT HPC cluster 初次部署。設置 acmt0（headnode）、acmt-storage、25 個 compute node；安裝 Slurm、LDAP、NFS、InfiniBand。

**Known config / 已知設定**:
- Slurm config: /etc/slurm/slurm.conf (created 2024-03-22) / Slurm 設定：/etc/slurm/slurm.conf（2024-03-22 建立）
- LDAP base: dc=acmt, admin password set / LDAP base：dc=acmt，admin 密碼已設定
- NFS exports: /home, /opt from acmt-storage / NFS exports：由 acmt-storage 匯出 /home、/opt
- InfiniBand: Mellanox MSB7700, ConnectX-4 cards / InfiniBand：Mellanox MSB7700 與 ConnectX-4 網卡
- Munge key: /etc/munge/munge.key (created 2024-03-18) / Munge key：/etc/munge/munge.key（2024-03-18 建立）

---

## 2024-03-22: SlurmDBD + MySQL setup / SlurmDBD + MySQL 設置

**Category**: config-change
**Author**: root

**Summary**: Configured slurmdbd with MySQL backend on acmt0. StoragePass set in /etc/slurm/slurmdbd.conf.

**摘要**：在 acmt0 上設定 slurmdbd 並以 MySQL 為後端。StoragePass 寫入 /etc/slurm/slurmdbd.conf。

---

## 2025-09-05: GCC 15.2 installation / GCC 15.2 安裝

**Category**: software-install
**Author**: kc-lin

**Summary**: Built GCC 15.2 from source and deployed via /root/install_gcc15.2_with_module_and_slurm.sh. Modulefile at /opt/modulefiles/gcc/15.2.

**摘要**：由原始碼編譯 GCC 15.2，透過 /root/install_gcc15.2_with_module_and_slurm.sh 部署。Modulefile 位於 /opt/modulefiles/gcc/15.2。

---

## Template for new entries / 新增紀錄的 template

```markdown
### YYYY-MM-DD: <title>

**Category**: <config-change | software-install | hardware | incident | update | other>
**Author**: <name>
**Duration**: <start> → <end>
**Nodes affected**: <list>
**Services affected**: <list>
**Summary**: <one-line>
**Details**:
- <step>
**Rollback**: <how to undo>
**Verification**: <how to confirm>
```
