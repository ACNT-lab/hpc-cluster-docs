---
title: ACMT HPC Cluster — Monitoring & Alerting
type: Reference + Operations
last_updated: 2026-05-22
source_of_truth: This file (topology, rule templates); `/etc/prometheus/`, `/etc/alertmanager/` (live config); `STATUS.md` §1.2 (open TODO)
---

# ACMT HPC Cluster — Monitoring & Alerting

> **動態狀態請以指令查詢**（targets 健康、active alerts、SMTP 設定狀態）。本檔記錄 **infrastructure topology 與設定模板**，open issues 見 [`STATUS.md`](STATUS.md) §1.2。

## 1. Infrastructure Overview

| Component | Host | Port | Deployment |
|-----------|------|------|------------|
| Prometheus | acmt0 | 9090 | Deployed |
| Grafana | acmt0 | 3000 | Deployed |
| Alertmanager | acmt0 | 9093 | Deployed (v0.27.0, 2026-05-21) |
| node_exporter | All nodes | 9100 | Deployed |
| slurm_exporter | acmt0 | 8080 | Deployed |

執行狀態檢查：

```bash
systemctl status prometheus grafana-server alertmanager
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health}'
```

### 1.1 Prometheus Scrape Targets

設定檔：`/etc/prometheus/prometheus.yml`

| Group | Hosts |
|-------|-------|
| local | acmt0 (head), localhost (prometheus, slurm_exporter) |
| mgmt | acmt-storage, acmt01-15, acmt-gpu (.10-.26, .32) |
| mgmt-2 | acmt16-27 (加入於 2026-05-21) |

> 即時健康狀態：`curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health!="up")'`
>
> 部分節點預期離線（見 STATUS.md §1.1）— 該 targets 會回報 `down`，屬已知狀況。
>
> **目前 down 的 node_exporter targets（2026-05-22 scan）**：
> - acmt14 (192.168.1.25) — 對應 ISS-NODE-04（節點同時 Slurm DRAINED）
> - acmt15 在 Prom 端 up，但 acmt14/16/17/25/26 顯示 down；其中 **acmt25 Slurm 已恢復 idle 但 node_exporter 仍未上線**（ISS-NODE-08）
> - acmt16/17 (.27/.28) — 對應 ISS-NODE-06/07（節點本身 down 自 2025-07-21）
> - acmt26 (.38) — 對應 ISS-NODE-09（節點本身 down 自 2026-03-19）

### 1.2 Alerting Pipeline

| Component | Deployment | Config Path |
|-----------|------------|-------------|
| Alert rules | Deployed (9 rules, 2026-05-21) | `/etc/prometheus/alert-rules.yml` |
| Alertmanager | Deployed (v0.27.0, systemd-managed) | `/etc/alertmanager/alertmanager.yml` |
| Email notifications | **TODO: SMTP smarthost 未設定** | 同上 (`global.smtp_smarthost`) |
| Slack / webhook | **TODO: 尚未配置** | 同上 (`receivers`) |

> 完整 TODO 細節見 [`STATUS.md`](STATUS.md) §1.2 (ISS-SVC-01 ~ ISS-SVC-04)。

---

## 2. Prometheus Alert Rules

### 2.1 Installation

Create `/etc/prometheus/alert-rules.yml`:

```yaml
groups:
  - name: acmt-cluster
    interval: 30s
    rules:
```

Then add to `/etc/prometheus/prometheus.yml`:

```yaml
rule_files:
  - /etc/prometheus/alert-rules.yml
```

Reload: `curl -X POST http://localhost:9090/-/reload`

### 2.2 Recommended Rules

#### Node-level Rules

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

#### Slurm-level Rules

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

#### Prometheus-level Rules

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

## 3. Alertmanager Setup

### 3.1 Installation

```bash
# Download alertmanager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar xf alertmanager-0.27.0.linux-amd64.tar.gz
sudo cp alertmanager-0.27.0.linux-amd64/alertmanager /usr/local/bin/
sudo cp alertmanager-0.27.0.linux-amd64/amtool /usr/local/bin/
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
```

### 3.2 Configuration

Create `/etc/alertmanager/alertmanager.yml`:

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

### 3.3 Systemd Service

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

### 3.4 Wire to Prometheus

In `/etc/prometheus/prometheus.yml`:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
```

---

## 4. Notification Channels

### 4.1 Currently Available

| Channel | Deployment | Config | Tracked Issue |
|---------|------------|--------|---------------|
| Email (SMTP) | Receiver 設定存在但 smarthost 未填 | `/etc/alertmanager/alertmanager.yml` | STATUS.md ISS-SVC-01 |
| Slack | 未配置 | webhook URL 待提供 | STATUS.md ISS-SVC-04 |
| Grafana UI | Available | http://acmt0:3000 | — |

### 4.2 Recommended Setup

1. **Email**: Configure `/etc/alertmanager/alertmanager.yml` with institutional SMTP
2. **Grafana Alerts**: Add notification channels in Grafana UI (Alerting → Contact points)
3. **Slack/Telegram**: Optional but useful for quick awareness

---

## 5. Grafana Dashboards

### 5.1 Available Dashboards

| Dashboard | Source | Notes |
|-----------|--------|-------|
| Node Exporter Full | grafana.net ID 1860 | General node metrics |
| Slurm Dashboard | Custom / grafana.net | Slurm-specific metrics |

### 5.2 Recommended Dashboard Panels

**Cluster Overview Dashboard**:
- Total CPU cores (allocated / idle / down)
- Memory usage by node
- Disk usage by partition
- Node state heatmap (up/down/drain)
- Job queue length over time
- Network I/O per interface

**Per-Node Drilldown**:
- CPU temperature
- Memory available
- Disk I/O
- Network errors
- Uptime

**Slurm Dashboard**:
- Jobs by partition
- Node states (alloc/mixed/idle/down)
- Fairshare usage
- Job wait times

---

## 6. Alert Thresholds Reference

| Alert | Warning | Critical | Check Interval | Action |
|-------|---------|----------|----------------|--------|
| Node down | — | 2m no response | 30s | Check power/network |
| Disk usage | >90% | >97% | 5m | Clean or expand |
| Memory usage | >95% | — | 5m | Check for runaway jobs |
| CPU load15 | >90% | — | 10m | Check running jobs |
| Clock skew | >1s | — | 2m | Check chrony/NTP |
| Slurm node down | — | immediate | 2m | Check node state |
| No idle nodes | all busy | — | 5m | Consider draining jobs |
| Pending jobs | >10 | — | 15m | Check resource avail |
| Exporter down | — | 1m | 30s | Restart exporter |

---

## 7. Monitoring Gaps & Action Items

已解決項（2026-05-21 完成，見 `maintenance-log.md`）：

- [x] Added acmt16-27 to `/etc/prometheus/prometheus.yml`
- [x] Created `/etc/prometheus/alert-rules.yml` (9 rules)
- [x] Installed Alertmanager v0.27.0 with systemd service
- [x] Wired Alertmanager into Prometheus alerting config

未解項（追蹤於 [`STATUS.md`](STATUS.md) §1.2）：

- **TODO (ISS-SVC-01)**：設定 SMTP smarthost 並驗證 email 告警
- **TODO (ISS-SVC-02)**：定義 on-call / receiver list
- **TODO (ISS-SVC-03)**：補 NFS mount health alert（`node_filesystem_avail_bytes{mountpoint="/home"}`）
- **TODO (ISS-SVC-04)**：匯入 Grafana dashboards（Node Exporter Full + Slurm）

---

## 8. Quick Commands Reference

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
