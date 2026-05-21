---
title: ACMT HPC Cluster — Software Installation SOP
type: Operations (SOP)
last_updated: 2026-05-22
source_of_truth: This file (procedure); `/opt/modulefiles/` (installed modules)
---

# ACMT HPC Cluster — Software Installation SOP

## 1. Overview

### 1.1 Software Stack Architecture

```
Software install path:  /opt/<name>/<version>/     (on NFS, shared cluster-wide)
Modulefile path:        /opt/modulefiles/<name>/<version>
Source tarballs:        /opt/src/<name>-<version>.tar.gz
Build logs:             /var/log/software-install/<name>-<version>.log
```

- `/opt` is **NFS from acmt-storage** → visible on all nodes
- Install once on **acmt0** (headnode), available everywhere
- All software uses **Environment Modules** (Tcl-based `module` command)
- Builds done with latest GCC or Intel compiler as appropriate

### 1.2 Quickstart (TL;DR)

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

## 2. Directory Conventions

### 2.1 Standard Layout

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

### 2.2 Naming Rules

| Field | Convention | Example |
|-------|-----------|---------|
| `<name>` | lowercase, hyphen-separated | `openmpi`, `fftw`, `gromacs` |
| `<version>` | SemVer (`X.Y` or `X.Y.Z`) | `4.2.1`, `2024.1` |
| Module alias | `latest` symlink to default version | `gcc/latest → gcc/15.2` |

### 2.3 Existing Software Locations

| Software | Installed Path | Modulefile |
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

## 3. Installation Workflow

### 3.1 Standard Build & Install

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

### 3.2 CMake-based Builds

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/software/4.2.1 \
         -DCMAKE_C_COMPILER=gcc \
         -DCMAKE_CXX_COMPILER=g++ \
         -DCMAKE_Fortran_COMPILER=gfortran
make -j$(nproc)
make install
```

### 3.3 Python Packages (Conda)

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

### 3.4 Modulefile Template

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

## 4. Post-Install Validation

### 4.1 Required Checks

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

### 4.2 Slurm Smoke Test

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

### 4.3 ⚠️ Critical: `module` Command in Slurm Jobs

The `module` command is initialized via `/etc/profile.d/modules.sh`, which runs only for **interactive login shells**. Slurm batch jobs run as **non-interactive non-login shells** by default, so `module` is NOT available inside job scripts.

**Symptoms**: `module: command not found` in job output. The script silently falls back to system defaults (e.g., system GCC instead of loaded module).

**Fix**: Add this line at the top of every Slurm job script that uses modules:

```bash
source /usr/share/modules/init/bash   # or /usr/share/modules/init/sh
```

**Alternative**: Submit with `sbatch --export=ALL` (default) and pre-load modules via `sbatch --wrap`, but this is fragile. The explicit `source` approach is recommended.

**Cluster-wide fix** (future): Add `source /usr/share/modules/init/bash` to Slurm's `Prolog` script, or add `--login` to Slurm's `SpawnParameters` in `slurm.conf` — but both have side effects and should be tested before deploying.

---

## 5. Module Management

### 5.1 Common Operations

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

### 5.2 Version Policy

| Rule | Guideline |
|------|-----------|
| Keep old versions | Never delete old versions — users may depend on them |
| Latest is default | Symlink `default` → latest stable version |
| Deprecation | Move to `/opt/modulefiles/<name>/<ver>.deprecated` |
| EOL removal | Annouce 3 months before removing any version |

### 5.3 MODULEPATH Configuration

The system MODULEPATH is configured in `/etc/environment-modules/modulespath`:

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

```bash
echo "/opt/<new-path>/modulefiles" >> /etc/environment-modules/modulespath
```

---

## 6. Software-Specific Recipes

### 6.1 Compiler-first: GCC

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

### 6.2 MPI: OpenMPI

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

**Important**: Build separate OpenMPI for each CUDA version if GPU support needed.
Existing examples: `/opt/openmpi-5.0.5-cuda12.4`, `/opt/openmpi-cuda11.8`

### 6.3 Libraries: FFTW, HDF5, NetCDF, etc.

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

### 6.4 GPU Software

```bash
module load cuda/12.6
module load gcc/15.2

# For CUDA-aware MPI
module load openmpi/5.0.5  # must be built with --with-cuda
```

### 6.5 Intel oneAPI Components

```bash
# Intel oneAPI is installed via their installer
# Modulefiles are auto-generated in /opt/intel/modulefiles/
module load compiler/latest   # Intel C/C++/Fortran
module load mpi/latest        # Intel MPI
module load mkl/latest        # Intel MKL
```

---

## 7. Build Environment Best Practices

### 7.1 Compiler Flags

| Architecture | `-march` flag | Notes |
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

**Conservative default**: `-march=x86-64-v3` (works on Haswell and later)

### 7.2 Building for Heterogeneous Cluster

Option A — **Generic build** (recommended for most software):
```bash
CFLAGS="-O2 -march=x86-64-v3" CXXFLAGS="-O2 -march=x86-64-v3"
```

Option B — **Multiple builds** (for performance-critical code):
```bash
/opt/<name>/<ver>/skylake     # -march=skylake-avx512
/opt/<name>/<ver>/haswell     # -march=haswell
```

### 7.3 Using the Right Compiler

| Task | Recommended Compiler |
|------|---------------------|
| General HPC code | GCC 15.2 (`module load gcc/15.2`) |
| Intel-optimized | Intel oneAPI (`module load compiler/latest`) |
| GPU (CUDA) | GCC 10.4 + CUDA 12.6 |
| NVHPC ecosystem | NVHPC 24.7 (`module load nvhpc/24.7`) |

---

## 8. Directory & Permission Standards

### 8.1 Ownership

```
/opt/<name>/<version>     root:root   755    (standard)
/opt/modulefiles/<name>/<version>  root:root  644
/opt/src/                 root:root   755
```

### 8.2 Shared Workspace for Users

```
/home/<user>/software/    <user>:<group>  755   (user-private builds)
/opt/apps/shared/        root:lab        755   (group-shared installs)
```

### 8.3 ACLs (if needed)

```bash
# Let lab group read/execute a specific software tree
setfacl -R -m g:lab:rx /opt/<name>/<version>
setfacl -R -m d:g:lab:rx /opt/<name>/<version>
```

---

## 9. Reporting & Documentation

### 9.1 Install Log Template

Every installation should be logged:

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

### 9.2 Announcement

After installation:

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

## 10. Quick Reference Card

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

## Appendix A: Existing Module Environment Reference

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

## Appendix B: Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `module: command not found` | environment-modules not installed, or Slurm batch shell not initialized | `apt install environment-modules`. In Slurm jobs: `source /usr/share/modules/init/bash` |
| `module avail` shows nothing | MODULEPATH wrong | Check `/etc/environment-modules/modulespath` |
| `./configure` can't find MPI | MPI not in PATH | `module load openmpi/5.0.5` before configure |
| `mpirun` fails with IB error | UCX missing | `module load ucx/1.17.0` |
| CUDA not found | CUDA not loaded | `module load cuda/12.6` |
| `cannot find -lfoo` | Library not in LD_LIBRARY_PATH | Check `--with-*` flags or add to modulefile |
| Executable can't run on some nodes | `-march` too new (e.g. AVX-512 binary on Haswell) | Rebuild with `-march=x86-64-v3` |
| Permission denied | Wrong ownership | `chown -R root:root /opt/<name>/<ver>` |
