# ACMT HPC Cluster Documentation

本 repository 是 **ACMT HPC cluster** (acmt0 headnode) 的 AI 維護助手知識庫，集中所有操作文件、設定參考、與流程指引。

## Document Types

每份文件頂端 frontmatter 標示其分類，AI 助手可據此判斷鮮度與使用情境：

| Type | 意義 | 使用方式 |
|------|------|---------|
| **Protocol** | 助手行為規範、策略文件 | 必讀，作為決策依據 |
| **Operations** | SOP、runbook、troubleshooting 流程 | 依場景檢索並依步驟執行 |
| **Reference** | 設定、命令、硬體規格等低頻變動資料 | 查詢用 |
| **State** | 跨會話追蹤的 issue 與 TODO | **每次起頭都應檢查** |
| **Snapshot** | 一次性分析報告（凍結於日期） | 視為歷史參考，不代表現況 |
| **Log** | append-only 變更歷史 | 寫入新事件、回查過去變更 |

---

## Index

### Protocol — 助手行為規範

| 檔案 | 說明 |
|------|------|
| [`AGENTS.md`](AGENTS.md) | AI 助手 system prompt — cluster 概覽、安全規則、工具、工作流 |
| [`security-policy.md`](security-policy.md) | 集群安全政策與存取控制 |

### State — 即時追蹤

| 檔案 | 說明 |
|------|------|
| [`STATUS.md`](STATUS.md) | **每次會話必讀** — 已知未解 issue、TODO、動態抓取指令 |
| [`maintenance-log.md`](maintenance-log.md) | 變更歷史（append-only） |

### Operations — 流程與 SOP

| 檔案 | 說明 |
|------|------|
| [`ansible-runbook.md`](ansible-runbook.md) | Ansible playbook runbook |
| [`software-installation-sop.md`](software-installation-sop.md) | 軟體安裝 SOP |
| [`troubleshooting.md`](troubleshooting.md) | 故障診斷決策樹 |
| [`monitoring-alerting.md`](monitoring-alerting.md) | Prometheus/Grafana/Alertmanager 設定與規則 |

### Reference — 設定與命令

| 檔案 | 說明 |
|------|------|
| [`ACMT_HPC_Cluster_Nodes_Configuration.md`](ACMT_HPC_Cluster_Nodes_Configuration.md) | 節點硬體規格與分區結構 |
| [`network-topology.md`](network-topology.md) | 網路架構、VLAN、路由 |
| [`tools-commands.md`](tools-commands.md) | 命令參考 |
| [`slurm-monitor-README.md`](slurm-monitor-README.md) | TUI Slurm monitor 工具文件 |

### Snapshot — 凍結報告

| 檔案 | 日期 | 說明 |
|------|------|------|
| [`ACMT_InfiniBand_Analysis_Report.md`](ACMT_InfiniBand_Analysis_Report.md) | 2026-01-25 | InfiniBand fabric 一次性分析 |

---

## 使用原則

1. **State 與 Protocol 分離**：時間敏感資料只在 `STATUS.md` 與 `maintenance-log.md`，其他檔案不寫快照。
2. **TODO Contract**：未完成或待設定項目用 `TODO: <目標狀態>` 標示，禁止以 placeholder 假裝完成。
3. **Single Source of Truth**：每份文件 frontmatter 標明其資料權威來源；重複內容請以連結引用。
4. **Live data 用指令抓**：節點狀態、jobs、佔用率等請執行 `acmt`/`sinfo`/`squeue`/Prometheus query，不要信賴內嵌表格。

## Quick Start

```bash
# 助手起手式
cat AGENTS.md          # 系統行為
cat STATUS.md          # 當前未解 issue

# 抓即時狀態
acmt status            # cluster 摘要
acmt jobs              # 作業佇列
sinfo -R               # down/drain 原因
```

完整命令參考見 [`tools-commands.md`](tools-commands.md)。
