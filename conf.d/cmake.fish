# TODO: check if `cmake-build-{debug,release}` is ignored by `.gitignore` (if in a gitproject)
# if not, then suggest to add it
# TODO: support CMakePresets.json

if not command --query cmake
    printf "[cmake.fish] %serror%s: `cmake` not found in \$PATH, no abbreviations will be created\n" (set_color red) (set_color normal)
    return 1
end

# All functions from here on assumes that `cmake` exists in `$PATH`

function __cmake::version
    command cmake --version | string match --regex --groups-only "(\d+\.\d+(\.\d+))" | read --line entire patch
    string split . $entire
end

function __cmake_common_configure_flags
    # TODO: expose a universal variable the user can use to add common settings they always want to use
    # TODO: Add a universal available to select the default compiler to use. Maybe "parse" CMakeLists.txt to see if they have
    # specified it first.
    echo -Wdeprecated
    echo "-DCMAKE_EXPORT_COMPILE_COMMANDS=1"
    __cmake::version | read --line major minor patch
    # The compiler (gcc, clang) strips ANSI escape codes from its diagnostic output i.e. reporting errors and warnings,
    #  if it detects that its stdout is not a tty (uses the syscall: `isatty(stdout)`). When invoked through cmake->ninja, it's stdout
    # is attached to a pipe, but the compiler can be forced to always output ANSI escape codes by one of the following defines below:
    if test $major -ge 3 -a $minor -ge 24
        # cmake v3.24.* got support for a dedicated variable to control color diagnostics
        # https://cmake.org/cmake/help/latest/variable/CMAKE_COLOR_DIAGNOSTICS.html
        echo "-DCMAKE_COLOR_DIAGNOSTICS=ON"
    else
        # For older versions of cmake, this compiler flag is supported by both gcc and clang.
        echo "-DCMAKE_CXX_FLAGS=-fdiagnostics-color=always"
    end
end

function __cmake::abbr::set_number_of_jobs
    echo "set -l jobs (math (nproc) - 1) # Leave 1 CPU core to not freeze the system ;)"
end

function __cmake_find_targets
    # TODO: implement
end

function __cmake_build_types
    printf "%s\n" Debug Release RelWithDebInfo MinSizeRel
end

function __cmake_supported_build_type -a build_type
    argparse --min-args 1 --max-args 1 -- $argv; or return 2
    # status print-stack-trace
    # supported build types taken from: https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html
    set -l supported_build_types Debug Release RelWithDebInfo MinSizeRel
    if not contains -- $build_type $supported_build_types
        printf "# % is not among the supported build types: %s\n" (string join ", " $supported_build_types)
        return 1
    end
end

function __cmake_builddir_from_build_type -a build_type
    argparse --min-args 1 --max-args 1 -- $argv; or return 2
    if not __cmake_supported_build_type $build_type
        return 2
    end

    echo cmake-build-(string lower $build_type)

    # switch $build_type
    #     case Debug
    #         echo cmake-build-debug
    #     case Release
    #         echo cmake-build-release
    #     case RelWithDebInfo
    #         echo cmake-build-relwithdebinfo
    #     case MinSizeRel
    #         echo cmake-build-minsizerel
    # end
end

function __cmake::find_build_dirs
    for f in *
        test -d $f; or continue
        test -d $f/CMakeFiles; or continue
        test -f $f/CMakeCache.txt; or continue
        echo $f
    end
end

function __cmake::find_generators
    # TODO: find other generators available on unix platforms
    set -l generators
    if command --query ninja
        # echo Ninja
        set -a generators Ninja
    end
    if command --query make
        # echo "Unix Makefiles"
        set -a generators "Unix Makefiles"
    end
    if test (count $generators) -eq 0
        return 1
    else
        printf "%s\n" $generators
    end
end

function abbr_cmake_configure -a build_type
    if not __cmake_supported_build_type $build_type
        return 2
    end

    if not test -f CMakeLists.txt
        echo "# ./CMakelists.txt not found in $PWD"
        return 1
    end

    set -l generators (__cmake::find_generators)
    # TODO: list available generators
    if test $status -ne 0
        echo "# No \"cmake generator\" found in \$PATH"
        echo "# The following generators are supported on unix platforms by cmake:"
        echo "# - 'Ninja' requires `ninja` to be installed in \$PATH"
        echo "# - 'Ninja Multi-Config' requires `ninja` to be installed in \$PATH"
        echo "# - 'Unix Makefiles' requires `make` to be installed in \$PATH"
        echo "# tip: prefer 'Ninja' over 'Unix Makefiles' for faster builds"

        return 1
    end

    set -l generator $generators[1] # use the first one, it has highest priority

    set -l builddir (__cmake_builddir_from_build_type $build_type)
    # TODO: print notification if already configured, and add a timestamp to estimate how long ago it was configured
    set -l configure_flags (__cmake_common_configure_flags)
    set -a configure_flags "-DCMAKE_BUILD_TYPE=$build_type"

    echo "cmake -S . -B $builddir -G '$generator' $configure_flags"
end

function __cmake::abbr::configure_debug
    abbr_cmake_configure Debug
    return 0 # abbrs does not expand if return code != 0
end

function abbr_cmake_configure_release
    abbr_cmake_configure Release
    return 0 # abbrs does not expand if return code != 0
end

function abbr_cmake_configure_rel_with_deb_info
    abbr_cmake_configure RelWithDebInfo
    return 0 # abbrs does not expand if return code != 0
end
function abbr_cmake_configure_min_size_rel
    abbr_cmake_configure MinSizeRel
    return 0 # abbrs does not expand if return code != 0
end

# NOTE: not meant to be used as the --function given to an abbr, used by wrapper functions instead
function abbr_cmake_build_inner -a build_type
    set -l options c/configure
    if not argparse $options -- $argv
        return 2
    end

    # TODO: refactor into a function that checks prerequisites are met
    if not test -f CMakeLists.txt
        echo "# ./CMakelists.txt not found in $PWD"
        return 1
    end

    if test (count $argv) -eq 1
        if not __cmake_supported_build_type $build_type
            return 2
        end

        set -f builddir (__cmake_builddir_from_build_type $build_type)
        # echo "builddir: $builddir"
        if not test -d $builddir; and set --query _flag_configure
            # Not configured yet. Notify user and expand configure abbr instead
            echo "# Build directory '$builddir' associated with -DCMAKE_BUILD_TYPE=$build_type not found in $PWD"
            echo "# Maybe you forgot to configure first?"
            echo "# If so, I will do it for you ;)"
            abbr_cmake_configure $build_type
            return 0
        end
    else
        set -l builddirs (__cmake::find_build_dirs)
        # Only fuzzy find if no existing build dir found
        switch (count $builddirs)
            case 0
                echo "# No cmake build directory has been configured yet."
                return 0
            case 1
                set -f builddir $builddirs[1]
            case "*" # 2 or more
                if command --query fzf
                    # TODO: improve presentation of menu
                    set -l fzf_opts \
                        --height=30% \
                        --cycle \
                        --header-first \
                        --header="Select which cmake build directory to use"
                    # FIXME: handle case where no dir is selected i.e. user presses <esc>
                    printf "%s\n" $builddirs | command fzf $fzf_opts | read dir
                    commandline --function repaint
                    set -f builddir $dir
                else
                    echo "# $(count $builddirs) configured build directories were found:"
                    printf "# - %s\n" $builddirs
                    echo "# Selecting the first one found as `fzf` was not found in \$PATH"
                    set -f builddir $builddirs[1]
                end
        end
    end

    __cmake::abbr::set_number_of_jobs
    echo "cmake --build '$builddir%' --parallel \$jobs --target all"
end

function abbr_cmake_build
    abbr_cmake_build_inner --configure
    return 0
end


function abbr_cmake_configure_and_build -a build_type
    abbr_cmake_configure $build_type
    # printf "and " # Only run the build if configure succeeded
    abbr_cmake_build_inner $build_type
end

function abbr_cmake_configure_debug_and_build
    abbr_cmake_configure_and_build Debug
    return 0
end

function abbr_cmake_configure_release_and_build
    abbr_cmake_configure_and_build Release
    return 0
end

# cmake configure
abbr -a cmc -f __cmake::abbr::configure_debug --set-cursor
abbr -a cmcd -f __cmake::abbr::configure_debug --set-cursor
abbr -a cmcr -f abbr_cmake_configure_release --set-cursor
abbr -a cmcw -f abbr_cmake_configure_rel_with_deb_info --set-cursor
abbr -a cmcm -f abbr_cmake_configure_min_size_rel --set-cursor
# cmake build
abbr -a cmb -f abbr_cmake_build --set-cursor
# cmake configure and build
abbr -a cmcb -f abbr_cmake_configure_debug_and_build --set-cursor
abbr -a cmcdb -f abbr_cmake_configure_debug_and_build --set-cursor
abbr -a cmcrb -f abbr_cmake_configure_release_and_build --set-cursor

# ctest
# abbr -a ct ctest --progress "-j(nproc)" --output-on-failure --test-dir build

# cpack

# functions in ./functions/*.fish
# abbr -a cmev cmake-explain-variables
# abbr -a cmep cmake-explain-properties

function __cmake::abbr::cmake-init
    if command --query gcc
        set -f gcc_available 1
    end
    if command --query clang
        set -f clang_available 1
    end
    if test -f CMakeLists.txt
        echo "# ./CMakelists.txt already exists in $PWD"
    end
    if set --query gcc_available; and set --query clang_available
        echo "# Both gcc and clang are available in \$PATH, use --gcc or --clang to select which compiler to use"
        echo cmake-init
    else if set --query gcc_available
        echo "cmake-init --gcc"
    else if set --query clang_available
        echo "cmake-init --clang"
    else
        echo "# gcc and clang are not available in \$PATH, you need one of them to compile C/C++ code!"
        echo cmake-init
    end
end

abbr -a cmi -f __cmake::abbr::cmake-init

function __cmake::abbr::cmake_run
    if not test -f CMakeLists.txt
        echo "# ./CMakelists.txt not found in $PWD"
        return 1
    end
    # Look for existing builds directories, and see if they have any executable files
    # use fzf to select which one to run
    # __cmake_set_number_of_jobs
    # echo "cmake --build . --target all --parallel $(nproc)"

    # TODO: refactor into function
    set -l builddirs (__cmake::find_build_dirs)
    # Only fuzzy find if no existing build dir found
    switch (count $builddirs)
        case 0
            echo "# No cmake build directory has been configured yet."
            return 0
        case 1
            set -f builddir $builddirs[1]
        case "*" # 2 or more
            if command --query fzf
                # TODO: improve presentation of menu
                set -l fzf_opts \
                    --height=30% \
                    --cycle \
                    --header-first \
                    --header="Select which cmake build directory to use"
                # FIXME: handle case where no dir is selected i.e. user presses <esc>
                printf "%s\n" $builddirs | command fzf $fzf_opts | read dir
                commandline --function repaint
                set -f builddir $dir
            else
                echo "# $(count $builddirs) configured build directories were found:"
                printf "# - %s\n" $builddirs
                echo "# Selecting the first one found as `fzf` was not found in \$PATH"
                set -f builddir $builddirs[1]
            end
    end

    set -l executables (
        for f in $builddir/*
            test -d $f; and continue
            test -x $f; and path basename $f
        end
    )

    # TODO: what if there is not 1 executable?

    echo "cmake --build $builddir --target $executables[1]"
    echo "and ./$builddir/$executables[1]"

    # cmake --build 'cmake-build-release' --target gbpplanner; and ./cmake-build-release/gbpplanner
end


abbr -a cmr -f __cmake::abbr::cmake_run


function __cmake::abbr::cmake_target
    # TODO: finish
    if not test -f CMakeLists.txt
        echo "# ./CMakelists.txt not found in $PWD"
        return 1
    end
    set -l builddir cmake-build-release
    set -l targets
    command cmake --build $builddir --target help \
        | string match --regex '^\S+: \S+' \
        | while read -d ': ' target type
        set -a targets $target
    end

    set -l selected_target (printf '%s\n' $targets | command fzf)

    printf 'cmake --build %s --target %s\n' $builddir $selected_target
end

abbr -a cmt -f __cmake::abbr::cmake_target

function abbr_cmake_watch
    if not command --query watchexec
        echo "# watchexec not installed"
        return
    end

    # TODO: handle different configs, and more extensions
    __cmake::abbr::set_number_of_jobs
    echo watchexec --timings --clear --restart -e cpp,cxx,h,hpp -- cmake --build cmake-build-release --parallel $jobs --target all
end

abbr -a cmw -f abbr_cmake_watch --set-cursor
