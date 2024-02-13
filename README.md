# cmake.fish
A couple of fish abbreviations to make cmake less of a headache to work with.  

## Installation

### Using [`fisher`](https://github.com/jorgebucaran/fisher)

```fish
fisher install kpbaks/cmake.fish
```


## Abbreveations

```fish
# cmake configure
abbr -a cmc -f abbr_cmake_configure_debug --set-cursor
abbr -a cmcd -f abbr_cmake_configure_debug --set-cursor
abbr -a cmcr -f abbr_cmake_configure_release --set-cursor
abbr -a cmcw -f abbr_cmake_configure_rel_with_deb_info --set-cursor
abbr -a cmcm -f abbr_cmake_configure_min_size_rel --set-cursor
# cmake build
abbr -a cmb -f abbr_cmake_build --set-cursor
# cmake configure and build
abbr -a cmcb -f abbr_cmake_configure_debug_and_build --set-cursor
abbr -a cmcdb -f abbr_cmake_configure_debug_and_build --set-cursor
abbr -a cmcrb -f abbr_cmake_configure_release_and_build --set-cursor
```

Every abbreviation will only expand if the current directory contains a `CMakeLists.txt` file, and `cmake` is found in `$PATH`.

### `cmc{,d,r,w,m}`

```fish
# cmc{,d} ->
cmake -S . -B cmake-build-debug -G 'Ninja' -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=Debug
# cmcr -> 
cmake -S . -B cmake-build-release -G 'Ninja' -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=Release
# cmcw ->
cmake -S . -B cmake-build-relwithdebinfo -G 'Ninja' -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
# cmcm ->
cmake -S . -B cmake-build-minsizerel -G 'Ninja' -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=MinSizeRel
```

Every abbreviation will check what CMake generators are available and use the first one found in `$PATH` from the following list:
1. `ninja` 
2. `make`

### `cmb`

```fish
# If not build directory exists, expand to the comment:
#  No cmake build directory has been configured yet

# If one build directory exists, e.g. 'cmake-build-debug' expand to:
set -l jobs (math (nproc) - 1) # Leave 1 CPU core to not freeze the system ;)
cmake --build 'cmake-build-debug' --parallel $jobs --target all

# If multiple build directories exist, e.g. 'cmake-build-debug' and 'cmmake-build-release'
# then open a fzf prompt to select the build directory to build. and expand to:
set -l jobs (math (nproc) - 1) # Leave 1 CPU core to not freeze the system ;)
cmake --build '$selected_builddir' --parallel $jobs --target all
```

### `cmcb{,d,r}`

A combination of `cmc{,d,r,w,m}` and `cmb` abbreviations.

```fish
# e.g. cmcrb ->
cmake -S . -B cmake-build-release -G 'Ninja' -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=Release                                  
set -l jobs (math (nproc) - 1) # Leave 1 CPU core to not freeze the system ;)
cmake --build 'cmake-build-release' --parallel $jobs --target all
```
