---
title: ACMT HPC Cluster Docs — CHANGELOG
type: Log (append-only)
last_updated: 2026-05-22
source_of_truth: This file
---

# CHANGELOG

This file logs changes to **the documentation set itself**. Cluster operational changes (hardware swaps, software installs, configuration deploys) go in [maintenance-log.md](maintenance-log.md) instead.

> 新事件加到最上面（reverse chronological）。每筆紀錄附 `[type]` 標籤：`docs:` 文件變動、`security:` 安全相關、`workflow:` 流程/工具、`fix:` 修正錯誤、`refactor:` 結構調整。

---

## 2026-05-22 — Phase-1 deploy + PR #2 (config drift backport)

[`fix:`] **Deployed `update_hosts` role across cluster** (post PR #1 merge). Result: 24 reachable nodes returned `ok=1 changed=0` (idempotent — /etc/hosts was already accurate everywhere reachable). 5 nodes UNREACHABLE matching known down list (acmt14/16/17/25/26 — see STATUS §1.1).

[`fix:`] **Discovered prometheus config drift before regression occurred.** Pre-deploy `diff /etc/prometheus/prometheus.yml roles/prometheus/templates/prometheus.yml.j2` revealed the deployed file had manually-added `rule_files` + `alerting.alertmanagers → localhost:9093` sections that were NOT in the template. Running `ansible-playbook acmt-monitoring.yml` would have silently removed alertmanager wiring. **No regression occurred — caught by dry-diff.**

[`fix:`] **Opened PR #2** (`prom-template-backport-2026-05-22`): https://github.com/AC-T-lab/acmt-ansible/pull/2 — backports deployed config drift into template so future `acmt-monitoring.yml` runs are non-regressive. Adds `(apollo)`/`(r740 GPU)`/`(dl360)` inline comments matching deployed format.

> **acmt-gpu GRES deploy still pending** — blocked on user `phat`'s interactive bash session (job 3602, ~50 min into RUNNING on acmt-gpu). Restarting slurmd will kill the session. acmt-gpu was briefly DRAINed for safety, then RESUMEd (no point gating other users until we have a deploy window).

---

## 2026-05-22 — acmt-ansible fork + PR (AC-T-lab)

[`workflow:`] **Forked `kerwenwwer/acmt-ansible` to `AC-T-lab/acmt-ansible` (private)**, pushed `main` + sync branch from `acmt0:/root/acmt-ansible`. Upstream `kerwenwwer/acmt-ansible` has forks disabled, so this was done via `gh repo create AC-T-lab/acmt-ansible --private` + `git push act` (remote alias). Lab now owns the source-of-truth for cluster ansible.

- **Repo:** https://github.com/AC-T-lab/acmt-ansible (private)
- **PR:** https://github.com/AC-T-lab/acmt-ansible/pull/1 (5 commits, +93/-43 across 14 files)
- **Branches pushed:** `main` (upstream snapshot), `cluster-state-sync-2026-05-22` (PR head)
- **Remote on admin:** `act` (in addition to existing `origin` → kerwenwwer)

[`fix:`] **Branch `cluster-state-sync-2026-05-22` on `/root/acmt-ansible` (acmt0)** consolidates admin's working-tree WIP plus 3 new fixes. Branch is now visible on GitHub for review.

Commits (`git log main..HEAD --oneline`):
1. `85827ad` — Sync inventory/slurm/nfs/ldap configs with cluster expansion (consolidates admin's 13 previously-uncommitted local edits — hosts, slurm.conf, gres.conf, slurm tasks, prometheus targets, nfs/IB mount options, IB nfs_network, LDAP base DN, ldap.secret mode).
2. `a5d2e5d` — fix(slurm): acmt-gpu has 4 P100 GPUs, not 2 (ISS-CFG-GRES P1 — physical hardware verified via `lspci | grep nvidia | wc -l` = 4 and `nvidia-smi -L`).
3. `10b6ca2` — fix(update_hosts): add acmt16-27 mappings missing from vars (ISS-CFG-HOSTS).
4. `7684aff` — fix(update_hosts): header comment typo (mine, harmless).
5. `66d3ef9` — feat(prometheus): keep acmt16/17/26 in target list while down (ISS-CFG-PROMTGT — partial; long-term goal: dynamic Jinja loop).

> **Admin action required before deploy:**
> 1. Review branch: `ssh admin "cd /root/acmt-ansible && git log main..HEAD -p"`.
> 2. Decide merge strategy — `git checkout main && git merge --ff-only cluster-state-sync-2026-05-22`, or open PR on GitHub.
> 3. Deploy in this order (each step has its own risk):
>    - `ansible-playbook acmt-slurm.yml -l acmt-gpu` then `ssh acmt-gpu systemctl restart slurmd` + `scontrol reconfigure` (will briefly interrupt jobs on acmt-gpu — drain first if any GPU job is running).
>    - `ansible acmt -m include_role -a name=update_hosts` (safe — only adds lines).
>    - `ansible-playbook acmt-monitoring.yml -l acmt0` + `systemctl reload prometheus` (safe — head only).

---

## 2026-05-22 — Workflow + content reorg, security incident

[`security:`] **Redacted leaked LDAP bind password** from `security-policy.md` §4.1 (line 119). The plaintext value (literally `bindpw` + 8-char short year) had been committed in the initial commit (`57e4b19`) and remained in git history through `594cf00`. Document now references `/etc/ldap.secret` instead. (Exact value intentionally not reproduced here — find it via `git log -p -- security-policy.md | rg bindpw` if needed.)

> **⚠️ Action items still pending on the admin side:**
> 1. **Rotate** the LDAP bind password on the LDAP server immediately.
> 2. **Deploy** the new password to `/etc/ldap.conf` (or `/etc/ldap.secret` with `chmod 600`) on `acmt0` and every compute node via the Ansible `users` role.
> 3. **Decide on git-history scrubbing.** Options:
>    - (A) Force-push a `git filter-repo --replace-text` rewrite removing `acmt&lt;YYYY&gt;` from all commits. **Breaks every clone.** Requires coordinating with everyone who has cloned this repo and rotating every cluster password that ever used this value (LDAP, MySQL, anything else).
>    - (B) Accept the historical leak, rotate the credential (which makes the leaked value useless), and document this CHANGELOG entry as the audit trail. **Lower-disruption** — appropriate if the repo is small-audience and rotation is fast.
> 4. **Audit** the rest of git history for other secrets: `git log -p | rg -iE "password|passwd|bindpw|secret|token|api[_-]?key"`.

[`docs:`] **Notion server manual rewritten** (page `6c42b275-b98a-451a-a837-cdc8d4398cf0`). Restructured 50K-character mixed-language doc into ~26K-character English user-first manual:
- §1 Getting Started, §2 Daily Workflows, §3 Templates, §4 Reference, §5 Troubleshooting, §6 Getting Help, §7 Administration (toggle).
- Added missing content: file transfer (scp/rsync/SFTP), SSH key setup, storage quotas, end-to-end first-job walkthrough, troubleshooting, help section.
- Removed Chinese remnants, stale `module avail` dump, 3 broken self-referential bookmarks.
- Source draft preserved at `/tmp/server-manual-rewrite/new_manual.md` (regen-able from this commit).

[`workflow:`] **Added CHANGELOG.md** (this file) — distinct from `maintenance-log.md`, which logs cluster changes.

[`workflow:`] **Added `.markdownlint.jsonc`** to lint markdown consistency (single H1, code-fence language, no bare URLs, secret-scanning hook). Run `markdownlint-cli2 "**/*.md"` locally.

[`docs:`] **Added frontmatter to README.md** — every other file already had `type` / `last_updated` headers.

[`fix:`] **Applied 14 prioritized fixes** from the markdown-workflow review (see commit body for the list). Highlights:
- Removed stale node-state snapshots from `network-topology.md`, `troubleshooting.md`, `ansible-runbook.md` (they contradicted STATUS).
- Fixed brace-expansion bug `acmt0{1..27}` → `acmt{01..27}` in `tools-commands.md` and `troubleshooting.md`.
- Marked `ACMT_InfiniBand_Analysis_Report.md` as SUPERSEDED (internal contradictions + past-due review date).
- Deduplicated keyboard-shortcut sections in `slurm-monitor-README.md`.
- Resolved `ISS-SVC-04` ID collision (Slack vs Grafana dashboards).
- Reconciled module init-path naming in `software-installation-sop.md`.
- Removed time-sensitive parenthetical from `AGENTS.md` partition table (belongs in STATUS).
- Added ~2-3 outbound cross-references to each previously orphan file.
- Logged the reorg itself in `maintenance-log.md` (it was previously missing).

[`refactor:`] **Notion page structure changes** that may affect bookmarks elsewhere:
- Old anchors `#1d69800a520644d3b26702bd58a71812`, `#a9244efe58f4432d89f5bb0407774a07`, `#3fdf7d4621a54bfaba389c63889d5616` were broken self-bookmarks; removed. Any external links that referenced them already pointed nowhere useful.
- File attachments (`input.txt`, `submit_1.sub`, `config.mk`, `sbatch.sh`) from old §2.1 / §3.3.3 were dropped — they were not viewable inline and their content is now shown directly in §3 (Job Templates).

---

## 2026-05-22 — Initial repo reorg (`594cf00`)

[`refactor:`] **Introduced docs taxonomy** — every file gained `type` / `last_updated` frontmatter and was tagged as one of: Protocol, Operations, Reference, State, Snapshot, Log. README.md added as the index.

[`docs:`] **Live cluster scan** against `acmt0` (2026-05-22 morning) — STATUS.md created/updated with current open issues, recovered nodes, and `ISS-XXX-NN` tracking IDs.

---

## 2024-03 — Initial commit (`57e4b19`)

[`docs:`] Initial drop of ACMT cluster documentation: `ansible-runbook.md`, `monitoring-alerting.md`, `network-topology.md`, `security-policy.md` (containing the LDAP bind password — see 2026-05-22 entry), `software-installation-sop.md`, `tools-commands.md`, `troubleshooting.md`, `STATUS.md`, `maintenance-log.md`, `ACMT_InfiniBand_Analysis_Report.md`, `ACMT_HPC_Cluster_Nodes_Configuration.md`, `slurm-monitor-README.md`, `AGENTS.md`.

---

## Format guidance for future entries

```
## YYYY-MM-DD — One-line headline

[`type:`] **What changed.** Why it matters / what it affects.
> Optional follow-ups, action items, or links.
```

Types: `docs:` `security:` `workflow:` `fix:` `refactor:`

If the change has operational consequences (cluster restart, user-visible behavior), cross-link to `maintenance-log.md`.
