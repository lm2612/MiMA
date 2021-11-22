#!/bin/bash
#SBATCH --job-name=test_MiMA
#SBATCH --ntasks=32
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=4G
#SBATCH --partition=serc
#SBATCH --output=mima_test%j.out
#SBATCH --error=mima_test%j.err
#
# Minimal runscript for atmospheric dynamical cores
ulimit -s unlimited

# Use cees-beta stack
. /home/groups/s-ees/share/cees/spack_cees/scripts/cees_sw_setup-beta.sh

module purge
CEES_MODULE_SUFFIX="cees-beta"

module load devel gcc/10.
module load intel-${CEES_MODULE_SUFFIX}
module load mpich-${CEES_MODULE_SUFFIX}/
module load netcdf-c-${CEES_MODULE_SUFFIX}/
module load netcdf-fortran-${CEES_MODULE_SUFFIX}/
module load anaconda-${CEES_MODULE_SUFFIX}/

cwd=`pwd`

# Currently two libraries are not found in linking on SH03_CEES: libfabric and hwloc. Manually add them here.
export LIBFABRIC_PATH="/home/groups/s-ees/share/cees/spack_cees/spack/opt/spack/linux-centos7-zen2/intel-2021.4.0/libfabric-1.13.1-fcah2ztj7a4kigbly6vxqa7vuwesyxmr/lib/"
export HWLOC_PATH="/home/groups/s-ees/share/cees/spack_cees/spack/opt/spack/linux-centos7-zen2/intel-2021.4.0/hwloc-2.5.0-4yz4g5jbydc4euoqrbudraxssx2tcaco/lib/"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${LIBFABRIC_PATH}:${HWLOC_PATH}"


N_PROCS=32

#--------------------------------------------------------------------------------------------------------
# Setup platform: Mazuma or SH03_CEES
PLATFORM=SH03_CEES

# Setup run directory
run=mima_test
executable=${HOME}/MiMA/exp/exec.${PLATFORM}/mima.x
input=${HOME}/MiMA/input
rundir=${SCRATCH}/MiMA/runs/$run

#--------------------------------------------------------------------------------------------------------
# Make run dir
[ ! -d $rundir ] && mkdir $rundir
# Copy executable to rundir
cp $executable $rundir/
# Copy input to rundir
cp -r $input/* $rundir/
# Run the model
cd $rundir

#--------------------------------------------------------------------------------------------------------
ulimit -s unlimited

echo "run MiMA"
[ ! -d RESTART ] && mkdir RESTART
srun --ntasks $N_PROCS mima.x

CCOMB=${HOME}/MiMA/bin/mppnccombine.${PLATFORM}
$CCOMB -r atmos_daily.nc atmos_daily.nc.*
$CCOMB -r atmos_avg.nc atmos_avg.nc.*
echo "done"


