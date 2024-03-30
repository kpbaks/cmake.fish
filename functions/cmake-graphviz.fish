function cmake-graphviz -d ''
    set -l options h/help o-open f/format=+ v/verbose
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

    if not command --query cmake
        printf '%serror:%s cmake not found in $PATH\n' $red $reset
        return 1
    end

    if not command --query dot
        printf '%serror:%s dot not found in $PATH\n' $red $reset
        return 1
    end

    if not test -f CMakeLists.txt
        printf '%serror:%s %s/CMakeLists.txt does not exist\n' $red $reset $PWD
        return 2
    end

    # TODO: change to cmake-build-*
    set -l cmake_graphviz_output_dir cmake-graphviz
    if test -d $cmake_graphviz_output_dir
    end

    if test -f .gitignore
        # add output dir to .gitignore if not already ignored
        if not string match --quiet $cmake_graphviz_output_dir <.gitignore
            echo $cmake_graphviz_output_dir >>.gitignore
            printf '%sinfo:%s appened "%s" to .gitignore\n' $green $reset $cmake_graphviz_output_dir
        end
    end

    # -DGRAPHVIZ_EXECUTABLES=TRUE
    # -DGRAPHVIZ_STATIC_LIBS=TRUE
    # -DGRAPHVIZ_SHARED_LIBS=TRUE
    # -DGRAPHVIZ_EXTERNAL_LIBS=TRUE
    # -DGRAPHVIZ_GENERATE_PER_TARGET=FALSE
    # -DGRAPHVIZ_GENERATE_DEPENDERS=FALSE

    # -DGRAPHVIZ_GRAPH_HEADER "node [ fontsize = "14" ];"

    # CMakeGraphVizOptions.cmake
    # # Because I don't like cmake files flooding my root directory
    # file(COPY cmake/CMakeGraphVizOptions.cmake DESTINATION ${CMAKE_BINARY_DIR})


    if not test -d cmake
        command mkdir cmake
    end

    # set -l cmake_graphviz_args \
    #     -DGRAPHVIZ_EXECUTABLES='TRUE' \
    #     -DGRAPHVIZ_GRAPH_HEADER='"node [ fontsize = \"14\" ];"'
    set -l cmake_graphviz_options_file_path cmake/CMakeGraphVizOptions.cmake
    if not test -f $cmake_graphviz_options_file_path
        echo " # set by `$(status function) $argv`
set(GRAPHVIZ_EXECUTABLES FALSE)

    " >>$cmake_graphviz_options_file_path
    end

    begin
        set -l needle 'file(COPY cmake/CMakeGraphVizOptions.cmake DESTINATION ${CMAKE_BINARY_DIR})'
        if not string match --quiet $needle <CMakeLists.txt
            echo $needle >>CMakeLists.txt
        end
    end

    set -l output_formats png svg pdf
    for format in $_flag_format
        set -a output_formats $format
    end

    mkdir -p $cmake_graphviz_output_dir
    set -l project_name (path basename $PWD)
    set -l file_path $cmake_graphviz_output_dir/$project_name
    set -l dot_file_path $file_path.dot

    set -l builddir cmake-build-release

    set -l cmake_expr command cmake -B $builddir --graphviz $dot_file_path
    if set --query _flag_verbose
        echo $cmake_expr | fish_indent --ansi
    end

    if not eval $cmake_expr
        return 1
    end

    # command cmake --graphviz $dot_file_path .
    for format in $output_formats
        set -l output_file_path $file_path.$format
        set -l expr command dot -T png $dot_file_path -o $output_file_path

        printf '%sinfo:%s running %s%s\n' $green $reset (printf (echo $expr |fish_indent --ansi)) $reset
        if not eval $expr
            printf '%serror:%s failed to '
            return 1
        end
    end
    # and command dot -T png $dot_file_path -o $png_file_path


    # if set --query _flag_open
    #     open $png_file_path
    # end

    return 0
end
