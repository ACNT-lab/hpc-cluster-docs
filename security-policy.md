# ACMT HPC Cluster — Security Policy

## 1. Current Security Posture Assessment

### 1.1 Risk Summary

| Area | Status | Severity |
|------|--------|----------|
| Firewall (mgmt) | iptables INPUT/OUTPUT policy ACCEPT — no restrictions | **HIGH** |
| SSH Root Login | PermitRootLogin=yes | **HIGH** |
| SSH Password Auth | PasswordAuthentication=yes (on acmt0) | **HIGH** |
| LDAP Password Storage | {SSHA} — SHA1 (weak, no salt iteration) | **MEDIUM** |
| LDAP Bind Credential | Plaintext password in `/etc/ldap.conf` | **MEDIUM** |
| LDAP Transport | No TLS/SSL — plaintext on wire | **HIGH** |
| NFS | `no_root_squash` on `/home` and `/opt` | **HIGH** |
| Password Policy | PASS_MAX_DAYS=99999 (no expiry) | **MEDIUM** |
| Failed Login Protection | fail2ban installed but not confirmed enforcing SSH | **LOW** |
| Audit Logging | auditd not installed | **MEDIUM** |
| Munge Key | Correctly permissioned (0400, munge:munge) | **OK** |
| SlurmDBD Credential | Correctly permissioned (0600, slurm:slurm) | **OK** |
| Sudo Access | `%sudo` has full access; 2 users in group | **OK** |
| TCP Wrappers | `/etc/hosts.allow` and `/etc/hosts.deny` empty | **LOW** |
| AppArmor/SELinux | Not enforced | **LOW** |

---

## 2. Network Access Control

### 2.1 Management Network (192.168.1.0/24)

Currently **no firewall** on management interface (INPUT/OUTPUT policy ACCEPT). All internal services (LDAP, NFS, MySQL, Slurm, Munge) are exposed to the entire subnet.

**Recommended rules (iptables on acmt0):**

| Direction | Source | Dest | Port | Protocol | Purpose |
|-----------|--------|------|------|----------|---------|
| IN | 192.168.1.0/24 | acmt0 | 22 | TCP | SSH |
| IN | 192.168.1.0/24 | acmt0 | 389 | TCP | LDAP |
| IN | 192.168.1.0/24 | acmt0 | 636 | TCP | LDAPS (if enabled) |
| IN | 192.168.1.0/24 | acmt0 | 6817-6819 | TCP | Slurm ports |
| IN | 192.168.1.0/24 | acmt0 | 3306 | TCP | MySQL (slurmdbd only) |
| IN | 192.168.1.0/24 | acmt0 | 3000 | TCP | Grafana (optional) |
| IN | 192.168.1.0/24 | acmt0 | 9090 | TCP | Prometheus |
| IN | 192.168.1.0/24 | acmt0 | 9100 | TCP | node_exporter |
| IN | 192.168.1.0/24 | acmt0 | 161 | UDP | chrony NTP |
| IN | 192.168.1.0/24 | acmt-gpu | 22 | TCP | SSH |
| IN | 192.168.1.31 (acmt20) | 0.0.0.0/0 | - | - | NAT masquerade (Docker) |
| IN | 0.0.0.0/0 | acmt0 | 123 | UDP | NTP (external) |
| OUT | acmt0 | 0.0.0.0/0 | 80,443 | TCP | apt, docker pulls |
| ALL | else | | | | **DROP** |

### 2.2 InfiniBand Network (10.0.0.0/24)

- Trusted high-speed fabric — minimal filtering needed
- Should only carry MPI/RDMA traffic
- No IP forwarding between ib0 and eno1

### 2.3 GPU Node NAT (acmt20)

- acmt20 has nftables masquerade for Docker bridge
- Verify rules with: `nft list ruleset` on acmt20
- Docker containers should not expose ports to 192.168.1.0/24 without explicit approval

---

## 3. SSH Configuration

### 3.1 Current State

```bash
# /etc/ssh/sshd_config on acmt0  (relevant lines)
PermitRootLogin yes
PasswordAuthentication yes
```

### 3.2 Recommended Hardening

| Setting | Value | Rationale |
|---------|-------|-----------|
| PermitRootLogin | `prohibit-password` | Key-only root SSH |
| PasswordAuthentication | `no` | Key-only auth for all |
| PubkeyAuthentication | `yes` | |
| ChallengeResponseAuthentication | `no` | |
| MaxAuthTries | `3` | Rate-limit attempts |
| MaxSessions | `10` | |
| LoginGraceTime | `30s` | |
| AllowUsers | `root kc-lin kerwin` | Only listed users via SSH |
| ClientAliveInterval | `300` | Drop idle connections |
| ClientAliveCountMax | `2` | |

### 3.3 SSH Key Management

- **Root key**: `/root/.ssh/id_rsa` — used for Ansible deployment across all nodes
- **User keys**: Users must provide public key for LDAP account creation
- **Key rotation**: Rotate root deploy key annually
- **No shared keys**: Each administrator has individual key

### 3.4 Compute Node SSH

- Compute nodes should NOT have PasswordAuthentication enabled
- Only root's deploy key should be propagated
- User SSH access goes through acmt0 (no direct SSH to compute nodes from outside)

---

## 4. LDAP Security

### 4.1 Current Issues

1. **Plaintext bind password** in `/etc/ldap.conf`: `bindpw acmt2024`
   - File permissions: likely world-readable (depends on package defaults)
   - Fix: `chmod 600 /etc/ldap.conf` or move password to `/etc/ldap.secret`

2. **No TLS**: LDAP traffic is in cleartext on 192.168.1.0/24
   - Fix: Generate self-signed cert and enable `ssl start_tls` in `/etc/ldap.conf`

3. **Weak password hashing**: Uses `{SSHA}` (SHA1, no salt iterations)
   - LDAP doesn't re-hash on verify — fix requires migrating to `{SSHA512}` or `{ARGON2}`

### 4.2 Recommended LDAP Hardening

```bash
# In slapd config (cn=config)
olcTLSCertificateFile: /etc/ldap/slapd.crt
olcTLSCertificateKeyFile: /etc/ldap/slapd.key
olcTLSProtocolMin: 3.3  # TLS 1.2+

# In /etc/ldap.conf
ssl start_tls
tls_checkpeer no          # self-signed cert
```

### 4.3 LDAP ACLs (Recommended)

```
# Users can read their own entries, admin has full access
access to attrs=userPassword
    by self write
    by anonymous auth
    by dn.base="cn=admin,dc=acmt" write
    by * none

access to *
    by self read
    by dn.base="cn=admin,dc=acmt" write
    by users read
    by * none
```

---

## 5. Authentication & Password Policy

### 5.1 PAM Stack (Current)

```
auth  [success=2 default=ignore]  pam_unix.so nullok
auth  [success=1 default=ignore]  pam_ldap.so use_first_pass
auth  requisite                   pam_deny.so
auth  required                    pam_permit.so
```

- `nullok` allows empty passwords — **remove this**
- Order is: local unix → LDAP → deny

### 5.2 Recommended Password Policy

| Setting | Current | Recommended |
|---------|---------|-------------|
| PASS_MAX_DAYS | 99999 | 90 |
| PASS_MIN_DAYS | 0 | 1 |
| PASS_WARN_AGE | 7 | 14 |
| Password complexity | none | minlen=8, minclass=3 |
| Lockout after N failures | none | 5 failures, 15min lockout |

### 5.3 fail2ban

fail2ban is installed. Verify SSH jail is active:

```bash
fail2ban-client status sshd
```

If not configured:

```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
maxretry = 5
bantime = 3600
findtime = 600
```

---

## 6. NFS Security

### 6.1 Current Exports

```
/home   192.168.1.0/24(rw,no_root_squash,async)
/opt    192.168.1.0/24(rw,no_root_squash,async)
```

**Critical issue**: `no_root_squash` on both exports means root on any compromised compute node has full root access to all NFS files.

### 6.2 Recommended Changes

```
/home   192.168.1.0/24(rw,root_squash,async,subtree_check)
/opt    192.168.1.0/24(rw,root_squash,async,subtree_check)
```

**Exception**: If software installation requires root on NFS, create a dedicated export with narrower scope:

```
/opt/admin   192.168.1.10(rw,no_root_squash,async)
```

### 6.3 NFS Client Mounts

Current: `rw,soft,proto=tcp,timeo=600,retrans=2`

- `soft` can cause silent data corruption — consider `hard,intr` for `/home`
- Add `nosuid,nodev` to prevent suid binaries on NFS mounts

---

## 7. Slurm Security

### 7.1 Munge

- `/etc/munge/munge.key` — permission 0400, owned by munge — **OK**
- Key was created 2024-03-18 — rotate if compromised
- Munge uses symmetric key — **same key on all nodes**

### 7.2 SlurmDBD

- `/etc/slurm/slurmdbd.conf` — permission 0600, owned by slurm — **OK**
- MySQL password stored here — ensure MySQL only accepts connections from localhost
- **Verify**: `mysql -u root -e "SELECT user,host FROM mysql.user"`

### 7.3 Slurm User Separation

- Slurm users are managed via LDAP
- Single Slurm account `lab` with 14 users
- No QoS restrictions — consider adding `QoS=normal` with resource limits
- Root is Administrator — no other admin accounts

### 7.4 Job Security

- `SelectType=cons_tres` with `CR_Core_Memory` — prevents memory overcommit
- `EnforcePartLimits=ANY` — enforces partition limits
- Consider adding `JobCompType=jobcomp/filetxt` for audit logging
- Interactive jobs (`srun --pty`) should be logged

---

## 8. System Hardening Checklist

### 8.1 All Nodes

- [ ] Remove unused services (`cups`, `avahi-daemon`, `whoopsie`, etc.)
- [ ] `umask 027` in `/etc/profile` and `/etc/bash.bashrc`
- [ ] `net.ipv4.conf.all.rp_filter = 1` in `/etc/sysctl.conf`
- [ ] `net.ipv4.tcp_syncookies = 1`
- [ ] `kernel.dmesg_restrict = 1`
- [ ] Disable core dumps for SUID: `* hard core 0` in `/etc/security/limits.conf`
- [ ] Remove `setuid` from unnecessary binaries: `find / -perm -4000 -type f`

### 8.2 Headnode (acmt0)

- [ ] Firewall rules deployed (see §2.1)
- [ ] SSH hardened (see §3.2)
- [ ] LDAP TLS enabled (see §4.2)
- [ ] Password policy enforced (see §5.2)
- [ ] fail2ban active
- [ ] auditd installed and logging

### 8.3 Storage Node (acmt-storage)

- [ ] NFS `root_squash` applied
- [ ] NFS mount options include `nosuid,nodev`
- [ ] Export list restricted to only needed directories
- [ ] SMART monitoring for disk health

### 8.4 Compute Nodes

- [ ] No direct external SSH (only via acmt0)
- [ ] `noexec` on `/tmp` (if possible)
- [ ] Munge key permissions verified
- [ ] Slurmd running as `slurm` user (not root)

---

## 9. Monitoring & Auditing

### 9.1 Security Events to Monitor

| Event | Source | Action |
|-------|--------|--------|
| SSH auth failure >5/min | `/var/log/auth.log` | fail2ban → alert |
| Slurm job as root | `sacct` | Investigate |
| NFS mount changes | `/var/log/syslog` | Alert |
| LDAP bind failures | `/var/log/slapd.log` | Investigate |
| `sudo` usage | `/var/log/auth.log` | Periodic review |
| Failed `su` attempts | `/var/log/auth.log` | Alert |
| Munge auth failures | `/var/log/slurm/slurmctld.log` | Investigate |

### 9.2 Audit Log Retention

| Log | Retention | Location |
|-----|-----------|----------|
| Slurm accounting | Permanent | MySQL (slurm_acct_db) |
| Auth logs | 90 days | `/var/log/auth.log.*` |
| Slurm logs | 90 days | `/var/log/slurm/*` |
| Apache/Grafana | 30 days | `/var/log/apache2/*` |
| Prometheus data | 30 days | Prometheus TSDB |

---

## 10. Incident Response

### 10.1 Severity Levels

| Level | Definition | Response Time |
|-------|------------|---------------|
| **S1** | Cluster compromised / data breach | Immediate |
| **S2** | Active attack / unauthorized access detected | < 1 hour |
| **S3** | Suspicious activity / policy violation | < 24 hours |
| **S4** | Policy gap / configuration issue | < 1 week |

### 10.2 Response Playbook

**Compromised Node (S1)**:
1. Isolate node: `acmt node-drain <node>` + block at switch port
2. Collect forensic data: `ssh <node> "cat /var/log/auth.log"`, `ps aux`, `netstat -tlnp`
3. Wipe and reinstall via Ansible: `acmt ansible new-node -l <node>`
4. Rotate munge key: regenerate on all nodes
5. Review LDAP logs for unauthorized access

**SSH Brute Force (S2)**:
1. Check fail2ban status: `fail2ban-client status sshd`
2. Check auth log: `grep "Failed password" /var/log/auth.log`
3. Add source IPs to `/etc/hosts.deny` if not already banned
4. Investigate if any account was compromised

### 10.3 Reporting

- Security incidents must be reported to the system administrator
- Document in `/root/incident-log.md` with timestamp, description, action taken

---

## 11. User Management

### 11.1 Onboarding
1. Create LDAP user entry (cn=admin binds to slapd)
2. Set initial password (expire on first login if possible)
3. Add user to `lab` group for Slurm access
4. Create home directory on NFS: `cp -r /etc/skel /home/<username> && chown -R <uid>:<gid> /home/<username>`
5. Add to Slurm: `acmt user-add <username>`

### 11.2 Offboarding
1. Cancel all running jobs: `scancel -u <username>`
2. Remove from Slurm: `acmt user-remove <username>`
3. Disable LDAP account (set `pwdReset` or change password)
4. Archive home directory: `tar czf /root/archived-homes/<username>.tar.gz /home/<username>`
5. Remove home directory after 30-day grace period

### 11.3 Access Reviews

- Review user list quarterly: `sacctmgr show user`
- Verify no stale accounts (users who left without offboarding)
- Check sudo group membership: `getent group sudo`

---

## 12. Remediation Priority

| # | Action | Priority | Effort | Impact |
|---|--------|----------|--------|--------|
| 1 | Add firewall rules on acmt0 (DROP default INPUT) | **Critical** | 30min | High |
| 2 | Disable `PasswordAuthentication` in SSH | **Critical** | 5min | High |
| 3 | Change NFS to `root_squash` on all exports | **Critical** | 5min | High |
| 4 | Enable LDAP TLS | **High** | 30min | Medium |
| 5 | Enforce password expiry (PASS_MAX_DAYS=90) | **High** | 5min | Medium |
| 6 | Remove `nullok` from PAM auth config | **High** | 5min | Medium |
| 7 | Set `PermitRootLogin=prohibit-password` | **Medium** | 5min | Medium |
| 8 | Restrict `/etc/ldap.conf` permissions to 600 | **Medium** | 2min | Low |
| 9 | Configure fail2ban SSH jail | **Medium** | 10min | Low |
| 10 | Install and configure auditd | **Low** | 15min | Low |
| 11 | Add `nosuid,nodev` to NFS mount options | **Low** | 5min | Low |
| 12 | Rotate munge key (scheduled) | **Low** | 10min | Low |

---

## 13. Reference

- SSH config: `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/`
- LDAP config: `/etc/ldap.conf`, `/etc/ldap/slapd.d/`
- NFS exports: `/etc/exports` (on acmt-storage)
- PAM config: `/etc/pam.d/common-auth`
- Munge key: `/etc/munge/munge.key`
- SlurmDBD: `/etc/slurm/slurmdbd.conf`
- Firewall: iptables/nftables (no persistent rules currently)
- fail2ban: `/etc/fail2ban/`
- Ansible roles: `/root/acmt-ansible/ansible/roles/` (for automated hardening)
