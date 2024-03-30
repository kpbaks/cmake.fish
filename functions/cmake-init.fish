function cmake-init -d "Bootstrap a CMake project from the context of the current directory"
    # IDEA: create flake.nix
    # IDEA: add c++ modules support if new enough cmake and gcc/clang
    # CMAKE_POSITION_INDEPENDENT_CODE
    set -l options h/help g-gcc c-clang

    if not argparse $options -- $argv
        eval (status function) --help
        return 2
    end

    set -l reset (set_color normal)
    set -l red (set_color red)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l blue (set_color blue)
    set -l bold (set_color --bold)

    if set --query _flag_help
        # TODO: finish help
        printf "%sBootstrap a CMake project from the context of the current directory%s\n" $bold $reset
        return 0
    end >&2

    if set --query _flag_gcc; and set --query _flag_clang
        printf "%serror%s: You can't specify both --gcc and --clang\n" $red $reset
        return 2
    end

    if test $PWD = $HOME
        printf "%serror%s: You are in your \$HOME directory!\n" $red $reset
        printf "It is not a good idea to create a CMake project here.\n"
        return 2
    end

    if test -f CMakeLists.txt
        printf "%serror%s: CMakeLists.txt already exists\n" $red $reset
        return 1
    end

    set -l builddirs build (for build_type in (__cmake_build_types); __cmake_builddir_from_build_type $build_type; end)

    if command --query git; and command git rev-parse --is-inside-work-tree 2>/dev/null >&2
        if not test -d .git
            printf "%serror%s: inside git worktree, but $PWD is not the root dir where .git/ is\n" $red $reset
            return 2
        end

        if not test -f .gitignore
            # command touch .gitignore
            echo "" >.gitignore
            printf " - created .gitignore file\n"
        end

        set -l ignore_rules (command cat .gitignore)
        begin
            set -l compile_commands_json_ignored 0
            set -l clang_index_ignored 0
            for line in $ignore_rules
                if string match --quiet "compile_commands.json" $line
                    set compile_commands_json_ignored 1
                    continue
                end
                if string match --quiet ".clang*" $line
                    set clang_index_ignored 1
                end
            end

            if test $compile_commands_json_ignored -eq 0
                echo "compile_commands.json" >>.gitignore
                printf " - added to %scompile_commands.json%s to .gitignore\n" $blue $reset
            end

            if test $clang_index_ignored -eq 0
                echo ".clang/" >>.gitignore
                printf " - added to %s.clang/%s to .gitignore\n" $blue $reset
            end
        end

        for builddir in $builddirs
            set -l already_ignored 0
            for line in $ignore_rules
                if string match --quiet "$builddir/" $line
                    set already_ignored 1
                    break
                end
            end
            if test $already_ignored -eq 1
                continue
            end
            echo "$builddir/" >>.gitignore
            printf " - added to %s$builddir/%s to .gitignore\n" $blue $reset
        end
    end

    set -l c_compiler
    set -l cxx_compiler
    if set --query _flag_gcc
        if not command --query g++
            printf "%serror%s: g++ not found\n" $red $reset
            return 1
        end
        set cxx_compiler (command --search g++)
        if not command --query gcc
            printf "%serror%s: gcc not found\n" $red $reset
            return 1
        end
        set c_compiler (command --search gcc)
    else if set --query _flag_clang
        if not command --query clang
            printf "%serror%s: clang not found\n" $red $reset
            return 1
        end
        set c_compiler (command --search clang)
        if not command --query clang++
            printf "%serror%s: clang++ not found\n" $red $reset
            return 1
        end
        set cxx_compiler (command --search clang++)
    else
        # TODO: not robust enough
        eval (status function) --gcc
        return
    end

    __cmake_version | read --line cmake_major cmake_minor cmake_patch
    set -l cmake_version (string join . $cmake_major $cmake_minor $cmake_patch)

    if test $cmake_major -ge 3 -a $cmake_minor -ge 16
        echo "cmake_minimum_required(VERSION 3.16...$cmake_version FATAL_ERROR)" >>CMakeLists.txt
    else
        echo "cmake_minimum_required(VERSION $cmake_version FATAL_ERROR)" >>CMakeLists.txt
    end

    if command --query fd
        set -f source_files (fd --type file -e c -e cpp -e h -e hpp)
    else if command --query find
        set -f source_files (find . -type f -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp')
    else
    end

    set -l set -l binaries
    set -l languages

    for f in $source_files
        if contains -- (path basename $f) $builddirs
            continue
        end

        set -l extension (path extension $f)
        switch $extension
            case .c .h
                if not contains -- C $languages
                    set -a languages C
                end
            case .cpp .hpp
                if not contains -- CXX $languages
                    set -a languages CXX
                end
        end
        switch $extension
            case .c .cpp
                if string match --regex --quiet '^(auto|int) +main\([^)]*\)\s*(-> +int)?' <$f
                    set -a binaries $f
                end
        end
    end

    if test (count $languages) -eq 0
        # Assume you are going to write a C++ program
        set -a languages CXX
    end

    set -l project_name (path basename $PWD)


    echo "project($project_name LANGUAGES $languages VERSION 0.1.0)" >>CMakeLists.txt
    echo "" >>CMakeLists.txt
    # TODO: determine the standard version from the compiler version
    set -l cxx_standard 23
    set -l c_standard 23
    echo "# set(CMAKE_C_COMPILER $c_compiler)" >>CMakeLists.txt
    echo "set(CMAKE_C_STANDARD $c_standard)" >>CMakeLists.txt
    echo "set(CMAKE_C_EXTENSIONS OFF)" >>CMakeLists.txt
    echo "set(CMAKE_C_STANDARD_REQUIRED ON)" >>CMakeLists.txt
    echo "" >>CMakeLists.txt
    echo "# set(CMAKE_CXX_COMPILER $cxx_compiler)" >>CMakeLists.txt
    echo "set(CMAKE_CXX_STANDARD $cxx_standard)" >>CMakeLists.txt
    echo "set(CMAKE_CXX_STANDARD_REQUIRED ON)" >>CMakeLists.txt
    echo "set(CMAKE_CXX_EXTENSIONS OFF)" >>CMakeLists.txt
    echo "set(CMAKE_EXPORT_COMPILE_COMMANDS ON)" >>CMakeLists.txt
    echo "" >>CMakeLists.txt

    if test $cmake_major -ge 3 -a $cmake_minor -ge 24
        echo "set(CMAKE_COLOR_DIAGNOSTICS ON)" >>CMakeLists.txt
    else
        echo '
# Force compiler to output in color when you use ninja as generator
# https://stackoverflow.com/questions/73349743/ninja-build-system-gcc-clang-doesnt-output-diagnostic-colors
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fdiagnostics-color=always")
' >>CMakeLists.txt
    end

    # https://mzhang.io/posts/2022-03-03-clangd-in-nix/
    if test -f flake.nix -o -f shell.nix
        echo '
# ensure that `clangd` can find standard headers when using `nix shell` or `nix develop`
set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
    '
    else
        echo '
# ensure that `clangd` can find standard headers when using `nix shell` or `nix develop`
# set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
    ' >>CMakeLists.txt
    end

    echo "
if (CMAKE_CXX_COMPILER_ID STREQUAL \"GNU\" OR CMAKE_CXX_COMPILER_ID STREQUAL \"Clang\")
    set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic -Werror\")
endif()
    " >>CMakeLists.txt

    if command --query sccache
        echo '
find_program(SCCACHE sccache REQUIRED)

set(CMAKE_C_COMPILER_LAUNCHER ${SCCACHE})
set(CMAKE_CXX_COMPILER_LAUNCHER ${SCCACHE})
# set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded)
cmake_policy(SET CMP0141 NEW)
' >>CMakeLists.txt
    else
        set -l sccache_url https://github.com/mozilla/sccache
        printf '%swarn:%s sccache not found (see %s)\n' $yellow $reset $sccache_url
    end

    # clang-tidy , clang-format
    # TODO: set compiler more flags

    echo "add_compile_options(-march=native)" >>CMakeLists.txt
    # TODO: detect glibc or musl
    # echo "add_compile_options(-mglibc)" >>CMakeLists.txt
    # echo "add_compile_options(-mmusl)" >>CMakeLists.txt

    echo "# add_compile_options(-fno-exceptions)" >>CMakeLists.txt
    echo "add_compile_options(-fno-rtti)" >>CMakeLists.txt
    echo "add_compile_options(-fno-omit-frame-pointer)" >>CMakeLists.txt
    echo "add_compile_options(-fno-strict-aliasing)" >>CMakeLists.txt
    echo "add_compile_options(-fno-strict-overflow)" >>CMakeLists.txt

    # https://gcc.gnu.org/onlinedocs/gcc-13.2.0/gcc/x86-Options.html
    # echo "add_compile_options(-fvisibility=hidden)" >>CMakeLists.txt

    echo "# Sanitizers
# add_compile_options(-fsanitize=address) # AddressSanitizer
# add_compile_options(-fsanitize=undefined) # UndefinedBehaviorSanitizer
# add_compile_options(-fsanitize=thread) # ThreadSanitizer
# add_compile_options(-fsanitize=memory) # MemorySanitizer
" >>CMakeLists.txt

    # https://gcc.gnu.org/onlinedocs/gcc-13.2.0/gcc/Instrumentation-Options.html#index-prof
    echo "# add_compile_options(-p) # Generate extra code to write profile information suitable for the analysis program prof" >>CMakeLists.txt
    # https://gcc.gnu.org/onlinedocs/gcc-13.2.0/gcc/Instrumentation-Options.html#index-gcov
    echo "# add_compile_options(--coverage) # Enable coverage testing that `gcov` can analyze" >>CMakeLists.txt

    echo "# add_compile_options(-flto) # Link-time optimization" >>CMakeLists.txt

    # TODO: add info/warn for the other linkers
    if command --query mold
        echo "add_compile_options(-fuse-ld=mold) # Use the Modern Linker (mold) instead of the default linker." >>CMakeLists.txt
        printf '%sinfo:%s found mold at %s%s%s. using it as linker\n' $green $reset (set_color $fish_color_command) (command --search mold) $reset
    else if command --query lld
        echo "add_compile_options(-fuse-ld=lld) # Use the LLVM Linker (lld) instead of the default linker." >>CMakeLists.txt
    else if command --query gold
        echo "add_compile_options(-fuse-ld=gold) # Use the GNU Gold Linker (gold) instead of the default linker." >>CMakeLists.txt
    end

    set -l library_dependencies

    echo "" >>CMakeLists.txt
    echo "include(FetchContent)" >>CMakeLists.txt

    begin
        echo "
# `#include <argparse/argparse.hpp>`
FetchContent_Declare(argparse GIT_REPOSITORY https://github.com/p-ranav/argparse.git)
FetchContent_MakeAvailable(argparse)
        "

        set -a library_dependencies argparse

    end >>CMakeLists.txt

    begin
        echo "
FetchContent_Declare(
  Catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG        v3.5.3 # or a later release
)

# exposes 2 targets: `Catch2::Catch2` and `Catch2::Catch2WithMain`
FetchContent_MakeAvailable(Catch2)
        "

    end >>CMakeLists.txt

    begin
        echo "
# Similar to `dbg!()` in Rust
# `#include <dbg.h>`
FetchContent_Declare(dbg_macro GIT_REPOSITORY https://github.com/sharkdp/dbg-macro)
FetchContent_MakeAvailable(dbg_macro)
# add_compile_definitions(DBG_MACRO_DISABLE) # disable the `dbg()` macro (i.e. make it a no-op)
# add_compile_definitions(DBG_NO_WARNING) # disable the \"'dbg.h' header is included in your code base\" warnings
# add_compile_definitions(DBG_NO_WARNING) # force colored output and skip tty checks.
# use `dbg(dbg::time());` to print a timestamp
" >>CMakeLists.txt

        set -a library_dependencies dbg_macro
    end

    begin
        echo "
# `#include <fmt/core.h>`
FetchContent_Declare(fmt GIT_REPOSITORY https://github.com/fmtlib/fmt GIT_TAG master)
FetchContent_MakeAvailable(fmt)
" >>CMakeLists.txt

        set -a library_dependencies fmt::fmt
    end

    begin
        echo "
# `#include <flux.hpp>`
FetchContent_Declare(
    flux
    GIT_REPOSITORY https://github.com/tcbrindle/flux.git
    GIT_TAG main # Replace with a git commit id to fix a particular revision
)
FetchContent_MakeAvailable(flux)
        " >>CMakeLists.txt

        set -a library_dependencies flux::flux
    end

    begin
        echo "
# `#include <spdlog/spdlog.h>`
FetchContent_Declare(spdlog GIT_REPOSITORY https://github.com/gabime/spdlog.git GIT_TAG v1.13.0)
FetchContent_MakeAvailable(spdlog)
" >>CMakeLists.txt

        set -a library_dependencies spdlog::spdlog
    end


    if test -d include
        echo "
include_directories(include)
" >>CMakeLists.txt
    end


    echo "
set(executable_targets)
" >>CMakeLists.txt
    for f in $binaries
        # if contains -- (path dirname $f | string split / --fields=1) build cmake-build-{debug,release,minsizerel,relwithdebinfo}
        if contains -- (path dirname $f | string split / --fields=1) $builddirs
            # Some source file in a build directory
            continue
        end
        set -l target_name (path basename $f | string split . --right --fields=1)
        echo "add_executable($target_name $f)" >>CMakeLists.txt
        if test (count $library_dependencies) -gt 0
            echo "target_link_libraries($target_name PRIVATE $library_dependencies)" >>CMakeLists.txt
        end
        echo "list(APPEND executable_targets $target_name)" >>CMakeLists.txt
    end

    if test (count $binaries) -eq 0
        echo "
# add_executable(\${PROJECT_NAME} main.cpp)
# add_library(\${PROJECT_NAME} lib.cpp)
# target_link_libraries(\${PROJECT_NAME} PRIVATE $library_dependencies)
        " >>CMakeLists.txt
    end

    # TODO: maybe use `cmake --system-information`

    printf "%sCMakeLists.txt%s has been created with the following content:\n\n" $green $reset

    if command --query bat
        command bat --style=plain --language=cmake CMakeLists.txt
    else
        command cat CMakeLists.txt
    end
end
