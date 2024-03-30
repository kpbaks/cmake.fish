function cmake-targets -d '' -a builddir
    set -l options h/help j/json
    if not argparse $options -- $argv
        printf '\n'
        eval (status function) --help
        return 2
    end

    set -l reset (set_color normal)
    set -l bold (set_color --bold)
    set -l italics (set_color --italics)
    set -l red (set_color red)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l blue (set_color blue)
    set -l cyan (set_color cyan)
    set -l magenta (set_color magenta)

    if set --query _flag_help
        # TODO: write --help
        set -l option_color (set_color $fish_color_option)
        set -l reset (set_color normal)
        set -l bold (set_color --bold)
        set -l section_header_color (set_color yellow)

        printf '%sdescription%s\n' $bold $reset
        printf '\n'
        printf '%sUSAGE:%s %s%s%s [OPTIONS]\n' $section_header_color $reset (set_color $fish_color_command) (status function) $reset
        printf '\n'
        printf '%sOPTIONS:%s\n' $section_header_color $reset
        printf '%s\t%s-h%s, %s--help%s Show this help message and return\n'
        # printf '%sEXAMPLES:%s\n' $section_header_color $reset
        # printf '\t%s%s\n' (printf (echo "$(status function)" | fish_indent --ansi)) $reset
        return 0
    end >&2

    # TODO: find build directory



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
                    --height=~10% \
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

    # set -l builddir cmake-build-release

    if set --query _flag_json
        set -l phony_targets
        set -l help_targets
        set -l clean_targets
        set -l rerun_cmake_targets
        set -l custom_command_targets

        # TODO: parse output more robustly incase there are some work cmake has to do i.e. configure
        command cmake --build $builddir --target help \
            | command tail -n +2 \
            | while read -d ': ' target type
            switch $type
                case phony
                    set -a phony_targets $target
                case HELP
                    set -a help_targets $target
                case CLEAN
                    set -a clean_targets $target
                case RERUN_CMAKE
                    set -a rerun_cmake_targets $target
                case CUSTOM_COMMAND
                    set -a custom_command_targets $target
            end
        end

        # TODO: simplify with a for loop

        printf '{\n'
        printf '  "phony": [\n'
        switch (count $phony_targets)
            case 0
            case 1
                printf '    "%s"\n' $phony_targets[-1]
            case '*'
                printf '    "%s",\n' $phony_targets[..-2]
                printf '    "%s"\n' $phony_targets[-1]
        end
        printf '  ],\n'
        printf '  "help": [\n'
        switch (count $help_targets)
            case 0
            case 1
                printf '    "%s"\n' $help_targets[-1]
            case '*'
                printf '    "%s",\n' $help_targets[..-2]
                printf '    "%s"\n' $help_targets[-1]
        end
        printf '  ],\n'
        printf '  "clean": [\n'

        switch (count $clean_targets)
            case 0
            case 1
                printf '    "%s"\n' $clean_targets[-1]
            case '*'
                printf '    "%s",\n' $clean_targets[..-2]
                printf '    "%s"\n' $clean_targets[-1]
        end
        printf '  ],\n'
        printf '  "rerun_cmake": [\n'

        switch (count $rerun_cmake_targets)
            case 0
            case 1
                printf '    "%s"\n' $rerun_cmake_targets[-1]
            case '*'
                printf '    "%s",\n' $rerun_cmake_targets[..-2]
                printf '    "%s"\n' $rerun_cmake_targets[-1]
        end
        printf '  ],\n'
        printf '  "custom_command": [\n'

        switch (count $custom_command_targets)
            case 0
            case 1
                printf '    "%s"\n' $custom_command_targets[-1]
            case '*'
                printf '    "%s",\n' $custom_command_targets[..-2]
                printf '    "%s"\n' $custom_command_targets[-1]
        end
        printf '  ]\n'
        printf '}\n'

        return 0
    end

    set -l counter 0
    # TODO: parse output more robustly incase there are some work cmake has to do i.e. configure
    command cmake --build $builddir --target help \
        | command tail -n +2 \
        | while read -d ': ' target type
        set -l type_color $reset
        switch $type
            case phony
                set type_color $green
            case HELP
                set type_color $magenta
            case CLEAN
                set type_color $red
            case RERUN_CMAKE
                set type_color $yellow
            case CUSTOM_COMMAND
                set type_color $cyan
        end

        printf '%s%15s%s | %s%s%s\n' $type_color $type $reset $bold $target $reset
        set counter (math $counter + 1)
    end

    printf '\n%s%2d%s targets found\n' $cyan $counter $reset

    return 0
end
