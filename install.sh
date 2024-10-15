#!/usr/bin/env bash
# Install the product into the system
#
# Copyright 2024 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: WTFPL
#
# shellcheck disable=SC2034

init(){
    local flag_uninstall=false
    local install_directory_xdg

    if ! process_commandline_arguments \
            flag_uninstall \
            "${script_args[@]}"; then
        printf \
            'Error: %s: Invalid command-line parameters.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        print_help "${script_basecommand}"
        exit 1
    fi

    if ! determine_install_directory \
            install_directory_xdg; then
        printf -- \
            'Error: Unable to determine install directory, installer cannot continue.\n' \
            1>&2
        exit 1
    else
        printf \
            'Will be installed to: %s\n' \
            "${install_directory_xdg}"
        printf '\n'
    fi

    remove_old_installation\
        "${install_directory_xdg}"
    if test "${flag_uninstall}" = true; then
        printf 'Software uninstalled successfully.\n'
        exit 0
    fi

    printf 'Installing template files...\n'
    mkdir \
        --parents \
        "${XDG_TEMPLATES_DIR}"
    install \
        --verbose \
        --mode=u=rw,go=r \
        "${script_dir}/.editorconfig" \
        "${install_directory_xdg}/EditorConfig Template.editorconfig"
    printf '\n' # Seperate output from different operations

    while true; do
        printf 'Do you want to install files to enable KDE support(y/N)?'
        read -r answer

        if test -z "${answer}"; then
            break
        else
            # lowercasewize
            answer="$(
                printf -- \
                    '%s' \
                    "${answer}" \
                    | tr '[:upper:]' '[:lower:]'
            )"

            if test "${answer}" != n && test "${answer}" != y; then
                # wrong format, re-ask
                continue
            elif test "${answer}" == n; then
                break
            else
                printf 'Configuring templates for KDE...\n'
                mkdir \
                    --parents \
                    "${HOME}/.local/share/templates"
                install \
                    --verbose \
                    --mode=u=rw,go=r \
                    "${script_dir}/.editorconfig" \
                    "${HOME}/.local/share/templates/EditorConfig Template.editorconfig"
                install \
                    --verbose \
                    --mode=u=rw,go=r \
                    "${script_dir}/Template Setup for KDE/"*.desktop \
                    "${HOME}/.local/share/templates"
                break
            fi
        fi
    done

    printf \
        'Info: Operation completed without errors.\n'

    exit 0
}

print_help(){
    local script_basecommand="${1}"; shift

    printf '# %s #\n' "${script_basecommand}"
    printf 'This program installs the templates into the system to make it accessible.\n\n'

    printf '## Command-line Options ##\n'
    printf '### --help / -h ###\n'
    printf 'Print this message\n\n'

    printf '### --uninstall / -u ###\n'
    printf 'Instead of installing, attempt to remove previously installed product\n\n'

    printf '### --debug / -d ###\n'
    printf 'Enable debug mode\n\n'

    return 0
}

process_commandline_arguments() {
    local -n flag_uninstall_ref="${1}"; shift

    if test "${#script_args[@]}" -eq 0; then
        return 0
    fi

    # modifyable parameters for parsing by consuming
    local -a parameters=("${@}"); set --

    # Normally we won't want debug traces to appear during parameter parsing, so we  add this flag and defer it activation till returning
    local enable_debug=false

    while true; do
        if test "${#parameters[@]}" -eq 0; then
            break
        else
            case "${parameters[0]}" in
                --help\
                |-h)
                    print_help;
                    exit 0
                    ;;
                --uninstall\
                |-u)
                    flag_uninstall_ref=true
                    ;;
                --debug\
                |-d)
                    enable_debug=true
                    ;;
                *)
                    printf 'ERROR: Unknown command-line argument "%s"\n' "${parameters[0]}" >&2
                    return 1
                    ;;
            esac
            # shift array by 1 = unset 1st then repack
            unset 'parameters[0]'
            if test "${#parameters[@]}" -ne 0; then
                parameters=("${parameters[@]}")
            fi
        fi
    done

    if test "${enable_debug}" = true; then
        set -o xtrace
    fi
    return 0
}

determine_install_directory(){
    local -n install_directory_xdg_ref="${1}"; shift

    # For $XDG_TEMPLATES_DIR
    if test -f "${HOME}/.config/user-dirs.dirs";then
        # external file, disable check
        # shellcheck source=/dev/null
        source "${HOME}/.config/user-dirs.dirs"

        if [ -v XDG_TEMPLATES_DIR ]; then
            install_directory_xdg_ref="${XDG_TEMPLATES_DIR}"
            return 0
        fi
    fi

    printf -- \
        "%s: Warning: Installer can't locate user-dirs configuration, will fallback to unlocalized directories\\n" \
        "${FUNCNAME[0]}" \
        1>&2

    if test ! -d "${HOME}/Templates"; then
        return 1
    else
        install_directory_xdg_ref="${HOME}/Templates"
    fi

}

## Attempt to remove old installation files
remove_old_installation(){
    local install_directory_xdg="${1}"; shift 1

    printf 'Removing previously installed templates(if available)...\n'
    rm \
        --verbose \
        --force \
        "${install_directory_xdg}/EditorConfig Template.editorconfig"
    rm \
        --verbose \
        --force \
        "${HOME}/.local/share/templates/EditorConfig Template.editorconfig" \
        "${HOME}/.local/share/templates/EditorConfig Template.desktop"
    printf 'Finished.\n'

    printf '\n' # Additional blank line for separating output
    return 0
}

printf \
    'Info: Configuring the defensive interpreter behaviors...\n'
set_opts=(
    # Terminate script execution when an unhandled error occurs
    -o errexit
    -o errtrace

    # Terminate script execution when an unset parameter variable is
    # referenced
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to configure the defensive interpreter behaviors.\n' \
        1>&2
    exit 1
fi

runtime_dependency_check_failed=false
required_commands=(
    basename
    dirname
    install
    realpath
    rm
)
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" &>/dev/null; then
        runtime_dependency_check_failed=true

        case "${command}" in
            basename\
            |dirname\
            |install\
            |realpath\
            |rm)
                required_software='GNU Coreutils'
                ;;
            *)
                required_software="${command}"
                ;;
        esac

        printf \
            'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n' \
            "${required_software}" \
            1>&2
    fi
done

if test "${runtime_dependency_check_failed}" == true; then
    printf \
        'Error: Runtime dependency checking failed, the progrom cannot continue.\n' \
        1>&2
    exit 1
fi


printf \
    'Info: Configuring the convenience variables...\n'
if test -v BASH_SOURCE; then
    # Convenience variables may not need to be referenced
    # shellcheck disable=SC2034
    {
        printf \
            'Info: Determining the absolute path of the program...\n'
        if ! script="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
            )"; then
            printf \
                'Error: Unable to determine the absolute path of the program.\n' \
                1>&2
            exit 1
        fi
        script_dir="${script%/*}"
        script_filename="${script##*/}"
        script_name="${script_filename%%.*}"
    }
fi
# Convenience variables may not need to be referenced
# shellcheck disable=SC2034
{
    script_basecommand="${0}"
    script_args=("${@}")
}

printf \
    'Info: Setting the ERR trap...\n'
# trap commands are not called by default
# shellcheck disable=SC2317
trap_err(){
    printf \
        'Error: The program prematurely terminated due to an unhandled error.\n' \
        1>&2
    exit 99
}
if ! trap trap_err ERR; then
    printf \
        'Error: Unable to set the ERR trap.\n' \
        1>&2
    exit 1
fi

init "${@}"
