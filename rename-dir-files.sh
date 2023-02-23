#!/bin/sh

# Rename Directories (replace empty spaces with a minus '-')
# AND/OR
# Rename Files       (replace empty spaces with a minus '-' [+MDATETIME prefix] )
#
# Usage: rename-dir-files.sh ABSOLUTE_PATH [EXECMODE] [TYPE]
# EXECMODE=[TEST,REAL,DATETIME]  Default=TEST
# TYPE=[D,F,DF]   Default=D
#
# A backup (.tar) of the directory is created before proceeding
# The program doesn't overwrite an existing directory/file


readonly FILE_DATETIME_PREFIX='+%Y%m%d-%H%M%S'

readonly BRE_SED_CLEAN_PATH='s;/\{1,\};/;g'
readonly BRE_SED_RMV_TRAILING_SLASH='s;/\{1,\}$;;'
readonly BRE_FILE_DATETIME_PREFIX_PATTERN='[0-9]\{8\}-[0-9]\{6\}-'
readonly BRE_SED_REPLACE_SPACE_WITH_DASH='s; ;-;g'
readonly BRE_SED_RMV_TRAILING_SPACES='s; \{1,\}$;;'
#readonly BRE_SED_RMV_FIREFOX_SCREENSHOT_PREFIX='s;Screenshot [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} at [0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\} ;;'

readonly RC_FAILED=1

[ $# -eq 0 ] && {
    printf %s\\n "ERROR - Need a directory as argument"
    return $RC_FAILED
}

dir="$( printf %s "$1/" | sed -e "$BRE_SED_CLEAN_PATH" )"
#printf %s\\n "$dir"

[ ! -d "$dir" -o "$dir" = '/' ] && {
    printf %s\\n "ERROR - Not a valid directory: $dir"
    return $RC_FAILED
}

printf %s "$dir" | grep '^/' > /dev/null 2>&1 || {
    printf %s\\n "ERROR - Use an absolute path for $dir"
    return $RC_FAILED
}

exec_mode="${2:-TEST}"   #TEST (Default), REAL (replace empty spaces with a minus '-'), DATETIME (add mdatetime prefix to filename)
type="${3:-D}"           #D=Rename Directories only, F=Rename Files only, FD,DF=Rename Files AND Directories

case "$exec_mode" in
    REAL|DATETIME|TEST);;
    *) exec_mode='TEST'
esac

printf %s "$exec_mode MODE: "

case "$type" in
    'F') printf %s\\n 'Renaming Files ONLY';;

    'DF'|'FD') printf %s\\n 'Renaming Files AND Directories';;

    *|'D') type=D
           printf %s\\n 'Renaming Directories ONLY'
     ;;
esac


case "$exec_mode" in
    REAL|DATETIME)
        # First rename working directory (if necessary)
        newdirname="$( printf %s "$dir" | sed -e "$BRE_SED_REPLACE_SPACE_WITH_DASH" | tr -s '-' )"
        #printf %s\\n "$newdirname"

        [ "$dir" != "$newdirname" ] && {
            mv "$dir" "$newdirname" || { printf %s\\n "ERROR: Cannot rename $dir to $newdirname" ; exit $RC_FAILED; }
            printf \\n%s\\n%s\\n "Renamed $dir" "To $newdirname" 
            dir="$newdirname"
        }

        # Then make a backup of the directory before proceeding with directories/files renaming
        readonly tar_backup_ext=".bak_$( date '+%Y%m%d%H%M%S' ).tar"

        tar_backup_fpath="${dir}$( basename "$dir" )${tar_backup_ext}"
        #printf %s\\n "$tar_backup_fpath"

        printf \\n%s\\n%s\\n "### Creating Backup" "$tar_backup_fpath"
        tar -cPf "$tar_backup_fpath" "$dir" > /dev/null 2>&1 || { printf %s\\n "ERROR: Cannot create backup $tar_backup_fpath from $dir"; exit $RC_FAILED; }
        printf %s\\n\\n "[OK]"
    ;;

    TEST) printf \\n;;
esac


# Rename Directories (replace empty spaces with a minus '-')
case "$type" in
    D|'DF'|'FD')
        printf %s\\n "### Renaming Directories (no empty spaces)"
        find "$dir" -type d | sed -e "$BRE_SED_CLEAN_PATH" -e "$BRE_SED_RMV_TRAILING_SLASH" | sort -r | {

            d_count=0
            d_count_renamed=0
            d_count_error=0
            while read -r d_path
            do
                d_parent="$( dirname "$d_path" )"
                d_newname="$( basename "$d_path" | sed -e "$BRE_SED_REPLACE_SPACE_WITH_DASH" | tr -s '-' )"
                d_newpath="${d_parent}/${d_newname}" 

                [ "$d_path" != "$d_newpath" ] && {

                    d_count=$((d_count +1))
                    printf %s\\n "d#$d_count"

                    printf %s\\n "SRC: $d_path"

                    case $exec_mode in
                        REAL|DATETIME)
                            printf %s\\n "DST: $d_newpath"

                            # Alert and skip current renaming operation if dst dir already exists
                            [ -e "$d_newpath" ] && {
                                printf %s\\n "WARNING: DST directory already exists"
                                d_count_error=$((d_count_error +1))
                                printf %s\\n\\n "[KO]"
                            } || {
                                cmd="mv '$d_path' '$d_newpath'"
                                #printf %s\\n\\n "$cmd"

                                eval "$cmd" && { printf %s\\n\\n "[OK]"; d_count_renamed=$((d_count_renamed +1)); } \
                                            || { printf %s\\n\\n "[KO]"; d_count_error=$((d_count_error +1)); }
                            }
                        ;;

                        TEST|*)
                            printf %s\\n\\n "DST: $d_newpath"
                        ;;
                    esac
                }
            done

            printf %s\\n "Renamed Directories: ${d_count_renamed}/${d_count}"
            printf %s\\n "Error Directories  : ${d_count_error}/${d_count}"
        }
    ;;
esac


case "$type" in
    'F'|'DF'|'FD');;
    *|'D') exit;;
esac

error_files_list=''
rename_files(){
    local f_src="$1"
    local f_dst="$2"

    # Do NOT overwrite an existing file
    # Alert and skip current renaming operation if dst file already exists
    [ -e "$f_dst" ] && {
        error_files_list="$error_files_list
$f_src"
        printf %s\\n "WARNING: DST file already exists"
        f_count_error=$((f_count_error +1))
        printf %s\\n "[KO]"
    } || {
        cmd="mv -n '$f_src' '$f_dst'"
        #printf %s\\n\\n "$cmd"

        eval "$cmd" && { printf %s\\n "[OK]"; f_count_renamed=$((f_count_renamed +1)); } \
                    || { printf %s\\n "[KO]"; f_count_error=$((f_count_error +1)); }
    }
}


[ "$exec_mode" = 'TEST' ] && printf \\n%s "IMPORTANT: REAL or DATETIME mode renames directories first, the following paths may not be the same as it should actually be"


# Rename Files
printf \\n\\n%s\\n "### Renaming Files"
find "$dir" -type f | {

    f_count=0
    f_count_renamed=0
    f_count_error=0
    f_count_skipped=0
    while read -r f_path
    do
        f_count=$((f_count +1))
        printf %s\\n "f#$f_count"

        f_datetime="$( LC_ALL=C ls -l --time-style='+%Y%m%d-%H%M%S' "$f_path" | cut -d' ' -f 6 )"
        #printf %s\\n "$f_datetime"

        f_path="$( LC_ALL=C ls -l --time-style='+%Y%m%d-%H%M%S' "$f_path" | cut -d' ' -f 7- | sed -e "$BRE_SED_RMV_TRAILING_SPACES" )"
        printf %s\\n "SRC: $f_path"

        f_dir="$( dirname "$f_path" )"
        #printf %s\\n "$f_dir"

        # Replace empty spaces with a minus '-' within filename
        #f_newname="$( basename "$f_path" | sed -e "$BRE_SED_RMV_FIREFOX_SCREENSHOT_PREFIX" -e "$BRE_SED_REPLACE_SPACE_WITH_DASH" | tr -s '-' )"
        f_newname="$( basename "$f_path" | sed -e "$BRE_SED_REPLACE_SPACE_WITH_DASH" | tr -s '-' )"
        #printf %s\\n "$f_newname"

        case $exec_mode in
            REAL) # Renaming Files (no empty spaces)
                rename_to="${f_dir}/${f_newname}"
                printf %s\\n "DST: $rename_to"

                [ "$f_path" != "$rename_to" ] && rename_files "$f_path" "$rename_to" \
                                              || { printf %s\\n "[SKIPPED]"; f_count_skipped=$((f_count_skipped +1)); }
                printf %s\\n
            ;;

            DATETIME)
                printf %s "$f_newname" | grep "^$BRE_FILE_DATETIME_PREFIX_PATTERN" > /dev/null && {
                    printf %s\\n\\n "File Not Renamed (FILE_DATETIME_PREFIX Detected: YYYYMMDD-hhmmss-)" 
                } || {
                    rename_to="${f_dir}/${f_datetime}-${f_newname}"
                    printf %s\\n "DST: $rename_to"

                    [ "$f_path" != "$rename_to" ] && rename_files "$f_path" "$rename_to" \
                                                  || { printf %s\\n "[SKIPPED]"; f_count_skipped=$((f_count_skipped +1)); }
                    printf %s\\n
                }
            ;;

            TEST|*)
                rename_to="${f_dir}/${f_newname}"
                printf %s\\n\\n "DST: $rename_to"
            ;;
        esac
    done

    printf %s\\n "Renamed Files    : ${f_count_renamed}/${f_count}"
    printf %s\\n "Error Files      : ${f_count_error}/${f_count}"
    printf %s\\n "Skipped Files    : ${f_count_skipped}/${f_count}"

    [ $f_count_error -gt 0 ] && {
        printf \\n%s\\n "Error Files List :" 
        printf %s\\n "$error_files_list" | sed /^$/d
    }
}
