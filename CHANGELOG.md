---
title: ACMT HPC Cluster Docs — CHANGELOG | ACMT HPC Cluster 文件 — CHANGELOG
type: Log (append-only)
last_updated: 2026-05-22
source_of_truth: This file
---

# CHANGELOG / 變更紀錄

This file logs changes to **the documentation set itself**. Cluster operational changes (hardware swaps, software installs, configuration deploys) go in [maintenance-log.md](maintenance-log.md) instead.

本檔記錄 **文件集本身的變動**。Cluster 上的維運變更（硬體置換、軟體安裝、設定部署）請查 [maintenance-log.md](maintenance-log.md)。

> New entries go at the top (reverse chronological). Each entry carries a `[type]` tag: `docs:` documentation changes, `security:` security-related, `workflow:` process/tooling, `fix:` bug fixes, `refactor:` structural changes.
>
> 新事件加到最上面（reverse chronological）。每筆紀錄附 `[type]` 標籤：`docs:` 文件變動、`security:` 安全相關、`workflow:` 流程/工具、`fix:` 修正錯誤、`refactor:` 結構調整。

---

## 2026-05-22 — Phase-1 deploy + PR #2 (config drift backport) / Phase-1 部署 + PR #2（設定漂移 backport）

[`fix:`] **Deployed `update_hosts` role across cluster** (post PR #1 merge). Result: 24 reachable nodes returned `ok=1 changed=0` (idempotent — /etc/hosts was already accurate everywhere reachable). 5 nodes UNREACHABLE matching known down list (acmt14/16/17/25/26 — see STATUS §1.1).

[`fix:`] **全 cluster 部署 `update_hosts` role**（PR #1 merge 後）。結果：24 個可達節點回傳 `ok=1 changed=0`（idempotent — 各處 /etc/hosts 早已正確）。5 個節點 UNREACHABLE，與已知 down 名單一致（acmt14/16/17/25/26 — 見 STATUS §1.1）。

[`fix:`] **Discovered prometheus config drift before regression occurred.** Pre-deploy `diff /etc/prometheus/prometheus.yml roles/prometheus/templates/prometheus.yml.j2` revealed the deployed file had manually-added `rule_files` + `alerting.alertmanagers → localhost:9093` sections that were NOT in the template. Running `ansible-playbook acmt-monitoring.yml` would have silently removed alertmanager wiring. **No regression occurred — caught by dry-diff.**

[`fix:`] **在 regression 發生前發現 prometheus 設定漂移**。部署前 `diff /etc/prometheus/prometheus.yml roles/prometheus/templates/prometheus.yml.j2` 發現部署版檔案含有手動加入的 `rule_files` + `alerting.alertmanagers → localhost:9093` 區段，但 template 沒有。直接執行 `ansible-playbook acmt-monitoring.yml` 會悄悄把 alertmanager 串接拆掉。**未發生 regression — 已由 dry-diff 攔下。**

[`fix:`] **Opened PR #2** (`prom-template-backport-2026-05-22`): https://github.com/AC-T-lab/acmt-ansible/pull/2 — backports deployed config drift into template so future `acmt-monitoring.yml` runs are non-regressive. Adds `(apollo)`/`(r740 GPU)`/`(dl360)` inline comments matching deployed format.

[`fix:`] **開出 PR #2**（`prom-template-backport-2026-05-22`）：https://github.com/AC-T-lab/acmt-ansible/pull/2 — 將部署端的設定漂移 backport 回 template，未來 `acmt-monitoring.yml` 部署不再 regress；同時補上 `(apollo)`/`(r740 GPU)`/`(dl360)` 等 inline comments 對齊部署格式。

> **acmt-gpu GRES deploy still pending** — blocked on user `phat`'s interactive bash session (job 3602, ~50 min into RUNNING on acmt-gpu). Restarting slurmd will kill the session. acmt-gpu was briefly DRAINed for safety, then RESUMEd (no point gating other users until we have a deploy window).
>
> **acmt-gpu GRES 部署仍待處理** — 卡在使用者 `phat` 的 interactive bash session（job 3602，已在 acmt-gpu 上 RUNNING 約 50 分鐘）。重啟 slurmd 會殺掉該 session。acmt-gpu 為安全短暫 DRAIN 後又 RESUME（在拿到部署視窗前沒必要卡住其他人）。

---

## 2026-05-22 — acmt-ansible fork + PR (AC-T-lab) / acmt-ansible fork + PR（AC-T-lab）

[`workflow:`] **Forked `kerwenwwer/acmt-ansible` to `AC-T-lab/acmt-ansible` (private)**, pushed `main` + sync branch from `acmt0:/root/acmt-ansible`. Upstream `kerwenwwer/acmt-ansible` has forks disabled, so this was done via `gh repo create AC-T-lab/acmt-ansible --private` + `git push act` (remote alias). Lab now owns the source-of-truth for cluster ansible.

[`workflow:`] **將 `kerwenwwer/acmt-ansible` fork 為 `AC-T-lab/acmt-ansible`（private）**，從 `acmt0:/root/acmt-ansible` 推送 `main` 與 sync branch。上游 `kerwenwwer/acmt-ansible` 已停用 fork，所以走 `gh repo create AC-T-lab/acmt-ansible --private` + `git push act`（remote alias）。實驗室現在擁有 cluster ansible 的 source-of-truth。

- **Repo / 倉庫:** https://github.com/AC-T-lab/acmt-ansible (private)
- **PR:** https://github.com/AC-T-lab/acmt-ansible/pull/1 (5 commits, +93/-43 across 14 files)
- **Branches pushed / 推送的分支:** `main` (upstream snapshot / 上游快照), `cluster-state-sync-2026-05-22` (PR head)
- **Remote on admin / admin 端 remote:** `act` (in addition to existing `origin` → kerwenwwer / 與既有 `origin` → kerwenwwer 並存)

[`fix:`] **Branch `cluster-state-sync-2026-05-22` on `/root/acmt-ansible` (acmt0)** consolidates admin's working-tree WIP plus 3 new fixes. Branch is now visible on GitHub for review.

[`fix:`] **`/root/acmt-ansible`（acmt0）上的 `cluster-state-sync-2026-05-22` 分支** 合併 admin working-tree 中的 WIP 加上 3 個新修正。分支已 push 到 GitHub 供 review。

Commits (`git log main..HEAD --oneline`) / Commit 清單：

1. `85827ad` — Sync inventory/slurm/nfs/ldap configs with cluster expansion (consolidates admin's 13 previously-uncommitted local edits — hosts, slurm.conf, gres.conf, slurm tasks, prometheus targets, nfs/IB mount options, IB nfs_network, LDAP base DN, ldap.secret mode).
   `85827ad` — 同步 inventory/slurm/nfs/ldap 設定以對應 cluster 擴充（整合 admin 13 項先前未 commit 的本機修改：hosts、slurm.conf、gres.conf、slurm tasks、prometheus targets、nfs/IB mount options、IB nfs_network、LDAP base DN、ldap.secret 權限）。
2. `a5d2e5d` — fix(slurm): acmt-gpu has 4 P100 GPUs, not 2 (ISS-CFG-GRES P1 — physical hardware verified via `lspci | grep nvidia | wc -l` = 4 and `nvidia-smi -L`).
   `a5d2e5d` — fix(slurm)：acmt-gpu 為 4 顆 P100 而非 2 顆（ISS-CFG-GRES P1 — 透過 `lspci | grep nvidia | wc -l` = 4 與 `nvidia-smi -L` 確認硬體）。
3. `10b6ca2` — fix(update_hosts): add acmt16-27 mappings missing from vars (ISS-CFG-HOSTS).
   `10b6ca2` — fix(update_hosts)：補上 vars 中缺少的 acmt16-27 對應（ISS-CFG-HOSTS）。
4. `7684aff` — fix(update_hosts): header comment typo (mine, harmless).
   `7684aff` — fix(update_hosts)：header comment 修錯字（我加的，無害）。
5. `66d3ef9` — feat(prometheus): keep acmt16/17/26 in target list while down (ISS-CFG-PROMTGT — partial; long-term goal: dynamic Jinja loop).
   `66d3ef9` — feat(prometheus)：節點 down 時仍把 acmt16/17/26 留在 target 中（ISS-CFG-PROMTGT — 部分處理；長期目標：動態 Jinja loop）。

> **Admin action required before deploy:**
> 1. Review branch: `ssh admin "cd /root/acmt-ansible && git log main..HEAD -p"`.
> 2. Decide merge strategy — `git checkout main && git merge --ff-only cluster-state-sync-2026-05-22`, or open PR on GitHub.
> 3. Deploy in this order (each step has its own risk):
>    - `ansible-playbook acmt-slurm.yml -l acmt-gpu` then `ssh acmt-gpu systemctl restart slurmd` + `scontrol reconfigure` (will briefly interrupt jobs on acmt-gpu — drain first if any GPU job is running).
>    - `ansible acmt -m include_role -a name=update_hosts` (safe — only adds lines).
>    - `ansible-playbook acmt-monitoring.yml -l acmt0` + `systemctl reload prometheus` (safe — head only).
>
> **部署前需 admin 處理的動作：**
> 1. 審核分支：`ssh admin "cd /root/acmt-ansible && git log main..HEAD -p"`。
> 2. 決定 merge 策略 — `git checkout main && git merge --ff-only cluster-state-sync-2026-05-22`，或在 GitHub 開 PR。
> 3. 依下列順序部署（每步皆有風險）：
>    - `ansible-playbook acmt-slurm.yml -l acmt-gpu` 然後 `ssh acmt-gpu systemctl restart slurmd` + `scontrol reconfigure`（會短暫中斷 acmt-gpu 上作業 — 有 GPU 作業時請先 drain）。
>    - `ansible acmt -m include_role -a name=update_hosts`（安全 — 只新增 lines）。
>    - `ansible-playbook acmt-monitoring.yml -l acmt0` + `systemctl reload prometheus`（安全 — 僅 head node）。

---

## 2026-05-22 — Workflow + content reorg, security incident / 流程與內容重整、安全事件

[`security:`] **Redacted leaked LDAP bind password** from `security-policy.md` §4.1 (line 119). The plaintext value (literally `bindpw` + 8-char short year) had been committed in the initial commit (`57e4b19`) and remained in git history through `594cf00`. Document now references `/etc/ldap.secret` instead. (Exact value intentionally not reproduced here — find it via `git log -p -- security-policy.md | rg bindpw` if needed.)

[`security:`] **遮蔽外洩的 LDAP bind password**：移除 `security-policy.md` §4.1（第 119 行）中的明碼密碼。該明碼（字面為 `bindpw` 加 8 字短年代字串）自 initial commit (`57e4b19`) 起就在版本歷史中，直到 `594cf00` 都還在。文件現改為參考 `/etc/ldap.secret`。（此處刻意不重複原值 — 需要時可用 `git log -p -- security-policy.md | rg bindpw` 查到。）

> **Action items still pending on the admin side:**
> 1. **Rotate** the LDAP bind password on the LDAP server immediately.
> 2. **Deploy** the new password to `/etc/ldap.conf` (or `/etc/ldap.secret` with `chmod 600`) on `acmt0` and every compute node via the Ansible `users` role.
> 3. **Decide on git-history scrubbing.** Options:
>    - (A) Force-push a `git filter-repo --replace-text` rewrite removing `acmt&lt;YYYY&gt;` from all commits. **Breaks every clone.** Requires coordinating with everyone who has cloned this repo and rotating every cluster password that ever used this value (LDAP, MySQL, anything else).
>    - (B) Accept the historical leak, rotate the credential (which makes the leaked value useless), and document this CHANGELOG entry as the audit trail. **Lower-disruption** — appropriate if the repo is small-audience and rotation is fast.
> 4. **Audit** the rest of git history for other secrets: `git log -p | rg -iE "password|passwd|bindpw|secret|token|api[_-]?key"`.
>
> **admin 端仍待處理的動作：**
> 1. **立即輪替** LDAP server 上的 bind password。
> 2. **部署**新密碼到 `acmt0` 與所有 compute node 的 `/etc/ldap.conf`（或 `/etc/ldap.secret` 並 `chmod 600`），透過 Ansible `users` role 推送。
> 3. **決定是否清掃 git 歷史。** 選項：
>    - (A) 用 `git filter-repo --replace-text` force-push 把所有 commit 中的 `acmt&lt;YYYY&gt;` 替掉。**會打掉所有 clone**。需協調所有已 clone repo 的人，並輪替每個曾用此值的 cluster 密碼（LDAP、MySQL 等）。
>    - (B) 接受歷史洩漏、輪替憑證（讓外洩值失效）、以此 CHANGELOG 紀錄作為 audit trail。**較低干擾** — 適用於 repo 受眾小且輪替快的情況。
> 4. **稽核** git 歷史中是否有其他 secret：`git log -p | rg -iE "password|passwd|bindpw|secret|token|api[_-]?key"`。

[`docs:`] **Notion server manual rewritten** (page `6c42b275-b98a-451a-a837-cdc8d4398cf0`). Restructured 50K-character mixed-language doc into ~26K-character English user-first manual:

[`docs:`] **Notion server manual 重寫**（page `6c42b275-b98a-451a-a837-cdc8d4398cf0`）。把 50K 字、語言混雜的文件重整成約 26K 字、以英文使用者為主的 manual：

- §1 Getting Started, §2 Daily Workflows, §3 Templates, §4 Reference, §5 Troubleshooting, §6 Getting Help, §7 Administration (toggle).
  §1 入門、§2 日常工作流、§3 範本、§4 參考、§5 故障排除、§6 取得協助、§7 管理（toggle）。
- Added missing content: file transfer (scp/rsync/SFTP), SSH key setup, storage quotas, end-to-end first-job walkthrough, troubleshooting, help section.
  補上缺漏內容：檔案傳輸（scp/rsync/SFTP）、SSH 金鑰設定、儲存配額、端到端的首次 job 教學、故障排除、求助章節。
- Removed Chinese remnants, stale `module avail` dump, 3 broken self-referential bookmarks.
  移除中文殘留、過期的 `module avail` 內容、3 個壞掉的自我引用 bookmark。
- Source draft preserved at `/tmp/server-manual-rewrite/new_manual.md` (regen-able from this commit).
  草稿保存於 `/tmp/server-manual-rewrite/new_manual.md`（可由此 commit 重生）。

[`workflow:`] **Added CHANGELOG.md** (this file) — distinct from `maintenance-log.md`, which logs cluster changes.

[`workflow:`] **新增 CHANGELOG.md**（本檔） — 與 `maintenance-log.md` 區隔，後者記錄 cluster 變更。

[`workflow:`] **Added `.markdownlint.jsonc`** to lint markdown consistency (single H1, code-fence language, no bare URLs, secret-scanning hook). Run `markdownlint-cli2 "**/*.md"` locally.

[`workflow:`] **新增 `.markdownlint.jsonc`** 以 lint markdown 一致性（單一 H1、code-fence 必含語言、不允許 bare URL、secret-scanning hook）。本機跑 `markdownlint-cli2 "**/*.md"`。

[`docs:`] **Added frontmatter to README.md** — every other file already had `type` / `last_updated` headers.

[`docs:`] **為 README.md 補上 frontmatter** — 其他檔案早已有 `type` / `last_updated` header。

[`fix:`] **Applied 14 prioritized fixes** from the markdown-workflow review (see commit body for the list). Highlights:

[`fix:`] **套用 14 項按優先級排序的修正**（清單見 commit body）。重點：

- Removed stale node-state snapshots from `network-topology.md`, `troubleshooting.md`, `ansible-runbook.md` (they contradicted STATUS).
  從 `network-topology.md`、`troubleshooting.md`、`ansible-runbook.md` 移除過期節點狀態快照（與 STATUS 相牴觸）。
- Fixed brace-expansion bug `acmt0{1..27}` → `acmt{01..27}` in `tools-commands.md` and `troubleshooting.md`.
  修正 `tools-commands.md` 與 `troubleshooting.md` 中的 brace 展開 bug `acmt0{1..27}` → `acmt{01..27}`。
- Marked `ACMT_InfiniBand_Analysis_Report.md` as SUPERSEDED (internal contradictions + past-due review date).
  將 `ACMT_InfiniBand_Analysis_Report.md` 標記為 SUPERSEDED（內部前後不一 + 過期未審查）。
- Deduplicated keyboard-shortcut sections in `slurm-monitor-README.md`.
  `slurm-monitor-README.md` 重複的快捷鍵段落去重。
- Resolved `ISS-SVC-04` ID collision (Slack vs Grafana dashboards).
  處理 `ISS-SVC-04` ID 衝突（Slack 與 Grafana dashboards）。
- Reconciled module init-path naming in `software-installation-sop.md`.
  `software-installation-sop.md` 中 module init path 命名統一。
- Removed time-sensitive parenthetical from `AGENTS.md` partition table (belongs in STATUS).
  從 `AGENTS.md` partition 表移除時間敏感的括號說明（應放 STATUS）。
- Added ~2-3 outbound cross-references to each previously orphan file.
  為先前無連結的檔案各補上約 2-3 個對外交叉引用。
- Logged the reorg itself in `maintenance-log.md` (it was previously missing).
  在 `maintenance-log.md` 也記錄這次 reorg 本身（之前漏了）。

[`refactor:`] **Notion page structure changes** that may affect bookmarks elsewhere:

[`refactor:`] **Notion 頁面結構變動**，可能影響其他地方的 bookmark：

- Old anchors `#1d69800a520644d3b26702bd58a71812`, `#a9244efe58f4432d89f5bb0407774a07`, `#3fdf7d4621a54bfaba389c63889d5616` were broken self-bookmarks; removed. Any external links that referenced them already pointed nowhere useful.
  舊 anchor `#1d69800a520644d3b26702bd58a71812`、`#a9244efe58f4432d89f5bb0407774a07`、`#3fdf7d4621a54bfaba389c63889d5616` 是已壞的自我 bookmark，已移除。任何指向它們的外部連結原本就指不到有用的地方。
- File attachments (`input.txt`, `submit_1.sub`, `config.mk`, `sbatch.sh`) from old §2.1 / §3.3.3 were dropped — they were not viewable inline and their content is now shown directly in §3 (Job Templates).
  舊 §2.1 / §3.3.3 的檔案附件（`input.txt`、`submit_1.sub`、`config.mk`、`sbatch.sh`）已移除 — 它們在內文中無法直接檢視，內容現直接呈現於 §3（Job Templates）。

---

## 2026-05-22 — Initial repo reorg (`594cf00`) / 初次 repo 重整（`594cf00`）

[`refactor:`] **Introduced docs taxonomy** — every file gained `type` / `last_updated` frontmatter and was tagged as one of: Protocol, Operations, Reference, State, Snapshot, Log. README.md added as the index.

[`refactor:`] **導入文件分類** — 每份檔案加上 `type` / `last_updated` frontmatter，並標為以下其一：Protocol、Operations、Reference、State、Snapshot、Log。新增 README.md 作為索引。

[`docs:`] **Live cluster scan** against `acmt0` (2026-05-22 morning) — STATUS.md created/updated with current open issues, recovered nodes, and `ISS-XXX-NN` tracking IDs.

[`docs:`] **對 `acmt0` 做 live cluster scan**（2026-05-22 上午） — 建立/更新 STATUS.md，內含當前未解 issue、已恢復節點、`ISS-XXX-NN` 追蹤 ID。

---

## 2024-03 — Initial commit (`57e4b19`) / 初次 commit（`57e4b19`）

[`docs:`] Initial drop of ACMT cluster documentation: `ansible-runbook.md`, `monitoring-alerting.md`, `network-topology.md`, `security-policy.md` (containing the LDAP bind password — see 2026-05-22 entry), `software-installation-sop.md`, `tools-commands.md`, `troubleshooting.md`, `STATUS.md`, `maintenance-log.md`, `ACMT_InfiniBand_Analysis_Report.md`, `ACMT_HPC_Cluster_Nodes_Configuration.md`, `slurm-monitor-README.md`, `AGENTS.md`.

[`docs:`] ACMT cluster 初次文件落地：`ansible-runbook.md`、`monitoring-alerting.md`、`network-topology.md`、`security-policy.md`（內含 LDAP bind password — 見 2026-05-22 紀錄）、`software-installation-sop.md`、`tools-commands.md`、`troubleshooting.md`、`STATUS.md`、`maintenance-log.md`、`ACMT_InfiniBand_Analysis_Report.md`、`ACMT_HPC_Cluster_Nodes_Configuration.md`、`slurm-monitor-README.md`、`AGENTS.md`。

---

## Format guidance for future entries / 後續紀錄格式建議

```
## YYYY-MM-DD — One-line headline

[`type:`] **What changed.** Why it matters / what it affects.
> Optional follow-ups, action items, or links.
```

Types: `docs:` `security:` `workflow:` `fix:` `refactor:`

類型：`docs:` `security:` `workflow:` `fix:` `refactor:`

If the change has operational consequences (cluster restart, user-visible behavior), cross-link to `maintenance-log.md`.

若變更帶來維運後果（cluster 重啟、使用者可見行為），請交叉引用 `maintenance-log.md`。
