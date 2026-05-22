---
title: ACMT HPC Cluster Documentation | ACMT HPC 集群文件
type: Protocol
last_updated: 2026-05-22
source_of_truth: This file (index)
---

# ACMT HPC Cluster Documentation / ACMT HPC 集群文件

This repository is the AI-maintained knowledge base for the **ACMT HPC cluster** (acmt0 headnode). It centralizes operational documentation, configuration references, and process guides used by both human operators and AI assistants.

本 repository 是 **ACMT HPC cluster**（acmt0 headnode）的 AI 維護助手知識庫，集中操作文件、設定參考、與流程指引，供人類維運者與 AI 助手共用。

> 📅 **Change history lives in [CHANGELOG.md](CHANGELOG.md)** — that file tracks changes to this documentation set; cluster operational changes (hardware swaps, software installs, deploys) go in [maintenance-log.md](maintenance-log.md) instead.
>
> 📅 **文件變更紀錄請見 [CHANGELOG.md](CHANGELOG.md)** — 該檔追蹤本文件集自身的變動；cluster 上的維運變更（硬體置換、軟體安裝、部署）請查 [maintenance-log.md](maintenance-log.md)。

## Document Types / 文件分類

Every document declares its category in the frontmatter `type` field. AI assistants use this to judge data freshness and how to consume the file.

每份文件在頂端 frontmatter 標示分類，AI 助手據此判斷鮮度與使用情境：

| Type / 類型 | Meaning / 意義 | Usage / 使用方式 |
|------|------|---------|
| **Protocol** | Assistant behavior rules and policies / 助手行為規範、策略文件 | Must-read; decision basis / 必讀，作為決策依據 |
| **Operations** | SOPs, runbooks, troubleshooting flows / SOP、runbook、troubleshooting 流程 | Look up by scenario, follow step-by-step / 依場景檢索並依步驟執行 |
| **Reference** | Configuration, commands, hardware specs (low-velocity data) / 設定、命令、硬體規格等低頻變動資料 | Lookup / 查詢用 |
| **State** | Issues and TODOs tracked across sessions / 跨會話追蹤的 issue 與 TODO | **Always read at session start** / **每次起頭都應檢查** |
| **Snapshot** | One-off analysis reports (frozen at a date) / 一次性分析報告（凍結於日期） | Historical reference only; does not represent current state / 視為歷史參考，不代表現況 |
| **Log** | Append-only change history / append-only 變更歷史 | Write new events; look up past changes / 寫入新事件、回查過去變更 |

---

## Index / 索引

### Protocol — Assistant Behavior / 助手行為規範

| File / 檔案 | Description / 說明 |
|------|------|
| [`AGENTS.md`](AGENTS.md) | AI assistant system prompt — cluster overview, safety rules, tools, workflows / AI 助手 system prompt — cluster 概覽、安全規則、工具、工作流 |
| [`security-policy.md`](security-policy.md) | Cluster security policy and access control / 集群安全政策與存取控制 |

### State — Live Tracking / 即時追蹤

| File / 檔案 | Description / 說明 |
|------|------|
| [`STATUS.md`](STATUS.md) | **Must-read every session** — open issues, TODOs, dynamic-data commands / **每次會話必讀** — 已知未解 issue、TODO、動態抓取指令 |
| [`maintenance-log.md`](maintenance-log.md) | Cluster change history (append-only) / 變更歷史（append-only），記錄 cluster 變更 |
| [`CHANGELOG.md`](CHANGELOG.md) | Doc-set's own version history / 文件集本身的版本變更紀錄 |

### Operations — Procedures & SOPs / 流程與 SOP

| File / 檔案 | Description / 說明 |
|------|------|
| [`ansible-runbook.md`](ansible-runbook.md) | Ansible playbook runbook / Ansible playbook runbook |
| [`software-installation-sop.md`](software-installation-sop.md) | Software installation SOP / 軟體安裝 SOP |
| [`troubleshooting.md`](troubleshooting.md) | Failure-mode decision trees / 故障診斷決策樹 |
| [`monitoring-alerting.md`](monitoring-alerting.md) | Prometheus / Grafana / Alertmanager configuration and rules / Prometheus/Grafana/Alertmanager 設定與規則 |

### Reference — Configuration & Commands / 設定與命令

| File / 檔案 | Description / 說明 |
|------|------|
| [`ACMT_HPC_Cluster_Nodes_Configuration.md`](ACMT_HPC_Cluster_Nodes_Configuration.md) | Node hardware specs and partition layout / 節點硬體規格與分區結構 |
| [`network-topology.md`](network-topology.md) | Network architecture, VLANs, routing / 網路架構、VLAN、路由 |
| [`tools-commands.md`](tools-commands.md) | Command reference / 命令參考 |
| [`slurm-monitor-README.md`](slurm-monitor-README.md) | TUI Slurm monitor tool documentation / TUI Slurm monitor 工具文件 |

### Snapshot — Frozen Reports / 凍結報告

| File / 檔案 | Date / 日期 | Description / 說明 |
|------|------|------|
| [`ACMT_InfiniBand_Analysis_Report.md`](ACMT_InfiniBand_Analysis_Report.md) | 2026-01-25 | One-time InfiniBand fabric analysis / InfiniBand fabric 一次性分析 |

---

## Operating Principles / 使用原則

1. **Separate State from Protocol.** Time-sensitive data lives only in `STATUS.md` and `maintenance-log.md`; no other file should hold a snapshot.
   **State 與 Protocol 分離**：時間敏感資料只在 `STATUS.md` 與 `maintenance-log.md`，其他檔案不寫快照。

2. **TODO Contract.** Mark unfinished or pending items with `TODO: <target-state>`. Never use placeholder strings to pretend a task is complete.
   **TODO Contract**：未完成或待設定項目用 `TODO: <目標狀態>` 標示，禁止以 placeholder 假裝完成。

3. **Single Source of Truth.** Each file's frontmatter declares its authoritative source. Reference repeated content by link rather than duplicating it.
   **Single Source of Truth**：每份文件 frontmatter 標明其資料權威來源；重複內容請以連結引用。

4. **Fetch live data with commands.** Node state, job queues, utilization, etc. — run `acmt` / `sinfo` / `squeue` / a Prometheus query at the moment of need. Do not trust embedded tables.
   **Live data 用指令抓**：節點狀態、jobs、佔用率等請執行 `acmt` / `sinfo` / `squeue` / Prometheus query，不要信賴內嵌表格。

## Quick Start / 起手式

```bash
# Assistant warm-up / 助手起手式
cat AGENTS.md          # system behavior / 系統行為
cat STATUS.md          # open issues / 當前未解 issue

# Fetch live state / 抓即時狀態
acmt status            # cluster summary / cluster 摘要
acmt jobs              # job queue / 作業佇列
sinfo -R               # down/drain reasons / down/drain 原因
```

See [`tools-commands.md`](tools-commands.md) for the full command reference.

完整命令參考見 [`tools-commands.md`](tools-commands.md)。
