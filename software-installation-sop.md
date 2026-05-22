---
title: ACMT HPC Cluster — Software Installation SOP | ACMT HPC 集群 — 軟體安裝 SOP
type: Operations (SOP)
last_updated: 2026-05-22
source_of_truth: This file (procedure); `/opt/modulefiles/` (installed modules)
---

# ACMT HPC Cluster — Software Installation SOP / ACMT HPC 集群 — 軟體安裝 SOP

## 1. Overview / 總覽

### 1.1 Software Stack Architecture / 軟體堆疊架構

The cluster keeps installed software, Tcl modulefiles, source tarballs, and build logs under fixed paths on shared NFS, so a single install on `acmt0` is visible cluster-wide.

集群將安裝後的軟體、Tcl modulefile、原始碼壓縮檔與 build 日誌固定存放於共享 NFS 路徑，在 `acmt0` 安裝一次即可在全集群可見。

```
Software install path:  /opt/<name>/<version>/     (on NFS, shared cluster-wide)
Modulefile path:        /opt/modulefiles/<name>/<version>
Source tarballs:        /opt/src/<name>-<version>.tar.gz
Build logs:             /var/log/software-install/<name>-<version>.log
```

- `/opt` is **NFS from acmt-storage** — visible on all nodes / `/opt` 由 **acmt-storage** 透過 NFS 共享，全節點可見
- Install once on **acmt0** (headnode), available everywhere / 在 **acmt0** (headnode) 安裝一次，全集群可用
- All software uses **Environment Modules** (Tcl-based `module` command) / 所有軟體透過 **Environment Modules** (Tcl 的 `module` 命令) 管理
- Builds use the latest GCC or Intel compiler as appropriate / 建置時依需求使用最新 GCC 或 Intel 編譯器

### 1.2 Quickstart (TL;DR) / 快速開始 (TL;DR)

End-to-end happy-path: build → install → write modulefile → smoke-test.

由建置到驗證的最短路徑：build → install → 寫 modulefile → 測試。

```bash
# 1. Build & install
cd /opt/src
tar xf <software>-<ver>.tar.gz
cd <software>-<ver>
./configure --prefix=/opt/<name>/<ver>
make -j$(nproc) && make install

# 2. Create modulefile
cat > /opt/modulefiles/<name>/<ver> << 'MODULEFILE'
#%Module1.0
proc ModulesHelp { } {
    puts stderr "\tLoads <name> <ver>"
}
module-whatis "<name> <ver>"
set root /opt/<name>/<ver>
prepend-path PATH $root/bin
prepend-path LD_LIBRARY_PATH $root/lib
MODULEFILE

# 3. Test
module avail <name>
module load <name>/<ver>
which <binary>
```

---

## 2. Directory Conventions / 目錄規範

### 2.1 Standard Layout / 標準佈局

The shared `/opt` tree splits installed roots, modulefiles, source tarballs, and complex applications by purpose.

共享的 `/opt` 樹依用途切分：安裝根目錄、modulefile、原始碼壓縮檔、複雜應用。

```
/opt/
├── <name>/                      # Software root
│   └── <version>/               # Version-specific install
│       ├── bin/                 #  binaries
│       ├── lib/ lib64/          #  libraries
│       ├── include/             #  headers
│       ├── share/man/           #  man pages
│       └── share/doc/           #  docs
├── modulefiles/                 # Tcl modulefiles
│   └── <name>/                  #  one directory per software
│       └── <version>            #  one file per version
├── src/                         # Source tarballs & build dirs
├── applications/                # Complex apps (Ansys, Conda...)
├── cuda/modulefiles/            # CUDA modulefiles
└── intel/modulefiles/           # Intel oneAPI modulefiles
```

### 2.2 Naming Rules / 命名規則

| Field / 欄位 | Convention / 規範 | Example / 範例 |
|-------|-----------|---------|
| `<name>` | lowercase, hyphen-separated / 小寫，連字號分隔 | `openmpi`, `fftw`, `gromacs` |
| `<version>` | SemVer (`X.Y` or `X.Y.Z`) | `4.2.1`, `2024.1` |
| Module alias / Module 別名 | `latest` symlink to default version / `latest` symlink 指向預設版本 | `gcc/latest → gcc/15.2` |

### 2.3 Existing Software Locations / 既有軟體位置

| Software / 軟體 | Installed Path / 安裝路徑 | Modulefile |
|----------|---------------|------------|
| GCC 10.4 | `/opt/gcc/10.4` | `/opt/modulefiles/gcc/10.4` |
| GCC 15.2 | `/opt/gcc/15.2` | `/opt/modulefiles/gcc/15.2` |
| OpenMPI 4.1.2 | system `/usr` | `/opt/modulefiles/openmpi-system/4.1.2` |
| OpenMPI 5.0.5 | `/opt/openmpi-5.0.5` | `/opt/openmpi/modulefiles/openmpi/5.0.5` |
| Python 3.10 | system `/usr` | `/opt/modulefiles/python/3.10` |
| CUDA 10.2/11.0/11.4/12.0/12.6 | `/opt/cuda/...` | `/opt/cuda/modulefiles/cuda/<ver>` |
| Intel oneAPI 2024.0 | `/opt/intel/oneapi/` | `/opt/intel/modulefiles/` |
| NVHPC 21.7/21.9/22.3/24.7 | `/opt/nvhpc/...` | `/opt/nvhpc/modulefiles/` |
| ANSYS Fluent v19T/v221 | `/opt/ansys/...` | `/opt/applications/ansys/Fluent/<ver>` |
| OpenFOAM 10 | `/opt/openfoam/...` | via `module load openfoam` |
| UCX 1.17.0 | `/opt/ucx/...` | via `module load ucx` |

---

## 3. Installation Workflow / 安裝流程

### 3.1 Standard Build & Install / 標準 build 與安裝

Canonical autotools workflow with explicit dependency loading via `module`.

採用 `module` 顯式載入相依的標準 autotools 流程。

```bash
# Step 1: Prepare environment
ssh acmt0
sudo -i
cd /opt/src

# Step 2: Load dependencies
module load gcc/15.2 openmpi/5.0.5

# Step 3: Download & extract
wget https://example.com/software-4.2.1.tar.gz
tar xf software-4.2.1.tar.gz
cd software-4.2.1

# Step 4: Configure (typical autotools)
./configure --prefix=/opt/software/4.2.1 \
            --with-mpi=/opt/openmpi-5.0.5 \
            CC=gcc CXX=g++ FC=gfortran

# Step 5: Build (use all cores)
make -j$(nproc) 2>&1 | tee /var/log/software-install/software-4.2.1.log

# Step 6: Install
make install

# Step 7: Strip debug symbols (optional)
find /opt/software/4.2.1/bin -type f -exec strip {} \;
```

### 3.2 CMake-based Builds / CMake 建置

Equivalent flow for CMake-based projects.

CMake 專案的對應流程。

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/software/4.2.1 \
         -DCMAKE_C_COMPILER=gcc \
         -DCMAKE_CXX_COMPILER=g++ \
         -DCMAKE_Fortran_COMPILER=gfortran
make -j$(nproc)
make install
```

### 3.3 Python Packages (Conda) / Python 套件 (Conda)

Use the system Conda at `/opt/conda` and expose the env as a module if it should be shared.

使用 `/opt/conda` 的系統級 Conda；若要共享，將該 env 包成 module。

```bash
# System Conda is at /opt/conda
conda create -n myenv python=3.10
conda activate myenv
pip install numpy scipy matplotlib

# To make available as module:
cat > /opt/modulefiles/myenv/1.0 << 'EOF'
#%Module1.0
module-whatis "My custom Conda environment"
set root /opt/conda/envs/myenv
prepend-path PATH $root/bin
prepend-path LD_LIBRARY_PATH $root/lib
EOF
```

### 3.4 Modulefile Template / Modulefile 範本

Standard modulefile structure with help text, whatis line, dependency loading, and path setup.

標準 modulefile 結構：help 文字、whatis、相依載入、路徑設定。

```tcl
#%Module1.0
##
#  <name> <version>
#  Description: one-line summary
#  Install date: YYYY-MM-DD
#  Built by: <user>
#  Dependencies: gcc/15.2, openmpi/5.0.5
##

proc ModulesHelp { } {
    puts stderr "\tLoads <name> <version>"
    puts stderr "\tInstalled in /opt/<name>/<version>"
    puts stderr "\n\tDependencies:"
    puts stderr "\t  - gcc/15.2"
    puts stderr "\t  - openmpi/5.0.5"
}

module-whatis "<name> <version>"

# Dependency chain
module load gcc/15.2

set root /opt/<name>/<version>

prepend-path PATH              $root/bin
prepend-path LD_LIBRARY_PATH   $root/lib
prepend-path LD_LIBRARY_PATH   $root/lib64
prepend-path MANPATH           $root/share/man
prepend-path INFOPATH          $root/share/info
prepend-path PKG_CONFIG_PATH   $root/lib/pkgconfig
prepend-path CPATH             $root/include

# Convenience variables
setenv           <NAME>_HOME   $root
setenv           <NAME>_DIR    $root
```

---

## 4. Post-Install Validation / 安裝後驗證

### 4.1 Required Checks / 必要檢查

Confirm the binary runs, libraries resolve, MPI launcher works, the compiler still compiles, and the module unloads cleanly.

確認 binary 可執行、library 可解析、MPI launcher 正常、編譯器仍可編譯、module 可乾淨卸載。

```bash
# 1. Binary works
module load <name>/<version>
which <binary>
<binary> --version

# 2. Libraries loadable
ldd $(which <binary>) | grep "not found"

# 3. MPI-only: launcher works
mpirun --version
mpirun -np 2 <binary>  # test parallel launch

# 4. Compile a test program
echo 'int main(){ return 0; }' | gcc -x c - -o /tmp/test && /tmp/test

# 5. Module unload clean
module unload <name>/<version>
module list 2>&1 | grep <name> && echo "FAIL: still loaded" || echo "OK"
```

### 4.2 Slurm Smoke Test / Slurm 煙霧測試

Submit a minimal Slurm job that loads the module and runs the binary.

提交一個最小的 Slurm 作業，載入 module 並執行 binary。

```bash
# Submit a quick test job
cat > /tmp/test-<name>.sh << 'SCRIPT'
#!/bin/bash
#SBATCH --job-name=test-<name>
#SBATCH --output=/tmp/test-<name>.out
#SBATCH --error=/tmp/test-<name>.err
#SBATCH --ntasks=2
#SBATCH --time=00:05:00
#SBATCH --partition=r630s

# IMPORTANT: Slurm batch shell does NOT source /etc/profile.d/
# Must manually initialize the module command:
source /usr/share/modules/init/bash

module load <name>/<version>
<binary> --version
echo "Test completed"
SCRIPT

sbatch /tmp/test-<name>.sh
squeue -u root
```

### 4.3 Critical: `module` Command in Slurm Jobs / 重要：Slurm 作業中的 `module` 命令

> **Warning / 警告**
>
> Environment Modules is initialized for login shells by `/etc/profile.d/modules.sh` (a thin wrapper around `/usr/share/modules/init/bash`). Slurm batch shells are **non-interactive non-login** by default and do NOT source `/etc/profile.d/`, so `module` is unavailable inside job scripts unless you source the underlying init file directly.
>
> Environment Modules 在 login shell 中由 `/etc/profile.d/modules.sh` 初始化（它只是 `/usr/share/modules/init/bash` 的薄包裝）。Slurm batch shell 預設是 **non-interactive non-login**，不會 source `/etc/profile.d/`；除非你自行 source 底層 init 檔，否則 job script 內無法使用 `module`。

**Symptoms / 徵兆**: `module: command not found` in job output; the script silently falls back to system defaults (e.g. system GCC instead of the loaded module).

`module: command not found` 出現在 job 輸出；script 會靜默退回系統預設（例如使用系統 GCC 而非已載入的 module）。

**Fix / 修法**: Add the explicit source line at the top of every Slurm job script that uses modules.

每個用到 module 的 Slurm job script 最上方都加入下列 source 指令。

```bash
source /usr/share/modules/init/bash   # or /usr/share/modules/init/sh
```

**Alternative / 替代方案**: Submit with `sbatch --export=ALL` (default) and pre-load modules via `sbatch --wrap`. This is fragile — the explicit `source` approach is recommended.

以 `sbatch --export=ALL`（預設）並透過 `sbatch --wrap` 預先載入 module。此方法較脆弱，建議仍以顯式 `source` 為主。

**Cluster-wide fix (future) / 集群層級修法（未來）**: Either add `source /usr/share/modules/init/bash` to Slurm's `Prolog` script, or add `--login` to Slurm's `SpawnParameters` in `slurm.conf`. Both have side effects and should be tested before deploying.

可在 Slurm `Prolog` 中加入 `source /usr/share/modules/init/bash`，或在 `slurm.conf` 的 `SpawnParameters` 加入 `--login`。兩者皆有副作用，部署前需測試。

---

## 5. Module Management / Module 管理

### 5.1 Common Operations / 常用操作

List, load, inspect, unload, swap, and default versions.

列出、載入、檢視、卸載、切換版本、設定預設版本。

```bash
# List available software
module avail

# List by category
module avail -C gcc
module avail gcc/

# Load with dependency resolution
module load gcc/15.2
module load openmpi/5.0.5

# View what a module does
module show gcc/15.2

# Unload
module unload gcc/15.2

# Swap versions
module swap gcc gcc/10.4

# Create default version (symlink)
ln -sf /opt/modulefiles/gcc/15.2 /opt/modulefiles/gcc/default
# Then users can: module load gcc  # loads the default
```

### 5.2 Version Policy / 版本策略

| Rule / 規則 | Guideline / 指引 |
|------|-----------|
| Keep old versions / 保留舊版 | Never delete old versions — users may depend on them / 不刪舊版，使用者可能依賴 |
| Latest is default / 預設為最新 | Symlink `default` → latest stable version / `default` symlink 指向最新穩定版 |
| Deprecation / 棄用 | Move to `/opt/modulefiles/<name>/<ver>.deprecated` / 移動到 `/opt/modulefiles/<name>/<ver>.deprecated` |
| EOL removal / EOL 移除 | Announce 3 months before removing any version / 任何版本移除前先公告 3 個月 |

### 5.3 MODULEPATH Configuration / MODULEPATH 設定

The system MODULEPATH lives in `/etc/environment-modules/modulespath`.

系統 MODULEPATH 設定於 `/etc/environment-modules/modulespath`。

```
/opt/modulefiles
/opt/cuda/modulefiles
/opt/intel/modulefiles
/opt/nvhpc/modulefiles
/opt/applications
/opt/openmpi/modulefiles
/usr/share/modules/modulefiles
```

To add a new module path:

新增 module 路徑：

```bash
echo "/opt/<new-path>/modulefiles" >> /etc/environment-modules/modulespath
```

---

## 6. Software-Specific Recipes / 軟體專用配方

### 6.1 Compiler-first: GCC / 編譯器優先：GCC

Bootstrap a new GCC version using `download_prerequisites`.

使用 `download_prerequisites` 啟動新版 GCC。

```bash
# Already done: see /root/install_gcc15.2_with_module_and_slurm.sh
# Template for new GCC version:
PREFIX=/opt/gcc/<ver>
wget https://ftp.gnu.org/gnu/gcc/gcc-<ver>/gcc-<ver>.tar.xz
tar xf gcc-<ver>.tar.xz
cd gcc-<ver>
./contrib/download_prerequisites
mkdir build && cd build
../configure --prefix=$PREFIX \
             --enable-languages=c,c++,fortran \
             --disable-multilib
make -j$(nproc) bootstrap
make install
```

### 6.2 MPI: OpenMPI / MPI：OpenMPI

OpenMPI build with UCX + CUDA when GPU support is needed.

需要 GPU 支援時的 OpenMPI 建置，使用 UCX + CUDA。

```bash
module load gcc/15.2
# Optional: module load ucx/1.17.0 (for InfiniBand support)

./configure --prefix=/opt/openmpi/<ver> \
            --with-ucx=/opt/ucx \
            --with-cuda=/opt/cuda/<ver> \
            --enable-mpi-fortran \
            --enable-mpi-cxx
make -j$(nproc) all
make install
```

**Important / 重要**: Build a separate OpenMPI per CUDA version when GPU support is needed.

需 GPU 支援時，每個 CUDA 版本要建獨立的 OpenMPI。

Existing examples / 既有範例: `/opt/openmpi-5.0.5-cuda12.4`, `/opt/openmpi-cuda11.8`

### 6.3 Libraries: FFTW, HDF5, NetCDF, etc. / 函式庫：FFTW、HDF5、NetCDF 等

Typical MPI-aware library build.

支援 MPI 的典型函式庫建置。

```bash
module load gcc/15.2
module load openmpi/5.0.5  # if MPI variant needed

./configure --prefix=/opt/<name>/<ver> \
            --enable-mpi \
            --enable-openmp \
            --enable-shared \
            CC=gcc CXX=g++ FC=gfortran
make -j$(nproc)
make install
```

### 6.4 GPU Software / GPU 軟體

Load CUDA + a compatible compiler; ensure the chosen OpenMPI was built `--with-cuda`.

載入 CUDA + 相容編譯器；確認所選 OpenMPI 在建置時加了 `--with-cuda`。

```bash
module load cuda/12.6
module load gcc/15.2

# For CUDA-aware MPI
module load openmpi/5.0.5  # must be built with --with-cuda
```

### 6.5 Intel oneAPI Components / Intel oneAPI 元件

Intel oneAPI is installed via its own installer and ships pre-generated modulefiles.

Intel oneAPI 由其自身的 installer 安裝，並提供現成 modulefile。

```bash
# Intel oneAPI is installed via their installer
# Modulefiles are auto-generated in /opt/intel/modulefiles/
module load compiler/latest   # Intel C/C++/Fortran
module load mpi/latest        # Intel MPI
module load mkl/latest        # Intel MKL
```

---

## 7. Build Environment Best Practices / 建置環境最佳實踐

### 7.1 Compiler Flags / 編譯器旗標

Per-node `-march` recommendations based on the heterogeneous mix of CPU generations.

依異質 CPU 世代給出各節點建議的 `-march`。

| Architecture / 架構 | `-march` flag | Notes / 備註 |
|--------------|---------------|-------|
| acmt01-02 (R620, E5-2590v3) | `-march=haswell` | AVX2 |
| acmt04 (R630a, E5-2697v3) | `-march=haswell` | AVX2 |
| acmt05-06 (R630b, E5-2690v3) | `-march=haswell` | AVX2 |
| acmt07,03,12 (R630c/m, E5-2620v4) | `-march=broadwell` | AVX2 |
| acmt09-15 (R630s) | `-march=broadwell` | AVX2 |
| acmt16-19 (Apollo, Silver 4114) | `-march=skylake-avx512` | AVX-512 |
| acmt20 (R740) | `-march=skylake-avx512` | AVX-512 + GPU |
| acmt21-27 (DL360, Gold 6142) | `-march=skylake-avx512` | AVX-512 |
| acmt-gpu (Gigabyte) | `-march=haswell` | GPU-focused |

**Conservative default / 保守預設**: `-march=x86-64-v3` — works on Haswell and later / 適用 Haswell 以後

### 7.2 Building for a Heterogeneous Cluster / 為異質集群建置

Two approaches: one generic build for portability, or per-arch builds for performance-critical code.

兩種策略：通用建置以求可移植，或按架構分別建置以追求效能。

Option A — **Generic build** (recommended for most software) / **通用建置** (大多數軟體建議):
```bash
CFLAGS="-O2 -march=x86-64-v3" CXXFLAGS="-O2 -march=x86-64-v3"
```

Option B — **Multiple builds** (for performance-critical code) / **多版本建置** (效能關鍵程式碼):
```bash
/opt/<name>/<ver>/skylake     # -march=skylake-avx512
/opt/<name>/<ver>/haswell     # -march=haswell
```

### 7.3 Using the Right Compiler / 選擇正確的編譯器

| Task / 任務 | Recommended Compiler / 建議編譯器 |
|------|---------------------|
| General HPC code / 一般 HPC 程式 | GCC 15.2 (`module load gcc/15.2`) |
| Intel-optimized / Intel 最佳化 | Intel oneAPI (`module load compiler/latest`) |
| GPU (CUDA) | GCC 10.4 + CUDA 12.6 |
| NVHPC ecosystem / NVHPC 生態 | NVHPC 24.7 (`module load nvhpc/24.7`) |

---

## 8. Directory & Permission Standards / 目錄與權限規範

### 8.1 Ownership / 擁有權

Default permissions for the standard install tree.

標準安裝樹的預設權限。

```
/opt/<name>/<version>     root:root   755    (standard)
/opt/modulefiles/<name>/<version>  root:root  644
/opt/src/                 root:root   755
```

### 8.2 Shared Workspace for Users / 使用者共享工作區

```
/home/<user>/software/    <user>:<group>  755   (user-private builds)
/opt/apps/shared/        root:lab        755   (group-shared installs)
```

### 8.3 ACLs (if needed) / ACL (需要時使用)

Use POSIX ACLs to grant a group read/execute access without changing ownership.

使用 POSIX ACL 在不變動擁有者的情況下，授予群組讀/執行權。

```bash
# Let lab group read/execute a specific software tree
setfacl -R -m g:lab:rx /opt/<name>/<version>
setfacl -R -m d:g:lab:rx /opt/<name>/<version>
```

---

## 9. Reporting & Documentation / 報告與文件

### 9.1 Install Log Template / 安裝紀錄範本

Every installation should be logged. The cluster-wide change history (including software installs that affect users) lives in [maintenance-log.md](maintenance-log.md) — follow that file's template for entries that touch user-visible behaviour.

每次安裝都應留下紀錄。會影響使用者的軟體安裝請寫入集群層級變更歷史 [maintenance-log.md](maintenance-log.md)，並依該檔範本撰寫。

```bash
cat >> /var/log/software-install/README << 'LOG'

<name>/<version>
  Date:       YYYY-MM-DD
  Installed:  /opt/<name>/<ver>
  Modulefile: /opt/modulefiles/<name>/<ver>
  Built by:   root
  Configure:  ./configure --prefix=... (full command)
  Depends on: gcc/15.2, openmpi/5.0.5
  Notes:      Any special build flags or issues
LOG
```

### 9.2 Announcement / 公告

After installation, notify users via `wall` or e-mail.

安裝後以 `wall` 或 e-mail 通知使用者。

```bash
echo "New software available: <name> <ver>
  module load <name>/<ver>
  See: module help <name>/<ver>" | wall

# Or email users:
mail -s "New Software: <name> <ver>" -b lab@acmt << 'MAIL'
<name> <ver> has been installed on the cluster.
To use it:
  module load <name>/<ver>
MAIL
```

---

## 10. Quick Reference Card / 速查卡

End-to-end command sequence collapsed onto one screen.

整個流程濃縮在一個畫面上的命令序列。

```bash
# === INSTALL FLOW ===
ssh acmt0
sudo -i
cd /opt/src
wget <url> && tar xf <file>
cd <dir>
module load gcc/15.2 openmpi/5.0.5
./configure --prefix=/opt/<name>/<ver> [options]
make -j$(nproc) 2>&1 | tee /var/log/software-install/<name>-<ver>.log
make install

# === MODULEFILE ===
vi /opt/modulefiles/<name>/<ver>
# (use template from section 3.4)

# === TEST ===
module load <name>/<ver>
which <binary> && <binary> --version
ldd $(which <binary>) | grep "not found"
sbatch /tmp/test-<name>.sh

# === ANNOUNCE ===
echo "<name>/<ver> installed — module load <name>/<ver>" | wall
```

---

## Appendix A: Existing Module Environment Reference / 附錄 A：既有 Module 環境參考

Common workflows for the modules already installed on the cluster.

集群既有 module 的常用工作流。

```bash
# View all available software
module avail

# Common workflows
module load gcc/15.2                     # Latest GCC
module load gcc/15.2 openmpi/5.0.5      # Typical HPC build environment
module load cuda/12.6                    # GPU development
module load compiler/latest              # Intel oneAPI compiler
module load mkl/latest                   # Intel MKL
module load nvhpc/24.7                   # NVIDIA HPC SDK
module load ansys/Fluent/v221            # ANSYS Fluent
module load openfoam                     # OpenFOAM 10
module load conda/conda                  # Conda environment
```

## Appendix B: Troubleshooting / 附錄 B：故障排除

| Problem / 問題 | Likely Cause / 可能原因 | Fix / 修法 |
|---------|-------------|-----|
| `module: command not found` | environment-modules not installed, or Slurm batch shell not initialized / 未安裝 environment-modules，或 Slurm batch shell 未初始化 | `apt install environment-modules`. In Slurm jobs: `source /usr/share/modules/init/bash` / Slurm 作業中：`source /usr/share/modules/init/bash` |
| `module avail` shows nothing / `module avail` 無輸出 | MODULEPATH wrong / MODULEPATH 錯誤 | Check `/etc/environment-modules/modulespath` / 檢查 `/etc/environment-modules/modulespath` |
| `./configure` can't find MPI / `./configure` 找不到 MPI | MPI not in PATH / MPI 不在 PATH | `module load openmpi/5.0.5` before configure / 在 configure 前載入 |
| `mpirun` fails with IB error / `mpirun` 出現 IB 錯誤 | UCX missing / 缺少 UCX | `module load ucx/1.17.0` |
| CUDA not found / 找不到 CUDA | CUDA not loaded / 未載入 CUDA | `module load cuda/12.6` |
| `cannot find -lfoo` | Library not in LD_LIBRARY_PATH / library 不在 LD_LIBRARY_PATH | Check `--with-*` flags or add to modulefile / 檢查 `--with-*` 旗標或加入 modulefile |
| Executable can't run on some nodes / 執行檔在部分節點無法執行 | `-march` too new (e.g. AVX-512 binary on Haswell) / `-march` 太新 (如在 Haswell 上跑 AVX-512 binary) | Rebuild with `-march=x86-64-v3` / 以 `-march=x86-64-v3` 重建 |
| Permission denied / 權限不足 | Wrong ownership / 擁有者錯誤 | `chown -R root:root /opt/<name>/<ver>` |
