#!/bin/bash
## WARNING: run in pytorch-amd directory
#conda create -n torch_rocm -c conda-forge gcc_linux-64=10.3.0 gxx_linux-64=10.3.0 zlib pip
# activate & install necessary stuff
#conda activate torch_rocm
# a HACK to fix a bug in the hipcc compiler toolchain (**)
## All of the above must be done "manually" before launching this script
#
cp -r /opt/rocm/include $CONDA_PREFIX/rocm-include
which pip # check that the conda env pip is being used
conda install cmake ninja
pip install -r requirements.txt
pip install mkl-static mkl-include
# optional:
make triton
