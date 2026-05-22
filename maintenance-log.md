---
title: ACMT HPC Cluster — Maintenance Log
type: Log (append-only)
last_updated: 2026-05-22
source_of_truth: This file (canonical history of cluster changes)
---

# ACMT HPC Cluster — Maintenance Log

> 新事件請以最新日期為頂，沿用本檔下方的 Template 格式。已解決的 issue 請從 [`STATUS.md`](STATUS.md) 移除並在此留紀錄。

## Format

Every entry follows this template:

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

## 2026-05-22: Documentation reorg + LDAP password redaction

**Category**: other (documentation)
**Author**: claude+latteine
**Duration**: same session
**Nodes affected**: none (docs only)
**Services affected**: none (docs only; LDAP password rotation still pending on admin side — see CHANGELOG.md)
**Summary**: Repo-wide doc reorg + Notion server-manual rewrite; redacted leaked LDAP bind password from security-policy.md; applied 14 prioritized markdown fixes (see CHANGELOG.md).
**Details**:
- Reconciled stale node states across `network-topology.md`, `troubleshooting.md`, `ansible-runbook.md`, `AGENTS.md` — STATUS.md is now the single source-of-truth for node state.
- Fixed brace-expansion bug `acmt0{1..27}` → `acmt{01..27}` in health-check loops.
- Resolved `ISS-SVC-04` ID collision (Slack moved to `ISS-SVC-05`).
- Marked `ACMT_InfiniBand_Analysis_Report.md` as SUPERSEDED.
- Deduplicated keyboard-shortcut sections in `slurm-monitor-README.md`; closed unbalanced code fence in `ansible-runbook.md`.
- Added cross-references across previously orphan files.
**Rollback**: `git revert <commit-hash>` (hash unknown at draft time; check `git log` after commit lands).
**Verification**: `scripts/check-secrets.sh` exits 0 on the working tree (covers the historical bind password + other generic secret patterns); code fences in `ansible-runbook.md` are balanced (even count via `awk` line-counter).

---

## 2026-05-21: GSL 2.8 installation

**Category**: software-install
**Author**: root
**Duration**: 30min
**Nodes affected**: all (via NFS /opt)
**Services affected**: none
**Summary**: Installed GNU Scientific Library 2.8 as test of software-installation-sop.md
**Details**:
- Downloaded gsl-2.8.tar.gz to /opt/src/
- Built with ./configure --prefix=/opt/gsl/2.8 CC=gcc CXX=g++ FC=gfortran
- make -j$(nproc) && make install
- Created modulefile: /opt/modulefiles/gsl/2.8
- Tested: module load, gsl-config, test C program compilation, Slurm job 3582 on acmt09
**Known issue**: `module` command not available in Slurm batch jobs — requires `source /usr/share/modules/init/bash`
**Rollback**: `rm -rf /opt/gsl/2.8 /opt/modulefiles/gsl/2.8`
**Verification**: `module load gsl/2.8 && gsl-config --version` returns 2.8

---

## 2026-05-21: Software Installation SOP documented

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all
**Summary**: Created /root/software-installation-sop.md covering standard build procedures, modulefile templates, and Slurm testing. Verified by installing GSL 2.8.

---

## 2026-05-21: Security Policy documented

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all
**Summary**: Created /root/security-policy.md covering firewall, SSH, LDAP, NFS, password policy, incident response.

---

## 2026-05-21: Network Topology documented

**Category**: config-change
**Author**: root
**Duration**: N/A
**Nodes affected**: all
**Summary**: Created /root/network-topology.md with IP→MAC mapping, IB fabric port mapping, routing table, rack layout from server.png/server2.png.

---

## 2026-05-21: Prometheus monitoring — full setup

**Category**: config-change
**Author**: root
**Duration**: 30min
**Nodes affected**: all
**Services affected**: Prometheus (restarted)
**Summary**: Completed monitoring infrastructure: added missing nodes to scrape config, created alert rules, installed Alertmanager
**Details**:
- Added acmt16-27 (12 nodes) to `/etc/prometheus/prometheus.yml`
- Created `/etc/prometheus/alert-rules.yml` with 9 rules (NodeDown, DiskFull, Memory, CPU, SlurmNodeDown, etc.)
- Downloaded and installed Alertmanager v0.27.0
- Created `/etc/alertmanager/alertmanager.yml` with email receivers (SMTP not configured — placeholder only)
- Created systemd service and enabled on boot
- Wired Alertmanager into Prometheus alerting config
**Known issue**: Email alerts require SMTP server — set `smtp_smarthost` in `/etc/alertmanager/alertmanager.yml`
**Rollback**: `systemctl stop alertmanager && systemctl disable alertmanager`; revert prometheus.yml
**Verification**: `curl -s http://localhost:9090/api/v1/alerts` shows 19 pending alerts

---

## 2024-03-18: Initial Cluster Deployment

**Category**: install
**Author**: kc-lin / kerwin
**Duration**: unknown
**Nodes affected**: all
**Summary**: Initial deployment of ACMT HPC cluster. Set up acmt0 (headnode), acmt-storage, 25 compute nodes. Installed Slurm, LDAP, NFS, InfiniBand.
**Known config**:
- Slurm config: /etc/slurm/slurm.conf (created 2024-03-22)
- LDAP base: dc=acmt, admin password set
- NFS exports: /home, /opt from acmt-storage
- InfiniBand: Mellanox MSB7700, ConnectX-4 cards
- Munge key: /etc/munge/munge.key (created 2024-03-18)

---

## 2024-03-22: SlurmDBD + MySQL setup

**Category**: config-change
**Author**: root
**Summary**: Configured slurmdbd with MySQL backend on acmt0. StoragePass set in /etc/slurm/slurmdbd.conf.

---

## 2025-09-05: GCC 15.2 installation

**Category**: software-install
**Author**: kc-lin
**Summary**: Built GCC 15.2 from source and deployed via /root/install_gcc15.2_with_module_and_slurm.sh. Modulefile at /opt/modulefiles/gcc/15.2.

---

## Template for new entries

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
