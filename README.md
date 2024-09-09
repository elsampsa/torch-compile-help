# Pytorch compilation with conda for CUDA and ROCm

## 0. Word of warning

Compilation can require up to 30GB of RAM.  Recommended laptop has at least 20 processors and 64GB of memory.

Both nvidia and amd version take at least half an hour to compile.

When compiling in a conda environment, one must be carefull to 

- use the correct preference of compile include `-I` arguments to get the right header files at compilation stage.
- at link stage, `-L`'s should point to correct directories.
- at run stage, environmental variable `LD_LIBRARY_PATH` should have the correct path order to find those same libraries
- these parameters must be passed to to cmake using *other* environmental variables (particular to the pytorch build system)

So for all of these, the preference is first in the conda environment directory and after that in the system-wide directories.

A very nasty pitfall:

The combination of cmake 3.30+ and ninja breaks up the build system completely (by chance observed this at ROCm compilation but for sure true for cuda as well), 
so please use always cmake ~ 3.26.

For example if you use the channel "conda forge" to install cmake, you'll get cmake 3.30 that breaks the build system, so use channel default instead.

This is taken care of in the commands below.

## 1. Get anaconda & torch

Install anaconda
```bash
# install anaconda: google is your friend
# NOTE: stuff is written to your .bashrc
conda config --set auto_activate_base false
```

Get torch from: https://github.com/pytorch/pytorch?tab=readme-ov-file#from-source
```bash
git clone https://github.com/pytorch/pytorch
cd pytorch
git checkout release/2.4 # it's better to use a release than the current main
# remember this after checking out torch with submodules
git submodule update --init --recursive
cd ..
cp -r pytorch pytorch-nvidia # let's make a separate dir for the nvidia/cuda case
cp -r pytorch pytorch-amd # same for rocm
```

## 2. CUDA version

GCC version 10 and cuda 12 are both installed into the conda environment.

### Create & prepare conda env

Create a conda environment with gcc 10 inside:
```bash
## WARNING: run in pytorch-nvidia
conda create -n torch_nvidia -c conda-forge gcc_linux-64=10.3.0 gxx_linux-64=10.3.0 pip
# activate & install necessary stuff
conda activate torch_nvidia
## you can type the following lines manually or use create-nvidia-env.bash
# cuda into the conda environment:
conda install nvidia/label/cuda-12.2.0::cuda-toolkit
conda install cmake ninja
pip install -r requirements.txt
pip install mkl-static mkl-include
conda install -c pytorch magma-cuda121
# optional:
make triton
```

NOTE: You can check which gcc compiler nvcc is using with:
```bash
touch /tmp/paska.cu; nvcc -v /tmp/paska.cu
```

### Compile & Use

Before starting compilation, remember to source the provided `torch-compile-env-cuda.bash`.
```bash
conda activate torch_nvidia
cd pytorch-nvidia
source ../torch-compile-env-cuda.bash
python setup.py develop
# finally, test the torch import with:
python setup.py develop && python -c "import torch"
```
Removing a build:
```bash
rm -rf build; python setup.py clean
```

When using the environment, always remember to source the environmental script (only once).

## 3. ROCm version

So here we mix a system-wide installation (ROCm) and a conda-environment installation (gcc, cmake, ninja, pip installed packages, etc.)

A system-wide installation of ROCm is done (there seems to be no conda package for it).  GCC 10 and all other stuff is installed into the conda environment.

Do ROCm system-wide installation as instructed in [here](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/install/quick-start.html).

### Create / prepare the conda environment

```bash
## run in pytorch-amd
conda create -n torch_rocm -c conda-forge gcc_linux-64=10.3.0 gxx_linux-64=10.3.0 zlib pip
# activate & install necessary stuff
conda activate torch_rocm
## you can type the following lines manually or use create-nvidia-amd.bash
# a HACK to fix a bug in the hipcc compiler toolchain (**)
cp -r /opt/rocm/include $CONDA_PREFIX/rocm-include
# cmake --version: 3.26.4 / ninja --version: 1.11.1.git.kitware.jobserver-1
conda install cmake ninja
which pip # check that the conda env pip is being used
pip install -r requirements.txt
pip install mkl-static mkl-include
# optional:
make triton
```

Overview of env variables when compiling stand-alone programs with ROCm/HIP (don't worry, these have been collected into the env var script - see below):
```bash
export ROCM_PATH=/opt/rocm # this is a link to /opt/rocm-version
# export ROCM_INCLUDE=$ROCM_PATH/include
## ..should be the previous, but we need to use this (** - see below):
export ROCM_INCLUDE=$CONDA_PREFIX/rocm-include
export HIP_PLATFORM=amd # avoid HIP calling nvcc (a part that doesn't work that well)
export HCC_AMDGPU_TARGET=gfx906 # target architecture
export HIP_CLANG_PATH=$ROCM_PATH/llvm/bin
## clang needs to hook up into the correct header files of the gcc installation inside the conda environment:
export GCC_VERSION=10.3.0
export $GCC_INSTALL_DIR=${CONDA_PREFIX}/lib/gcc/x86_64-conda-linux-gnu/$GCC_VERSION
export CONDA_INCLUDE=${CONDA_PREFIX}/include
## at link & runtime, rocm libraries first:
export LD_LIBRARY_PATH=$ROCM_PATH/lib:$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
```
ROCm uses clang (and llvm) and comes bundled with the correct clang version.  Don't ever
try to use another version instead.

You can source [torch-compile-env-rocm.bash](torch-compile-env-rocm.bash) to get all the env variables right.

Finally, you can check that everything's in order with:
```bash
clear; touch /tmp/paska.hip; hipcc -v --gcc-install-dir=$GCC_INSTALL_DIR -I $ROCM_INCLUDE -I $CONDA_INCLUDE /tmp/paska.hip
```
That reports what environmental variables the compiler uses.  It also shows **on which order the header file directories are included**.
For the latter you can also use [./testinc.bash](./testinc.bash).

### Compile & Use

Before starting compilation, remember to source the provided `torch-compile-env-rocm.bash`.  NOTE: `rocm` in the filename.
```bash
conda activate torch_rocm
cd pytorch-amd
source ../torch-compile-env-rocm.bash # run only once, not twice!
## RUN THE "Removing a build" COMMAND INDICATED BELOW
python setup.py develop
# finally, test the torch import with:
python setup.py develop && python -c "import torch"
```
Removing a build:
```bash
rm -rf build && python setup.py clean && git reset --hard && git clean -fd && git submodule foreach --recursive git reset --hard && python tools/amd_build/build_amd.py
```

When using the environment, always remember to source the environmental script (only once).

### Why ROCm compilation is more complicated that CUDA?

#### Code conversion & modification

Pytorch ROCm build does some extra stuff with that `build_amd.py` script, say, churns cuda code into hip code, etc.  

- Hipifies code in `torch/csrc/`
- Modifies some submodule code, for example `third_party/kineto`: changes `-D` directives in `libkineto/CMakeLists.txt`

#### Conflicting libraries

ROCm comes with many bundled components that can clash with the system-wide/conda env installed components (header files and shared libraries).

- ROCm comes budled with Thrust and OpenMP libraries among others
- A separate clang and llvm compilers come bundled with ROCm - use these instead of the gcc complier installed in your system
- ..however, they use gcc-toolchain header files installed system-wide (or in the conda environment as in our case)
- By default, cmake doesn't find OpenMP, and the openmp compiler must be explicitly set to custom-installed (i.e. in `/opt/roc`) llvm
- For example the thrust libraries are included in pytorch in many places with <> directive instead of "" directive --> the build system may look for them in the system-wide/conda env installation first instead of `/opt/rocm/include`.  Take a look at [torch-compile-env-rocm.bash](torch-compile-env-rocm.bash) how we fix this.

Some disabled libraries:

- To avoid OpenMP-related error messages, we set `export USE_MKLDNN=0`, see [this](https://stackoverflow.com/questions/78957417/building-pytorch-which-openmp-for-rocm)
- Clang doesn't like the fbgemm module, so we set `export USE_FBGEMM=0`, see [this](https://discuss.pytorch.org/t/clang-and-fbgemm/209305).  NOTE: this might have actually been
  the cmake 3.30+ problem as mentioned in the very beginning of this readme file

#### Bug in the HIPCC compiler wrapper (**)

As per [here](https://github.com/ROCm/HIP/issues/3587).

We want to include header files in the following ascending preference order:
- `/opt/rocm/include` : ROCm
- `$CONDA_PREFIX/include` : Conda environment
- `/usr/include` : System-wide

This should be straightforward: just do `-I /opt/rocm/include -I $CONDA_PREFIX/include -I /usr/include` in the c++ compilation commands.
But it turns out that when using these with the hipcc command, it always puts `/opt/rocm/include` as the last include.  That is the reason
we make a copy of the header files to another name (see above).

## 4. Test your pytorch

Test the compilation with:
```bash
pytest test/test_nn.py
```

## 5. Development

While in your desired environment (nvidia or rocm), iterate this:
```bash
## edit your c++ and cuda/hip
ninja build # builds with the modified files
python setup.py develop # installs pytorch in development mode (again)
```

## 6. /tmp

### Installing gcc and cuda system-wide

*WARNING: DO NOT do this, install both nvidia and gcc inside the conda environment instead*

`nvidia-smi` reports the driver version & cuda version, but when you type `nvcc --version` the cuda version
might not match that of the drivers.

Better to make them match.  Apply your cuda major & minor versions to these commands:
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda-repo-ubuntu2204-12-2-local_12.2.2-535.104.05-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2204-12-2-local_12.2.2-535.104.05-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2204-12-2-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda
```
NOTE: Cuda installed from nvidia repos creates `/usr/local/cuda/` directories (the default ubuntu package for some reason doesn't)

gcc 10:
```bash
sudo apt-get install gcc-10 g++-10
```

```bash
/usr/lib/x86_64-linux-gnu/libstdc++.so.6/libstdc++.so.6  --> has 3.4.0
/home/sampsa/anaconda3/envs/torch_nvidia/lib/libstdc++.so.6 --> only has up to 3.3.X  ## prefer this during compilation
```

## 7. Test problems

With cuda, there were two failures out of aprox 2500 tests:
```bash
python test/test_nn.py TestNNDeviceTypeCUDA.test_GRU_grad_and_gradgrad_cuda_float64
python test/test_nn.py TestNNDeviceTypeCUDA.test_LSTM_grad_and_gradgrad_cuda_float64
```

## 8. Notes About the PyTorch build system

Look into `tools/setup_helpers/cmake.py`.  There it is stated that "We currently pass over all environment variables that start with "BUILD_", "USE_", and "CMAKE_", i.e.
these are passed to the cmake command with `-D` & they become cmake variables.

```python
from tools.build_pytorch_libs import build_caffe2
from tools.setup_helpers.cmake import CMake
...
cmake = CMake()
def get_submodule_folders() # reads .gitmodules, etc.
def check_submodules() # initializes the submodules
...
build_caffe2(
    ...
    cmake=cmake,
)
    -> cmake.generate(cmake_args, env=my_env)
        -> wraps cmake command
       cmake.build(build_args, env=my_env)
```

