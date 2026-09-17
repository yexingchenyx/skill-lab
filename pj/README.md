# pj

C++ project built with CMake (C++17).

## Build

```bash
cmake -B build
cmake --build build
```

## Run

Build artifacts go to `build/output/<config>/` (see `cmake/common.cmake`),
e.g. `build/output/Release/` or `build/output/Debug/`:

```bash
./build/output/Release/bin/pj
cmake -B build -DCMAKE_BUILD_TYPE=Debug   # outputs to build/output/Debug/
```

## Build configuration

`cmake/common.cmake` generates `pj/config.h` (from
`cmake/config.h.in`) into `build/output/<config>/include/`. It exposes the
project version, build options (e.g. `PJ_BUILD_TESTS`),
git commit and build time. Include it uniformly as:

```cpp
#include "pj/config.h"
```
