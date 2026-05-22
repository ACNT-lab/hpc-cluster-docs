---
title: ACMT HPC Cluster — Security Policy | ACMT HPC 集群 — 安全政策
type: Protocol + Reference
last_updated: 2026-05-22
source_of_truth: This file (policy + risk register); `STATUS.md` §1.3 (open SEC TODO)
---

# ACMT HPC Cluster — Security Policy / ACMT HPC 集群 — 安全政策

## 1. Current Security Posture Assessment / 當前安全態勢評估

> This section is a **risk register**. The corresponding **open TODOs and priorities** are consolidated in [`STATUS.md`](STATUS.md) §1.3 (ISS-SEC-01 ~ ISS-SEC-07). After remediation, update the Status column here and remove the issue from STATUS.md.
>
> 本節為**風險登記**（risk register）。對應的**未處理 TODO 與優先序**集中在 [`STATUS.md`](STATUS.md) §1.3（ISS-SEC-01 ~ ISS-SEC-07）。完成修補後請更新本表 Status 欄位並從 STATUS.md 移除該 issue。

### 1.1 Risk Summary / 風險摘要

| Area / 領域 | Status / 現狀 | Severity / 嚴重度 |
|------|--------|----------|
| Firewall (mgmt) / 管理網路防火牆 | iptables INPUT/OUTPUT policy ACCEPT — no restrictions / 無限制 | **HIGH** |
| SSH Root Login / SSH root 登入 | PermitRootLogin=yes | **HIGH** |
| SSH Password Auth / SSH 密碼認證 | PasswordAuthentication=yes (on acmt0) | **HIGH** |
| LDAP Password Storage / LDAP 密碼儲存 | {SSHA} — SHA1 (weak, no salt iteration) / SHA1（弱、無 salt 迭代） | **MEDIUM** |
| LDAP Bind Credential / LDAP bind 憑證 | Plaintext password in `/etc/ldap.conf` / `/etc/ldap.conf` 內為明文 | **MEDIUM** |
| LDAP Transport / LDAP 傳輸 | No TLS/SSL — plaintext on wire / 無 TLS/SSL，明文傳輸 | **HIGH** |
| NFS | `no_root_squash` on `/home` and `/opt` | **HIGH** |
| Password Policy / 密碼政策 | PASS_MAX_DAYS=99999 (no expiry) / 永不過期 | **MEDIUM** |
| Failed Login Protection / 失敗登入防護 | fail2ban installed but not confirmed enforcing SSH / 已安裝但未確認強制執行 SSH | **LOW** |
| Audit Logging / 稽核日誌 | auditd not installed / 未安裝 | **MEDIUM** |
| Munge Key | Correctly permissioned (0400, munge:munge) / 權限正確 | **OK** |
| SlurmDBD Credential / SlurmDBD 憑證 | Correctly permissioned (0600, slurm:slurm) / 權限正確 | **OK** |
| Sudo Access / Sudo 存取 | `%sudo` has full access; 2 users in group / 完整存取，群組內 2 位使用者 | **OK** |
| TCP Wrappers | `/etc/hosts.allow` and `/etc/hosts.deny` empty / 皆為空 | **LOW** |
| AppArmor/SELinux | Not enforced / 未強制執行 | **LOW** |

---

## 2. Network Access Control / 網路存取控制

### 2.1 Management Network (192.168.1.0/24) / 管理網路

Currently **no firewall** on management interface (INPUT/OUTPUT policy ACCEPT). All internal services (LDAP, NFS, MySQL, Slurm, Munge) are exposed to the entire subnet.

目前管理介面**無防火牆**（INPUT/OUTPUT policy ACCEPT）。所有內部服務（LDAP、NFS、MySQL、Slurm、Munge）皆暴露於整個子網路。

**Recommended rules (iptables on acmt0): / 建議規則（acmt0 上的 iptables）：**

| Direction / 方向 | Source / 來源 | Dest / 目的 | Port / 連接埠 | Protocol / 通訊協定 | Purpose / 用途 |
|-----------|--------|------|------|----------|---------|
| IN | 192.168.1.0/24 | acmt0 | 22 | TCP | SSH |
| IN | 192.168.1.0/24 | acmt0 | 389 | TCP | LDAP |
| IN | 192.168.1.0/24 | acmt0 | 636 | TCP | LDAPS (if enabled) / LDAPS（若啟用） |
| IN | 192.168.1.0/24 | acmt0 | 6817-6819 | TCP | Slurm ports / Slurm 連接埠 |
| IN | 192.168.1.0/24 | acmt0 | 3306 | TCP | MySQL (slurmdbd only) / MySQL（僅 slurmdbd） |
| IN | 192.168.1.0/24 | acmt0 | 3000 | TCP | Grafana (optional) / Grafana（選用） |
| IN | 192.168.1.0/24 | acmt0 | 9090 | TCP | Prometheus |
| IN | 192.168.1.0/24 | acmt0 | 9100 | TCP | node_exporter |
| IN | 192.168.1.0/24 | acmt0 | 161 | UDP | chrony NTP |
| IN | 192.168.1.0/24 | acmt-gpu | 22 | TCP | SSH |
| IN | 192.168.1.31 (acmt20) | 0.0.0.0/0 | - | - | NAT masquerade (Docker) / NAT masquerade（Docker） |
| IN | 0.0.0.0/0 | acmt0 | 123 | UDP | NTP (external) / NTP（外部） |
| OUT | acmt0 | 0.0.0.0/0 | 80,443 | TCP | apt, docker pulls |
| ALL | else / 其他 | | | | **DROP** |

### 2.2 InfiniBand Network (10.0.0.0/24) / InfiniBand 網路

- Trusted high-speed fabric — minimal filtering needed / 受信任的高速網路 — 需最小化過濾
- Should only carry MPI/RDMA traffic / 僅應承載 MPI/RDMA 流量
- No IP forwarding between ib0 and eno1 / ib0 與 eno1 之間禁止 IP forwarding

### 2.3 GPU Node NAT (acmt20) / GPU 節點 NAT

- acmt20 has nftables masquerade for Docker bridge / acmt20 為 Docker bridge 設有 nftables masquerade
- Verify rules with `nft list ruleset` on acmt20 / 在 acmt20 以 `nft list ruleset` 驗證規則
- Docker containers should not expose ports to 192.168.1.0/24 without explicit approval / Docker container 未經明確許可不應對 192.168.1.0/24 開放埠口

---

## 3. SSH Configuration / SSH 設定

### 3.1 Current State / 當前狀態

```bash
# /etc/ssh/sshd_config on acmt0  (relevant lines)
PermitRootLogin yes
PasswordAuthentication yes
```

### 3.2 Recommended Hardening / 建議強化設定

| Setting / 設定項 | Value / 值 | Rationale / 理由 |
|---------|-------|-----------|
| PermitRootLogin | `prohibit-password` | Key-only root SSH / root 僅允許金鑰登入 |
| PasswordAuthentication | `no` | Key-only auth for all / 全部僅允許金鑰認證 |
| PubkeyAuthentication | `yes` | |
| ChallengeResponseAuthentication | `no` | |
| MaxAuthTries | `3` | Rate-limit attempts / 限制嘗試次數 |
| MaxSessions | `10` | |
| LoginGraceTime | `30s` | |
| AllowUsers | `root kc-lin kerwin` | Only listed users via SSH / 僅清單內使用者可 SSH |
| ClientAliveInterval | `300` | Drop idle connections / 中斷閒置連線 |
| ClientAliveCountMax | `2` | |

### 3.3 SSH Key Management / SSH 金鑰管理

- **Root key / Root 金鑰**: `/root/.ssh/id_rsa` — used for Ansible deployment across all nodes / 用於跨節點 Ansible 部署
- **User keys / 使用者金鑰**: Users must provide public key for LDAP account creation / 使用者建立 LDAP 帳號時須提供公鑰
- **Key rotation / 金鑰輪替**: Rotate root deploy key annually / 每年輪替 root 部署金鑰
- **No shared keys / 不共用金鑰**: Each administrator has individual key / 每位管理員擁有個別金鑰

### 3.4 Compute Node SSH / 計算節點 SSH

- Compute nodes should NOT have PasswordAuthentication enabled / 計算節點不應啟用 PasswordAuthentication
- Only root's deploy key should be propagated / 僅應分發 root 部署金鑰
- User SSH access goes through acmt0 (no direct SSH to compute nodes from outside) / 使用者 SSH 須經由 acmt0（外部不可直接 SSH 至計算節點）

---

## 4. LDAP Security / LDAP 安全

### 4.1 Current Issues / 當前問題

1. **Plaintext bind password / 明文 bind 密碼** in `/etc/ldap.conf` (value `<REDACTED — see /etc/ldap.secret on acmt0>`)
   - File permissions: likely world-readable (depends on package defaults) / 檔案權限可能為全域可讀（取決於套件預設）
   - Fix / 修補: `chmod 600 /etc/ldap.conf` or move password to `/etc/ldap.secret` / 或將密碼搬到 `/etc/ldap.secret`
   - **Action required / 需執行的動作:** rotate the bind password on the LDAP server, update `/etc/ldap.conf` on acmt0 and every compute node (via Ansible `users` role), and verify git history was scrubbed (see CHANGELOG.md entry for 2026-05-22). / 在 LDAP 伺服器上輪替 bind 密碼，透過 Ansible `users` role 更新 acmt0 與所有計算節點上的 `/etc/ldap.conf`，並確認 git 歷史已清除（見 CHANGELOG.md 2026-05-22 條目）。

2. **No TLS / 無 TLS**: LDAP traffic is in cleartext on 192.168.1.0/24 / LDAP 流量在 192.168.1.0/24 上為明文
   - Fix / 修補: Generate self-signed cert and enable `ssl start_tls` in `/etc/ldap.conf` / 產生自簽憑證並在 `/etc/ldap.conf` 啟用 `ssl start_tls`

3. **Weak password hashing / 弱密碼雜湊**: Uses `{SSHA}` (SHA1, no salt iterations) / 使用 `{SSHA}`（SHA1，無 salt 迭代）
   - LDAP doesn't re-hash on verify — fix requires migrating to `{SSHA512}` or `{ARGON2}` / LDAP 驗證時不會重新雜湊 — 修補需遷移至 `{SSHA512}` 或 `{ARGON2}`

### 4.2 Recommended LDAP Hardening / 建議的 LDAP 強化設定

```bash
# In slapd config (cn=config)
olcTLSCertificateFile: /etc/ldap/slapd.crt
olcTLSCertificateKeyFile: /etc/ldap/slapd.key
olcTLSProtocolMin: 3.3  # TLS 1.2+

# In /etc/ldap.conf
ssl start_tls
tls_checkpeer no          # self-signed cert
```

### 4.3 LDAP ACLs (Recommended) / LDAP ACL（建議）

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

## 5. Authentication & Password Policy / 認證與密碼政策

### 5.1 PAM Stack (Current) / PAM Stack（當前）

```
auth  [success=2 default=ignore]  pam_unix.so nullok
auth  [success=1 default=ignore]  pam_ldap.so use_first_pass
auth  requisite                   pam_deny.so
auth  required                    pam_permit.so
```

- `nullok` allows empty passwords — **remove this** / `nullok` 允許空密碼 — **必須移除**
- Order is: local unix → LDAP → deny / 順序為：local unix → LDAP → deny

### 5.2 Recommended Password Policy / 建議的密碼政策

| Setting / 設定項 | Current / 當前 | Recommended / 建議 |
|---------|---------|-------------|
| PASS_MAX_DAYS | 99999 | 90 |
| PASS_MIN_DAYS | 0 | 1 |
| PASS_WARN_AGE | 7 | 14 |
| Password complexity / 密碼複雜度 | none / 無 | minlen=8, minclass=3 |
| Lockout after N failures / N 次失敗後鎖定 | none / 無 | 5 failures, 15min lockout / 5 次失敗，鎖定 15 分鐘 |

### 5.3 fail2ban

fail2ban is installed. Verify SSH jail is active:

fail2ban 已安裝。確認 SSH jail 為作用中：

```bash
fail2ban-client status sshd
```

If not configured: / 若尚未設定：

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

## 6. NFS Security / NFS 安全

### 6.1 Current Exports / 當前 export

```
/home   192.168.1.0/24(rw,no_root_squash,async)
/opt    192.168.1.0/24(rw,no_root_squash,async)
```

**Critical issue**: `no_root_squash` on both exports means root on any compromised compute node has full root access to all NFS files.

**關鍵問題**：兩個 export 皆設定 `no_root_squash`，代表任何被攻陷的計算節點上的 root 即擁有所有 NFS 檔案的完整 root 存取權。

### 6.2 Recommended Changes / 建議變更

```
/home   192.168.1.0/24(rw,root_squash,async,subtree_check)
/opt    192.168.1.0/24(rw,root_squash,async,subtree_check)
```

**Exception**: If software installation requires root on NFS, create a dedicated export with narrower scope:

**例外**：若軟體安裝需在 NFS 上以 root 執行，建立範圍更窄的專屬 export：

```
/opt/admin   192.168.1.10(rw,no_root_squash,async)
```

### 6.3 NFS Client Mounts / NFS 客戶端掛載

Current / 當前: `rw,soft,proto=tcp,timeo=600,retrans=2`

- `soft` can cause silent data corruption — consider `hard,intr` for `/home` / `soft` 可能造成靜默資料損毀 — `/home` 建議改用 `hard,intr`
- Add `nosuid,nodev` to prevent suid binaries on NFS mounts / 加入 `nosuid,nodev` 以防止 NFS 掛載上的 suid 程式

---

## 7. Slurm Security / Slurm 安全

### 7.1 Munge

- `/etc/munge/munge.key` — permission 0400, owned by munge — **OK** / 權限 0400，擁有者 munge — **OK**
- Key was created 2024-03-18 — rotate if compromised / 金鑰建立於 2024-03-18 — 若有外洩請輪替
- Munge uses symmetric key — **same key on all nodes** / Munge 使用對稱金鑰 — **所有節點共用相同金鑰**

### 7.2 SlurmDBD

- `/etc/slurm/slurmdbd.conf` — permission 0600, owned by slurm — **OK** / 權限 0600，擁有者 slurm — **OK**
- MySQL password stored here — ensure MySQL only accepts connections from localhost / MySQL 密碼存放於此 — 確保 MySQL 僅接受 localhost 連線
- **Verify / 驗證**: `mysql -u root -e "SELECT user,host FROM mysql.user"`

### 7.3 Slurm User Separation / Slurm 使用者區隔

- Slurm users are managed via LDAP / Slurm 使用者透過 LDAP 管理
- Single Slurm account `lab` with ~14 users (verify via `sacctmgr show users`) / 單一 Slurm account `lab`，約 14 位使用者（以 `sacctmgr show users` 驗證）
- No QoS restrictions — consider adding `QoS=normal` with resource limits / 無 QoS 限制 — 建議加入帶有資源限制的 `QoS=normal`
- Root is Administrator — no other admin accounts / Root 為 Administrator — 無其他管理員帳號

### 7.4 Job Security / 作業安全

- `SelectType=cons_tres` with `CR_Core_Memory` — prevents memory overcommit / 防止記憶體 overcommit
- `EnforcePartLimits=ANY` — enforces partition limits / 強制執行 partition 限制
- Consider adding `JobCompType=jobcomp/filetxt` for audit logging / 建議加入 `JobCompType=jobcomp/filetxt` 以利稽核日誌
- Interactive jobs (`srun --pty`) should be logged / 互動式作業（`srun --pty`）應紀錄日誌

---

## 8. System Hardening Checklist / 系統強化檢查清單

### 8.1 All Nodes / 所有節點

- [ ] Remove unused services (`cups`, `avahi-daemon`, `whoopsie`, etc.) / 移除未使用之服務
- [ ] `umask 027` in `/etc/profile` and `/etc/bash.bashrc`
- [ ] `net.ipv4.conf.all.rp_filter = 1` in `/etc/sysctl.conf`
- [ ] `net.ipv4.tcp_syncookies = 1`
- [ ] `kernel.dmesg_restrict = 1`
- [ ] Disable core dumps for SUID: `* hard core 0` in `/etc/security/limits.conf` / 為 SUID 停用 core dump
- [ ] Remove `setuid` from unnecessary binaries: `find / -perm -4000 -type f` / 移除不必要 binary 的 `setuid`

### 8.2 Headnode (acmt0) / 管理節點

- [ ] Firewall rules deployed (see §2.1) / 部署防火牆規則
- [ ] SSH hardened (see §3.2) / SSH 強化
- [ ] LDAP TLS enabled (see §4.2) / 啟用 LDAP TLS
- [ ] Password policy enforced (see §5.2) / 強制密碼政策
- [ ] fail2ban active / fail2ban 已啟用
- [ ] auditd installed and logging / auditd 已安裝並啟用日誌

### 8.3 Storage Node (acmt-storage) / 儲存節點

- [ ] NFS `root_squash` applied / 已套用 NFS `root_squash`
- [ ] NFS mount options include `nosuid,nodev` / NFS 掛載選項包含 `nosuid,nodev`
- [ ] Export list restricted to only needed directories / Export 清單僅限必要目錄
- [ ] SMART monitoring for disk health / 磁碟健康監控（SMART）

### 8.4 Compute Nodes / 計算節點

- [ ] No direct external SSH (only via acmt0) / 不允許外部直接 SSH（僅可經由 acmt0）
- [ ] `noexec` on `/tmp` (if possible) / `/tmp` 設為 `noexec`（若可行）
- [ ] Munge key permissions verified / Munge 金鑰權限已驗證
- [ ] Slurmd running as `slurm` user (not root) / Slurmd 以 `slurm` 使用者執行（非 root）

---

## 9. Monitoring & Auditing / 監控與稽核

### 9.1 Security Events to Monitor / 應監控之安全事件

| Event / 事件 | Source / 來源 | Action / 動作 |
|-------|--------|--------|
| SSH auth failure >5/min / SSH 認證失敗每分鐘 >5 次 | `/var/log/auth.log` | fail2ban → alert / 觸發告警 |
| Slurm job as root / Slurm 作業以 root 執行 | `sacct` | Investigate / 調查 |
| NFS mount changes / NFS 掛載變更 | `/var/log/syslog` | Alert / 告警 |
| LDAP bind failures / LDAP bind 失敗 | `/var/log/slapd.log` | Investigate / 調查 |
| `sudo` usage / `sudo` 使用 | `/var/log/auth.log` | Periodic review / 定期審視 |
| Failed `su` attempts / `su` 失敗嘗試 | `/var/log/auth.log` | Alert / 告警 |
| Munge auth failures / Munge 認證失敗 | `/var/log/slurm/slurmctld.log` | Investigate / 調查 |

### 9.2 Audit Log Retention / 稽核日誌保留

| Log / 日誌 | Retention / 保留 | Location / 位置 |
|-----|-----------|----------|
| Slurm accounting / Slurm 計帳 | Permanent / 永久 | MySQL (slurm_acct_db) |
| Auth logs / 認證日誌 | 90 days / 90 天 | `/var/log/auth.log.*` |
| Slurm logs / Slurm 日誌 | 90 days / 90 天 | `/var/log/slurm/*` |
| Apache/Grafana | 30 days / 30 天 | `/var/log/apache2/*` |
| Prometheus data / Prometheus 資料 | 30 days / 30 天 | Prometheus TSDB |

---

## 10. Incident Response / 事件回應

### 10.1 Severity Levels / 嚴重度等級

| Level / 等級 | Definition / 定義 | Response Time / 回應時間 |
|-------|------------|---------------|
| **S1** | Cluster compromised / data breach / 集群遭入侵 / 資料外洩 | Immediate / 立即 |
| **S2** | Active attack / unauthorized access detected / 偵測到主動攻擊 / 未授權存取 | < 1 hour / < 1 小時 |
| **S3** | Suspicious activity / policy violation / 可疑活動 / 違反政策 | < 24 hours / < 24 小時 |
| **S4** | Policy gap / configuration issue / 政策落差 / 設定議題 | < 1 week / < 1 週 |

### 10.2 Response Playbook / 回應 Playbook

**Compromised Node (S1) / 受害節點 (S1)**:
1. Isolate node: `acmt node-drain <node>` + block at switch port / 隔離節點：`acmt node-drain <node>` 並於 switch port 阻擋
2. Collect forensic data: `ssh <node> "cat /var/log/auth.log"`, `ps aux`, `netstat -tlnp` / 收集鑑識資料
3. Wipe and reinstall via Ansible: `acmt ansible new-node -l <node>` / 透過 Ansible 重灌
4. Rotate munge key: regenerate on all nodes / 輪替 munge key，於所有節點重新產生
5. Review LDAP logs for unauthorized access / 檢視 LDAP 日誌是否有未授權存取

**SSH Brute Force (S2) / SSH 暴力破解 (S2)**:
1. Check fail2ban status: `fail2ban-client status sshd` / 檢查 fail2ban 狀態
2. Check auth log: `grep "Failed password" /var/log/auth.log` / 檢查認證日誌
3. Add source IPs to `/etc/hosts.deny` if not already banned / 若尚未封鎖，將來源 IP 加入 `/etc/hosts.deny`
4. Investigate if any account was compromised / 調查是否有帳號遭入侵

### 10.3 Reporting / 通報

- Security incidents must be reported to the system administrator / 安全事件須通報系統管理員
- Document in `/root/incident-log.md` with timestamp, description, action taken / 於 `/root/incident-log.md` 紀錄時間戳、描述與處置

---

## 11. User Management / 使用者管理

### 11.1 Onboarding / 入職流程
1. Create LDAP user entry (cn=admin binds to slapd) / 建立 LDAP 使用者條目（cn=admin 連 slapd）
2. Set initial password (expire on first login if possible) / 設定初始密碼（可行的話設首次登入即過期）
3. Add user to `lab` group for Slurm access / 將使用者加入 `lab` 群組以取得 Slurm 存取權
4. Create home directory on NFS: `cp -r /etc/skel /home/<username> && chown -R <uid>:<gid> /home/<username>` / 於 NFS 建立家目錄
5. Add to Slurm: `acmt user-add <username>` / 加入 Slurm

### 11.2 Offboarding / 離職流程
1. Cancel all running jobs: `scancel -u <username>` / 取消所有執行中作業
2. Remove from Slurm: `acmt user-remove <username>` / 從 Slurm 移除
3. Disable LDAP account (set `pwdReset` or change password) / 停用 LDAP 帳號（設定 `pwdReset` 或變更密碼）
4. Archive home directory: `tar czf /root/archived-homes/<username>.tar.gz /home/<username>` / 封存家目錄
5. Remove home directory after 30-day grace period / 30 天緩衝期後移除家目錄

### 11.3 Access Reviews / 存取審視

- Review user list quarterly: `sacctmgr show user` / 每季審視使用者清單
- Verify no stale accounts (users who left without offboarding) / 確認無過期帳號（離職但未走流程者）
- Check sudo group membership: `getent group sudo` / 檢查 sudo 群組成員

---

## 12. Remediation Priority / 修補優先序

| # | Action / 動作 | Priority / 優先序 | Effort / 工作量 | Impact / 影響 |
|---|--------|----------|--------|--------|
| 1 | Add firewall rules on acmt0 (DROP default INPUT) / 在 acmt0 加入防火牆規則（預設 DROP INPUT） | **Critical** | 30min | High |
| 2 | Disable `PasswordAuthentication` in SSH / 在 SSH 停用 `PasswordAuthentication` | **Critical** | 5min | High |
| 3 | Change NFS to `root_squash` on all exports / 所有 NFS export 改為 `root_squash` | **Critical** | 5min | High |
| 4 | Enable LDAP TLS / 啟用 LDAP TLS | **High** | 30min | Medium |
| 5 | Enforce password expiry (PASS_MAX_DAYS=90) / 強制密碼過期 | **High** | 5min | Medium |
| 6 | Remove `nullok` from PAM auth config / 從 PAM auth 設定移除 `nullok` | **High** | 5min | Medium |
| 7 | Set `PermitRootLogin=prohibit-password` | **Medium** | 5min | Medium |
| 8 | Restrict `/etc/ldap.conf` permissions to 600 / `/etc/ldap.conf` 權限限制為 600 | **Medium** | 2min | Low |
| 9 | Configure fail2ban SSH jail / 設定 fail2ban SSH jail | **Medium** | 10min | Low |
| 10 | Install and configure auditd / 安裝並設定 auditd | **Low** | 15min | Low |
| 11 | Add `nosuid,nodev` to NFS mount options / 於 NFS 掛載選項加入 `nosuid,nodev` | **Low** | 5min | Low |
| 12 | Rotate munge key (scheduled) / 輪替 munge key（排程） | **Low** | 10min | Low |

---

## 13. Reference / 參考

- SSH config / SSH 設定: `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/`
- LDAP config / LDAP 設定: `/etc/ldap.conf`, `/etc/ldap/slapd.d/`
- NFS exports / NFS export: `/etc/exports` (on acmt-storage)
- PAM config / PAM 設定: `/etc/pam.d/common-auth`
- Munge key: `/etc/munge/munge.key`
- SlurmDBD: `/etc/slurm/slurmdbd.conf`
- Firewall / 防火牆: iptables/nftables (no persistent rules currently) / 目前無持久化規則
- fail2ban: `/etc/fail2ban/`
- Ansible roles: `/root/acmt-ansible/ansible/roles/` (for automated hardening) / 用於自動化強化
