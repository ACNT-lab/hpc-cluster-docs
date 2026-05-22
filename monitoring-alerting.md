---
title: ACMT HPC Monitoring & Alerting | ACMT HPC 監控與告警
type: Reference + Operations
last_updated: 2026-05-22
source_of_truth: This file (topology, rule templates); `/etc/prometheus/`, `/etc/alertmanager/` (live config); `STATUS.md` §1.2 (open TODO)
---

# ACMT HPC Cluster — Monitoring & Alerting / ACMT HPC 集群 — 監控與告警

> Use live commands to inspect dynamic state (target health, active alerts, SMTP settings). This document records the **infrastructure topology and configuration templates**; open issues are tracked in [`STATUS.md`](STATUS.md) §1.2.
>
> **動態狀態請以指令查詢**（targets 健康、active alerts、SMTP 設定狀態）。本檔記錄 **infrastructure topology 與設定模板**，open issues 見 [`STATUS.md`](STATUS.md) §1.2。

## 1. Infrastructure Overview / 基礎架構概覽

| Component / 元件 | Host / 主機 | Port / 連接埠 | Deployment / 部署狀態 |
|-----------|------|------|------------|
| Prometheus | acmt0 | 9090 | Deployed |
| Grafana | acmt0 | 3000 | Deployed |
| Alertmanager | acmt0 | 9093 | Deployed (v0.27.0, 2026-05-21) |
| node_exporter | All nodes / 所有節點 | 9100 | Deployed |
| slurm_exporter | acmt0 | 8080 | Deployed |

Service-status checks:

執行狀態檢查：

```bash
systemctl status prometheus grafana-server alertmanager
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health}'
```

### 1.1 Prometheus Scrape Targets / Prometheus 抓取目標

Config file / 設定檔：`/etc/prometheus/prometheus.yml`

| Group / 群組 | Hosts / 主機 |
|-------|-------|
| local | acmt0 (head), localhost (prometheus, slurm_exporter) |
| mgmt | acmt-storage, acmt01-15, acmt-gpu (.10-.26, .32) |
| mgmt-2 | acmt16-27 (added 2026-05-21 / 加入於 2026-05-21) |

> Live health query / 即時健康狀態查詢：
>
> `curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up")'`
>
> Some nodes are expected offline (see STATUS.md §1.1) — those targets will report `down`, which is a known condition.
>
> 部分節點預期離線（見 STATUS.md §1.1）— 該 targets 會回報 `down`，屬已知狀況。
>
> **Currently down node_exporter targets (2026-05-22 scan) / 目前 down 的 node_exporter targets（2026-05-22 scan）**:
> - acmt14 (192.168.1.25) — corresponds to ISS-NODE-04 (node also Slurm DRAINED) / 對應 ISS-NODE-04（節點同時 Slurm DRAINED）
> - acmt15 reports up in Prometheus, but acmt14/16/17/25/26 are down; notably **acmt25 has returned to Slurm idle but node_exporter is still offline** (ISS-NODE-08) / acmt15 在 Prom 端 up，但 acmt14/16/17/25/26 顯示 down；其中 **acmt25 Slurm 已恢復 idle 但 node_exporter 仍未上線**（ISS-NODE-08）
> - acmt16/17 (.27/.28) — corresponds to ISS-NODE-06/07 (nodes down since 2025-07-21) / 對應 ISS-NODE-06/07（節點本身 down 自 2025-07-21）
> - acmt26 (.38) — corresponds to ISS-NODE-09 (node down since 2026-03-19) / 對應 ISS-NODE-09（節點本身 down 自 2026-03-19）

### 1.2 Alerting Pipeline / 告警管線

| Component / 元件 | Deployment / 部署狀態 | Config path / 設定路徑 |
|-----------|------------|-------------|
| Alert rules / 告警規則 | Deployed (9 rules, 2026-05-21) | `/etc/prometheus/alert-rules.yml` |
| Alertmanager | Deployed (v0.27.0, systemd-managed) | `/etc/alertmanager/alertmanager.yml` |
| Email notifications / Email 告警 | **TODO: SMTP smarthost not configured / SMTP smarthost 未設定** | Same file (`global.smtp_smarthost`) / 同上 |
| Slack / webhook | **TODO: not yet configured / 尚未配置** | Same file (`receivers`) / 同上 |

> See [`STATUS.md`](STATUS.md) §1.2 (ISS-SVC-01 ~ ISS-SVC-05) for full TODO details.
>
> 完整 TODO 細節見 [`STATUS.md`](STATUS.md) §1.2 (ISS-SVC-01 ~ ISS-SVC-05)。

---

## 2. Prometheus Alert Rules / Prometheus 告警規則

### 2.1 Installation / 安裝

Create `/etc/prometheus/alert-rules.yml`:

建立 `/etc/prometheus/alert-rules.yml`：

```yaml
groups:
  - name: acmt-cluster
    interval: 30s
    rules:
```

Then add to `/etc/prometheus/prometheus.yml`:

接著加入 `/etc/prometheus/prometheus.yml`：

```yaml
rule_files:
  - /etc/prometheus/alert-rules.yml
```

Reload / 重新載入：`curl -X POST http://localhost:9090/-/reload`

### 2.2 Recommended Rules / 建議規則

#### Node-level Rules / 節點層級規則

These rules cover the basic health of each compute node — reachability, disk, memory, CPU load, clock skew, and NIC flap.

這些規則涵蓋每個計算節點的基本健康狀態 — 連線可達性、磁碟、記憶體、CPU 負載、時鐘漂移、網卡振盪。

```yaml
  - alert: NodeDown
    expr: up{job="node_exporter"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.instance }} is down"
      description: "{{ $labels.instance }} has been unreachable for >2 minutes"

  - alert: NodeHighDiskUsage
    expr: (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 0.90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} disk >90%"
      description: "{{ $labels.instance }} root disk is {{ $value | humanizePercentage }} full"

  - alert: NodeDiskFull
    expr: (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 0.97
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "{{ $labels.instance }} disk CRITICAL >97%"

  - alert: NodeHighMemoryUsage
    expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.95
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} memory >95%"
      description: "Available: {{ $value | humanizePercentage }}"

  - alert: NodeHighCpuLoad
    expr: node_load15 / on(instance) count(node_cpu_seconds_total{mode="user"}) by(instance) > 0.9
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} load15 >90% of CPUs"

  - alert: NodeClockSkew
    expr: abs(node_timex_offset_seconds) > 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} clock skew >1s"

  - alert: NodeNetworkFlapping
    expr: rate(node_network_carrier_changes_total[15m]) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} network interface flapping"
```

#### Slurm-level Rules / Slurm 層級規則

These rules surface Slurm scheduler state — drained nodes, idle-node depletion, and long pending queues.

這些規則暴露 Slurm 排程器狀態 — drain 節點、idle 節點耗盡、長時 pending 佇列。

```yaml
  - alert: SlurmNodeDown
    expr: slurm_node_cpu_alloc{status=~"down.*|drained.*"} > 0
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Slurm node {{ $labels.node }} is {{ $labels.status }}"
      description: "Node {{ $labels.node }} has state {{ $labels.status }}"

  - alert: SlurmNoIdleNodes
    expr: sum(slurm_node_cpu_alloc{status="idle"}) == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "No idle nodes available"
      description: "All nodes are allocated, mixed, or down"

  - alert: SlurmJobsPendingLong
    expr: slurm_account_jobs_pending > 10
    for: 15m
    labels:
      severity: info
    annotations:
      summary: "{{ $value }} jobs pending >15 min"
      description: "Pending jobs may indicate resource shortage"

  - alert: SlurmExporterDown
    expr: up{job="slurm_exporter"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Slurm exporter is down"
      description: "Cannot monitor Slurm state"
```

#### Prometheus-level Rules / Prometheus 自身規則

These rules guard the monitoring stack itself — target reachability and config-reload status.

這些規則保護監控堆疊本身 — target 可達性與設定重新載入狀態。

```yaml
  - alert: PrometheusTargetMissing
    expr: up{job=~".*"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Target {{ $labels.instance }} ({{ $labels.job }}) is down"
      description: "{{ $labels.instance }} has been unreachable for >2 minutes"

  - alert: PrometheusConfigurationReloadFailed
    expr: prometheus_config_last_reload_successful == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Prometheus config reload failed"
```

---

## 3. Alertmanager Setup / Alertmanager 設定

### 3.1 Installation / 安裝

Download the binary, unpack, install to `/usr/local/bin/`, and create the config and data directories.

下載二進位、解壓、安裝到 `/usr/local/bin/`，並建立設定與資料目錄。

```bash
# Download alertmanager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar xf alertmanager-0.27.0.linux-amd64.tar.gz
sudo cp alertmanager-0.27.0.linux-amd64/alertmanager /usr/local/bin/
sudo cp alertmanager-0.27.0.linux-amd64/amtool /usr/local/bin/
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
```

### 3.2 Configuration / 設定檔

Create `/etc/alertmanager/alertmanager.yml`. Customize the SMTP smarthost and receiver email per the institution's setup.

建立 `/etc/alertmanager/alertmanager.yml`。SMTP smarthost 與接收 email 需依機構環境調整。

```yaml
global:
  resolve_timeout: 5m
  # Email (if SMTP available):
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@acmt.local'
  smtp_auth_username: ''
  smtp_auth_password: ''
  smtp_require_tls: false

route:
  group_by: ['severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'

  routes:
    - match:
        severity: critical
      receiver: 'critical'
      repeat_interval: 1h

receivers:
  - name: 'default'
    email_configs:
      - to: 'admin@example.com'

  - name: 'critical'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true

  # Example: Slack integration
  # - name: 'slack-critical'
  #   slack_configs:
  #     - api_url: 'https://hooks.slack.com/services/...'
  #       channel: '#hpc-alerts'
  #       title: '{{ .GroupLabels.severity }}: {{ .CommonAnnotations.summary }}'
```

### 3.3 Systemd Service / Systemd 服務單元

```ini
# /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager

Restart=always
User=alertmanager
Group=alertmanager

[Install]
WantedBy=multi-user.target
```

### 3.4 Wire to Prometheus / 接上 Prometheus

Add the `alerting` block to `/etc/prometheus/prometheus.yml` and reload Prometheus.

在 `/etc/prometheus/prometheus.yml` 加入 `alerting` 區塊並 reload Prometheus。

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

---

## 4. Notification Channels / 通知通道

### 4.1 Currently Available / 目前可用

| Channel / 通道 | Deployment / 部署 | Config / 設定 | Tracked issue / 追蹤 issue |
|---------|------------|--------|---------------|
| Email (SMTP) | Receiver exists but smarthost not filled / Receiver 設定存在但 smarthost 未填 | `/etc/alertmanager/alertmanager.yml` | STATUS.md ISS-SVC-01 |
| Slack | Not configured / 未配置 | Webhook URL pending / webhook URL 待提供 | STATUS.md ISS-SVC-05 |
| Grafana UI | Available / 可用 | http://acmt0:3000 | — |

### 4.2 Recommended Setup / 建議設定流程

1. **Email**: Configure `/etc/alertmanager/alertmanager.yml` with institutional SMTP. / 以機構 SMTP 設定 `/etc/alertmanager/alertmanager.yml`。
2. **Grafana Alerts**: Add notification channels in Grafana UI (Alerting → Contact points). / 在 Grafana UI 加入通知通道（Alerting → Contact points）。
3. **Slack/Telegram**: Optional but useful for quick awareness. / 選用，但對快速察覺事件有幫助。

---

## 5. Grafana Dashboards / Grafana 儀表板

### 5.1 Available Dashboards / 已可用儀表板

| Dashboard / 儀表板 | Source / 來源 | Notes / 備註 |
|-----------|--------|-------|
| Node Exporter Full | grafana.net ID 1860 | General node metrics / 通用節點指標 |
| Slurm Dashboard | Custom / grafana.net | Slurm-specific metrics / Slurm 專屬指標 |

### 5.2 Recommended Dashboard Panels / 建議儀表板面板

**Cluster Overview Dashboard / 集群總覽儀表板**:
- Total CPU cores (allocated / idle / down) / CPU 核心總數（已分配 / idle / down）
- Memory usage by node / 各節點記憶體使用率
- Disk usage by partition / 各分區磁碟使用率
- Node state heatmap (up/down/drain) / 節點狀態熱圖
- Job queue length over time / 作業佇列長度隨時間變化
- Network I/O per interface / 各介面網路 I/O

**Per-Node Drilldown / 單節點細部檢視**:
- CPU temperature / CPU 溫度
- Memory available / 可用記憶體
- Disk I/O / 磁碟 I/O
- Network errors / 網路錯誤
- Uptime / 運行時間

**Slurm Dashboard / Slurm 儀表板**:
- Jobs by partition / 各分區作業數
- Node states (alloc/mixed/idle/down) / 節點狀態
- Fairshare usage / Fairshare 使用率
- Job wait times / 作業等待時間

---

## 6. Alert Thresholds Reference / 告警閾值參考

| Alert / 告警 | Warning / 警告 | Critical / 危急 | Check interval / 檢查間隔 | Action / 動作 |
|-------|---------|----------|----------------|--------|
| Node down | — | 2m no response / 2 分鐘無回應 | 30s | Check power/network / 檢查電源/網路 |
| Disk usage | >90% | >97% | 5m | Clean or expand / 清理或擴容 |
| Memory usage | >95% | — | 5m | Check for runaway jobs / 檢查失控作業 |
| CPU load15 | >90% | — | 10m | Check running jobs / 檢查運行作業 |
| Clock skew | >1s | — | 2m | Check chrony/NTP / 檢查 chrony/NTP |
| Slurm node down | — | Immediate / 即時 | 2m | Check node state / 檢查節點狀態 |
| No idle nodes | All busy / 全部忙碌 | — | 5m | Consider draining jobs / 考慮 drain 作業 |
| Pending jobs | >10 | — | 15m | Check resource availability / 檢查資源可用性 |
| Exporter down | — | 1m | 30s | Restart exporter / 重啟 exporter |

---

## 7. Monitoring Gaps & Action Items / 監控缺口與待辦事項

Resolved items (completed 2026-05-21, see `maintenance-log.md`):

已解決項（2026-05-21 完成，見 `maintenance-log.md`）：

- [x] Added acmt16-27 to `/etc/prometheus/prometheus.yml`
- [x] Created `/etc/prometheus/alert-rules.yml` (9 rules)
- [x] Installed Alertmanager v0.27.0 with systemd service
- [x] Wired Alertmanager into Prometheus alerting config

Open items (tracked in [`STATUS.md`](STATUS.md) §1.2):

未解項（追蹤於 [`STATUS.md`](STATUS.md) §1.2）：

- **TODO (ISS-SVC-01)**: Configure SMTP smarthost and verify email alerts / 設定 SMTP smarthost 並驗證 email 告警
- **TODO (ISS-SVC-02)**: Define on-call / receiver list / 定義 on-call / receiver list
- **TODO (ISS-SVC-03)**: Add NFS mount health alert (`node_filesystem_avail_bytes{mountpoint="/home"}`) / 補 NFS mount health alert
- **TODO (ISS-SVC-04)**: Import Grafana dashboards (Node Exporter Full + Slurm) / 匯入 Grafana dashboards（Node Exporter Full + Slurm）

---

## 8. Quick Commands Reference / 快速指令參考

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | python3 -c "
import sys,json
for t in json.load(sys.stdin)['data']['activeTargets']:
    print('%-25s %-20s %s' % (t['labels']['instance'], t['labels']['job'], t['health']))
"

# Check all alert rules
curl -s http://localhost:9090/api/v1/rules | python3 -m json.tool

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload

# Check Alertmanager status (if installed)
curl -s http://localhost:9093/api/v2/status

# Query node memory
curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes'

# Query root disk usage
curl -s 'http://localhost:9090/api/v1/query?query=(1+-+node_filesystem_avail_bytes{mountpoint%3D%22/%22}+/+node_filesystem_size_bytes{mountpoint%3D%22/%22})'

# Query Slurm node state count
curl -s 'http://localhost:9090/api/v1/query?query=count(slurm_node_cpu_alloc)'

# Grafana health
curl -s http://localhost:3000/api/health
```
