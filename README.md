# ACMT HPC Cluster Documentation

This repository serves as the **knowledge base** for the AI server assistant managing the **ACMT HPC cluster** (acmt0 headnode). It contains all operational documentation, configuration references, and procedural guides used by the AI assistant to maintain and operate the cluster.

## Repository Structure

| File | Description |
|------|-------------|
| `AGENTS.md` | AI assistant system prompt — cluster overview, commands, workflows, troubleshooting |
| `ACMT_HPC_Cluster_Nodes_Configuration.md` | Node hardware specs, partitions, and Slurm configuration |
| `ACMT_InfiniBand_Analysis_Report.md` | InfiniBand fabric analysis and recommendations |
| `ansible-runbook.md` | Ansible playbook runbook for cluster deployment and maintenance |
| `maintenance-log.md` | Cluster maintenance history and changes |
| `monitoring-alerting.md` | Prometheus/Grafana monitoring setup and alerting rules |
| `network-topology.md` | Network architecture, VLANs, and routing |
| `security-policy.md` | Cluster security policies and access control |
| `slurm-monitor-README.md` | TUI Slurm monitor dashboard documentation |
| `software-installation-sop.md` | Standard operating procedures for software installation |
| `tools-commands.md` | Command reference for cluster management tools |
| `troubleshooting.md` | Common issues, diagnostics, and resolutions |

## Purpose

- **Centralized knowledge** for AI-assisted cluster administration
- **Live reference** updated as the cluster evolves
- **Single source of truth** for configurations, procedures, and operational knowledge

## Quick Start

```bash
# Check cluster status
acmt status

# List running jobs
acmt jobs

# View node information
acmt node-info <node>
```

See `AGENTS.md` for the complete assistant workflow and command reference.
