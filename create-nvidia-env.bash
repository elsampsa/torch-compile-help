#!/bin/bash
## WARNING: run in pytorch-nvidia directory
#conda create -n torch_nvidia -c conda-forge gcc_linux-64=10.3.0 gxx_linux-64=10.3.0 pip
# activate & install necessary stuff
#conda activate torch_nvidia
# cuda into the conda environment:
## all of the above must be done "manually" before launching this script
#
conda install nvidia/label/cuda-12.2.0::cuda-toolkit
conda install cmake ninja
pip install -r requirements.txt
pip install mkl-static mkl-include
conda install -c pytorch magma-cuda121
# optional:
make triton
