function cmake-init -d "Bootstrap a CMake project from the context of the current directory"
    set -l options h/help g-gcc c-clang

    if not argparse $options -- $argv
        eval (status function) --help
        return 2
    end

    set -l reset (set_color normal)
    set -l red (set_color red)
    set -l green (set_color green)
    set -l blue (set_color blue)
    set -l bold (set_color --bold)

    if set --query _flag_help
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

    # TODO: detect git and add gitignore with `cmake-build-*` and `compile_commands.json`
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

        set -l builddirs build (for build_type in (__cmake_build_types); __cmake_builddir_from_build_type $build_type; end)
        set -l ignore_rules (command cat .gitignore)

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
                # TODO: improve the regex to handle `auto main() -> int`
                if string match --regex --quiet '^int main([^]]*)\s*{?' <$f
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
    echo "set(CMAKE_C_COMPILER $c_compiler)" >>CMakeLists.txt
    echo "set(CMAKE_C_STANDARD $c_standard)" >>CMakeLists.txt
    echo "set(CMAKE_C_EXTENSIONS OFF)" >>CMakeLists.txt
    echo "set(CMAKE_C_STANDARD_REQUIRED ON)" >>CMakeLists.txt
    echo "" >>CMakeLists.txt
    echo "set(CMAKE_CXX_COMPILER $cxx_compiler)" >>CMakeLists.txt
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


    echo "
if (CMAKE_CXX_COMPILER_ID STREQUAL \"GNU\" OR CMAKE_CXX_COMPILER_ID STREQUAL \"Clang\")
    set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -Wall -Wextra -Wpedantic -Werror\")
endif()
    " >>CMakeLists.txt

    # TODO: set compiler more flags




    if test -d include
        echo "
include_directories(include)
" >>CMakeLists.txt
    end

    echo "
set(executable_targets)
" >>CMakeLists.txt
    for f in $binaries
        if contains -- (path dirname $f | string split / --fields=1) build cmake-build-{debug,release,minsizerel,relwithdebinfo}
            # Some source file in a build directory
            continue
        end
        set -l target_name (path basename $f | string split . --right --fields=1)
        echo "add_executable($target_name $f)" >>CMakeLists.txt
        echo "list(APPEND executable_targets $target_name)" >>CMakeLists.txt
    end

    # TODO: maybe use `cmake --system-information`

    printf "%sCMakeLists.txt%s has been created with the following content:\n\n" $green $reset

    if command --query bat
        command bat --style=plain --language=cmake CMakeLists.txt
    else
        command cat CMakeLists.txt
    end
end
