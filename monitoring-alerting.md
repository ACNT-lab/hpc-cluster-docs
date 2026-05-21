# ACMT HPC Cluster — Monitoring & Alerting

## 1. Infrastructure Overview

| Component | Host | Port | Status |
|-----------|------|------|--------|
| Prometheus | acmt0 | 9090 | ✅ Running |
| Grafana | acmt0 | 3000 | ✅ Running |
| Alertmanager | acmt0 | — | ❌ **Not installed** |
| node_exporter | All nodes | 9100 | ✅ Running (see §1.1) |
| slurm_exporter | acmt0 | 8080 | ✅ Running |

### 1.1 Prometheus Targets Currently Scraped

```
local:    acmt0 (head), localhost (prometheus, slurm_exporter)
mgmt:     acmt-storage, acmt01-15, acmt-gpu  (.10-.26, .32)
missing:  acmt16-27 (NOT in prometheus.yml — config gap!)
```

**Gap**: 12 nodes (acmt16~27) are missing from `scrape_configs` in `/etc/prometheus/prometheus.yml`. Even though some are down, running nodes (acmt18-21,27) should be added.

### 1.2 Current Alerting State

| Component | Status | Notes |
|-----------|--------|-------|
| Alert rules | ❌ **None** | Prometheus has zero alerting rules |
| Alertmanager | ❌ **Not installed** | No notification routing |
| Notifications | ❌ **None** | No email/Slack/webhook configured |

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

| Channel | Status | Config |
|---------|--------|--------|
| Email (SMTP) | ❌ Not configured | Needs SMTP server info |
| Slack | ❌ Not configured | Needs webhook URL |
| Grafana UI | ✅ Available | Login at http://acmt0:3000 |

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

- [ ] Add missing nodes (acmt16-27) to `/etc/prometheus/prometheus.yml`
- [ ] Create `/etc/prometheus/alert-rules.yml` with rules from §2
- [ ] Install and configure Alertmanager with email notifications
- [ ] Set up Grafana dashboards (Node Exporter Full + Slurm)
- [ ] Determine and configure SMTP server for alert notifications
- [ ] Define on-call rotation or escalation contacts (currently none)
- [ ] Add alert for NFS mount health (`node_filesystem_avail_bytes{mountpoint="/home"}`)

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
