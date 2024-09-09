#!/bin/bash

# Ensure we're in a Conda environment
if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: Not in a Conda environment. Please activate your environment first."
    return
fi

## *** WARNING *****************************************
## RUN THIS ONLY AFTER ACTIVATING YOUR CONDA ENVIRONMENT
## *****************************************************
export DEBUG="1"
export USE_CUDA="0" 
export USE_ROCM="1"

## HACK: sudo copy -r /opt/rocm/include $CONDA_PREFIX/rocm-include
## reason for this is explained in torch-compile.md
export ROCM_PATH=/opt/rocm
export ROCM_INCLUDE=$CONDA_PREFIX/rocm-include

# Define the ROCm architecture you're targeting
# This is an example, adjust according to your GPU
# export ROCM_ARCH="gfx900,gfx906,gfx908"
export ROCM_ARCH="gfx906"

## *** conda-installed gcc ***
export GCC_VERSION="10.3.0"
## should be gcc-10 or compatible version
## NOTE: not gcc, but hipcc
#export CC=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc
#export CXX=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++
export CC=$ROCM_PATH/bin/hipcc
export CXX=$ROCM_PATH/bin/hipcc
## ****************************

# Set the target GPU architecture (adjust as needed)
export PYTORCH_ROCM_ARCH=gfx906

## *** ROCm-specific settings ***
export HIP_PATH=$ROCM_PATH
export HIP_COMPILER=clang
## clang doesn't have built-in rocm support like gcc and with rocm, openmp is in a 
## non-standard location, so we need to tell that to the cmake system:
export OPENMP_ROOT=$ROCM_PATH/llvm
export HCC_HOME=$ROCM_PATH/hcc
export HIP_PLATFORM=amd
export PATH=$ROCM_PATH/bin:$PATH
##
## HIPCC_COMPILE_FLAGS_APPEND environmental variable is very sneaky: it's not documented anywhere.  It's not used by the
## torch cmake system, but instead directly by hipcc
##
## many of the rocm source files use the <> include directive instead of the "" directortive, so for example
## thrust libraries are searched first system-wide and only after that locally installed.. but we should use
## the locally installed that come bundled with the ROCm package..!
# export HIPCC_COMPILE_FLAGS_APPEND="-isystem $ROCM_PATH/include"
## -> doesn't make any difference: https://github.com/ROCm/HIP/issues/3587
## force hip/clang to use the gcc headers installed into the conda environment:
export GCC_INSTALL_DIR=${CONDA_PREFIX}/lib/gcc/x86_64-conda-linux-gnu/$GCC_VERSION
## not used, instead CMAKE_PREFIX_PATH is used for cmake, this is just for interactive stuff in the terminal, feel free to
## use with -I:
export CONDA_INCLUDE=${CONDA_PREFIX}/include
#
export HIPCC_COMPILE_FLAGS_APPEND=$HIPCC_COMPILE_FLAGS_APPEND" --gcc-install-dir=${GCC_INSTALL_DIR}"
## openmp needs to be separately evoked for clang (in contrast to gcc):
export HIPCC_COMPILE_FLAGS_APPEND=$HIPCC_COMPILE_FLAGS_APPEND" -fopenmp"
## HACK for to include rocm include directory before anything else:
export CXXFLAGS="${CXXFLAGS} -D__HIP_PLATFORM_HCC__ -I ${ROCM_INCLUDE} -I ${ROCM_PATH}/lib/llvm/include"
## *******************************

export PATH=$CONDA_PREFIX/bin:$PATH

export _GLIBCXX_USE_CXX11_ABI=1
# export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
export CMAKE_PREFIX_PATH=$ROCM_PATH/lib/llvm/lib:${CONDA_PREFIX}

export MAX_JOBS=7
export BUILD_TEST=0
## these do not work with clang & lvmm ld & will crash your build at link stage..!
# export CXXFLAGS="$CXXFLAGS -Wl,--no-keep-memory -Wl,--reduce-memory-overheads"
## what if we would use this..?
# export LD="$CONDA_ENV_PATH/bin/x86_64-conda-linux-gnu-ld"

# order of preference matters..
# openmp is in that lib/llvm/lib path ... omg ..
export LD_LIBRARY_PATH=$ROCM_PATH/lib:$ROCM_PATH/lib/llvm/lib:$CONDA_PREFIX/lib:$LD_LIBRARY_PATH

## /opt/rocm/llvm/bin/ld.lld: /home/sampsa/anaconda3/envs/torch_rocm/lib/libtinfo.so.6: 
##   no version information available (required by /opt/rocm/llvm/bin/ld.lld)
## --> This warning message suggests that there's a potential mismatch between the 
##     version of libtinfo.so.6 in your Conda environment and the version expected by 
##     the ROCm LLVM linker. 
## https://stackoverflow.com/questions/72103046/libtinfo-so-6-no-version-information-available-message-using-conda-environment
## to shut that up, use:
# export LDFLAGS="$LDFLAGS -Wlinker --allow-shlib-undefined"
## this command should get rid of the message (added to the .md file):
## conda install -c conda-forge ncurses 

# PyTorch-specific ROCm flags
export PYTORCH_ROCM_ARCH=$ROCM_ARCH
export HIPCC_VERBOSE=7  # For verbose output during compilation

# *************** OPTIONAL ************
## WARNING: DON't USE
## Disable AOT Triton if causing issues ()
# export CMAKE_DISABLE_FIND_PACKAGE_TRITON=TRUE
## Disable FBGEMM if not needed (uncomment if you want to disable)
# export USE_FBGEMM=0
# *************************************

## Increase verbosity for debugging
export VERBOSE=1
export CMAKE_VERBOSE_MAKEFILE=ON
## this one gives weirdo error messages at the cmake configuration stage so we disable it:
export USE_MKLDNN=0
## -> avoid OpenMP problems
## for more details, see: https://stackoverflow.com/questions/78957417/building-pytorch-which-openmp-for-rocm
export USE_FBGEMM=0
## -> clang doesn't like the fbgemm library ## or not sure if this was the cmake 3.30 problem.. see the README.md file.. eh

## remove "~/.local/bin" from the path which is a constant nuisance as some python-based
## executables sometimes start from there (say, pytest, etc.)
export PATH=$(echo $PATH | sed -e "s|:$HOME/.local/bin||" -e "s|$HOME/.local/bin:||")
