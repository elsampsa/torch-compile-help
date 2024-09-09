#!/bin/bash
echo "ROCM_PATH: "$ROCM_PATH
echo "ROCM_INCLUDE: "$ROCM_INCLUDE
touch /tmp/paska.hip
## just testing that -isystem --> doesn't have any effect - good
$ROCM_PATH/bin/hipcc -v --gcc-install-dir=$GCC_INSTALL_DIR -isystem $CONDA_INCLUDE -I $ROCM_INCLUDE -I $CONDA_INCLUDE /tmp/paska.hip 2>&1 \
| sed -n '/search starts here:/,/End of search list./p' | grep -v 'search starts here:\|End of search list.'
