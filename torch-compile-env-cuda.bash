#!/bin/bash
## *** WARNING *****************************************
## RUN THIS ONLY AFTER ACTIVATING YOUR CONDA ENVIRONMENT
## *****************************************************

# Ensure we're in a Conda environment
if [ -z "$CONDA_PREFIX" ]; then
    echo "Error: Not in a Conda environment. Please activate your environment first."
    return    
fi

export DEBUG="1"
export USE_CUDA="1" 
export USE_ROCM="0"

# export TORCH_CUDA_ARCH_LIST="6.0 6.1 7.0 7.5 8.0 8.6+PTX"
## this probably saves memory during the build:
export TORCH_CUDA_ARCH_LIST="8.0 8.6+PTX"

## *** system-installed gcc ***
#export CC="gcc-10"
#export CXX="g++-10"
## ****************************
#
## *** conda-installed gcc ***
## should be gcc-10
export CC=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc
export CXX=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++
## ****************************

## *** system-installed cuda ***
#export CUDACXX=/usr/local/cuda-12/bin/nvcc
#export CUDA_BIN_PATH=/usr/local/cuda-12/bin
#export PATH=/usr/local/cuda-12/bin:$PATH
#export CMAKE_CUDA_COMPILER=/usr/local/cuda-12/bin/nvcc
#export CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES=/usr/local/cuda-12/include
## *******************************
#
## *** conda-installed cuda ***
export CUDACXX=$CONDA_PREFIX/bin/nvcc
export CUDA_BIN_PATH=$CONDA_PREFIX/bin
export CMAKE_CUDA_COMPILER=$CONDA_PREFIX/bin/nvcc
export CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES=$CONDA_PREFIX/include
export CUDAHOSTCXX=$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++
export CUDA_HOME=$CONDA_PREFIX
## *****************************

export PATH=$CONDA_PREFIX/bin:$PATH

export _GLIBCXX_USE_CXX11_ABI=1
export CMAKE_PREFIX_PATH=${CONDA_PREFIX:-"$(dirname $(which conda))/../"}
## VERY IMPORTANT: otherwise your mem will blow up during flash attention compilation:

export MAX_JOBS=7
#export USE_FBGEMM=0 
#export USE_KINETO=0 
export BUILD_TEST=0
export CXXFLAGS="$CXXFLAGS -Wl,--no-keep-memory -Wl,--reduce-memory-overheads"
## optional disable flash attention: there seems to be something weird in their templating
## causing runaway mem consumption: https://github.com/Dao-AILab/flash-attention/issues/1043
## disabling flash attention is not required.  other tricks (see above) did it
# export USE_FLASH_ATTENTION=0
## important to avoid runtime library conflicts:

export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH

## remove "~/.local/bin" from the path which is a constant nuisance as some python-based
## executables sometimes start from there (say, pytest, etc.)
export PATH=$(echo $PATH | sed -e "s|:$HOME/.local/bin||" -e "s|$HOME/.local/bin:||")
