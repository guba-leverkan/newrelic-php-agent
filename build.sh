#!/bin/bash
# shellcheck disable=SC2317

function build_deb_package {
    # $1 - Packaging folder
    # $2 - Package name/subfolder
    cd "${1}" || exit 1
    
    # grab name from control file
    pkgName=$( grep '^Package:.*$' "${1}"/"${source}"/DEBIAN/control | cut -d' ' -f2 )
    # grab version from control file, tr ~ to -
    pkgVer=$( grep '^Version:.*$' "${1}"/"${source}"/DEBIAN/control | cut -d' ' -f2 | tr '~' '-' )
    # grab arch from control file
    pkgArch=$( grep '^Arch:.*$' "${1}"/"${source}"/DEBIAN/control | cut -d' ' -f2 ) ### FIX
    # ${name}_${version}_${arch}.deb
    # compose package name
    pkgFile="${pkgName}_${pkgVer}_${pkgArch}.deb"
    
    # do a dpkg-deb to build the package
    dpkg-deb -b "${1}"/"${source}" ./"${pkgFile}"
    
    return 0
}

function calc_new_version {
    # 1 - old version
    mainVer=$( echo "${1}" | rev | cut -d'.' -f2- | rev )
    minorVer=$( echo "${1}" | rev | cut -d'.' -f1 | rev | cut -d'-' -f1 | cut -d'~' -f1 )
    printf "%s.%s~gubagoo" "${mainVer}" "${minorVer}"
}

function capture_lib_output {
    # $1 - Packaging folder
    # $2 - PHP version as major.minor
    
    local date_folder
    
    date_folder=$(convert_php "${2}")
    
    cp --preserve=all /usr/lib/php/"${date_folder}"/newrelic.so "${1}"/newrelic-php5/usr/lib/newrelic-php5/agent/x64/newrelic-"${date_folder}".so
    
    return 0
}

function capture_nonlib_output {
    # 1 - Build folder
    # 2 - Packaging folder
    
    cp --preserve=all "${1}"/bin/daemon           "${2}"/newrelic-daemon/usr/bin/newrelic-daemon
    cp --preserve=all "${1}"/bin/newrelic-install "${2}"/newrelic-php5-common/usr/bin/newrelic-install
    cp --preserve=all "${1}"/bin/newrelic-iutil   "${2}"/newrelic-php5/usr/lib/newrelic-php5/scripts/newrelic-iutil.x64
    
    return 0
}

function clean_package_folder {
    # $1 build folder
    # $2 package
    
    target="${1}"/"${2}"
    # Is /home or /tmp at base of ${target}?
    # If not, we aren't budging
}

function clean_up_everything {
    apt remove newrelic-* php*.*-dev
    
    add-apt-repository --remove ppa:ondrej/php
    
    rm /etc/apt/sources.list.d/newrelic.list
    
    rm /var/cache/apt/archives/newrelic*
    
    return 0
}

function clone_git_repo {
    # $1 - Build folder
    printf "\n"
    printf "Cloning Git repo...\n"
    printf -- '--------------------------------'"\n"
    cd "${1}" || exit 1
    git clone https://github.com/guba-leverkan/newrelic-php-agent.git
    return 0
}

function convert_php {
    # $1 - PHP version as major.minor
    
    case ${1} in
        (5.6)   printf '20131212' ;;
        (7.0)   printf '20151012' ;;
        (7.1)   printf '20160303' ;;
        (7.2)   printf '20170718' ;;
        (7.3)   printf '20180731' ;;
        (7.4)   printf '20190902' ;;
        (8.0)   printf '20200930' ;;
        (8.1)   printf '20210902' ;;
        (*)     return 1          ;;
    esac
    
    return 0
}

function generate_hashline {
    # 1 - file to hash
    echo "${1}" | grep -q DEBIAN && return
    hash=$( md5sum "${1}" )
    # shellcheck disable=SC2086
    printf "%s  %s\n" ${hash/.\/}
}

function get_build_user {
    # $1 - build folder
    # shellcheck disable=SC2010
    printf "%s" "$(ls -l "${1}"/. | grep -v '^total' | cut -d' ' -f3)"
    return 0
}

function get_packaging_user {
    # $1 - packaging folder
    # shellcheck disable=SC2010
    printf "%s" "$(ls -l "${1}"/. | grep -v '^total' | cut -d' ' -f3)"
    return 0
}

function install_build_deps {
    printf "\n"
    printf "Installing build dependencies...\n"
    printf -- '--------------------------------'"\n"
    
    apt install -y build-essential doxygen libargon2-dev libsodium-dev libxml2-dev valgrind zlib1g-dev
    
    return 0
}

function install_newrelic_repo {
    # $1 - packaging folder
    
    printf "\n"
    printf "Installing New Relic Repo...\n"
    printf -- '--------------------------------'"\n"
    
    echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' > /etc/apt/sources.list.d/newrelic.list
    
    wget -O- 'https://download.newrelic.com/548C16BF.gpg' | apt-key add -
    
    apt update
    
    return 0
}

function install_php_repo {
    printf "\n"
    printf "Installing PHP repository...\n"
    printf -- '--------------------------------'"\n"
    add-apt-repository --yes ppa:ondrej/php
    apt update
    return 0
}

function install_php_version {
    # $1 - PHP version number
    apt install -y 'php'"${1}"'-dev'
    # return $?
}

function prepare_source_package {
    # $1 package name
    # $2 packaging folder
    
    pkg_file=$( apt -qq list "${1}" 2>/dev/null | awk -F ' ' '{ pkg=substr($1,0,index($1,"/")-1) ; gsub(/:/,"%3a",$2); print( pkg"_"$2"_"$3".deb" ) }' )
    
    cd '/tmp/' || exit 1
    apt download "${1}"
    
    mkdir -p "${2}"'/'"${1}"
    
    dpkg-deb -R "${pkg_file}" "${2}"'/'"${1}"
    
    rm '/tmp/'"${pkg_file}"
    
    return 0
}

function print_section_header {
    # $1   DIV character
    # $2   DIV width
    # $3   message
    # Bash doesn't support variables in brace range expansions
    # printf -v divider -- "${1}"'%.0s' {1.."${2}"}
    printf -v divider -- "${1}"'%.0s' {1..32}
    
    printf -- "\n"
    printf -- '%s'"\n" "${3}"
    printf -- '%s'"\n" "${divider}"
    return 0
}

function regenerate_hashfile {
    cd "${1}"/"${2}" || exit 1
    
    find . -type f | while read -r file; do generate_hashline "${file}"; done | tee ./DEBIAN/md5sums
    
    return 0
}

function restore_php_version {
    update-alternatives --auto libphp5
    update-alternatives --auto libphp7
    update-alternatives --auto libphp8
    update-alternatives --auto phar
    update-alternatives --auto phar.phar
    update-alternatives --auto php
    update-alternatives --auto php-config
    update-alternatives --auto phpize
    return 0
}

function set_php_version {
    # $1 - PHP version as major.minor
    php_version="${1}"
    
    php_major=$( printf '%s' "${php_version}" | cut -d'.' -f1 )
    
    update_alternatives --set libphp"${php_major}" /usr/lib/libphp"${php_version}"     || return 1
    update_alternatives --set phar                 /usr/bin/phar"${php_version}"       || return 2
    update_alternatives --set phar.phar            /usr/bin/phar.phar"${php_version}"  || return 3
    update_alternatives --set php                  /usr/bin/php"${php_version}"        || return 4
    update_alternatives --set php-config           /usr/bin/php-config"${php_version}" || return 5
    update_alternatives --set phpize               /usr/bin/phpize"${php_version}"     || return 6
    
    return 0
}

function update_control_file {
    # 1 - Packaging folder
    # 2 - Subfolder
    packagePath="${1}"'/'"${2}"
    
    cd "${packagePath}" || exit 1
    
    controlFile="${packagePath}"'/DEBIAN/control'
    
    # Capture package name
    packageName=$( grep '^Package:.*$' "${controlFile}" | cut -d' ' -f2 )
    
    # Read Version field and capture version
    oldVersion=$( grep '^Version: ' "${controlFile}" | cut -d' ' -f2 )
    
    newVersion=$( calc_new_version "${oldVersion}" )
    
    # Use captured version to do a sed replace
    sed -i 's/'"${oldVersion}"'/'"${newVersion}"'/' "${controlFile}"
    
      totalSize=$( du --summarize "${packagePath}"/.       | cut -f1 )
     debianSize=$( du --summarize "${packagePath}"/DEBIAN/ | cut -f1 )
    payloadSize=$(( totalSize - debianSize ))
    
    # Update file size field in control file
    sed -i 's/^Installed-Size: .*$/Installed-Size: '"${payloadSize}"'/' "${controlFile}"
    # Insert Provides old version
    sed -i '/^Replaces:.*$/a Provides: '"${packageName}"' (= '"${oldVersion}"')' "${controlFile}"
    # Check if modified for gubagoo message appended to end of file, do so if not
    grep -q "This version has been modified for Gubagoo." "${controlFile}" || \
        echo "  This version has been modified for Gubagoo." >> "${controlFile}"
    # TODO, update maintainer based on github keys on system
    
    return 0
}

### MAIN

unset build_path
unset package_path

while getopts "b:p:" opt; do
    case ${opt} in
        (b)
            build_path="${OPTARG}"
        ;;
        (p)
            package_path="$(realpath -e "${OPTARG}")"
        ;;
        (\?)
            continue
        ;;
        (:)
            printf "Option -% requires an argument." "${OPTARG}" >&2
            exit 1
        ;;
    esac
done

if [[ ! ( -v build_path ) ]]; then
    build_path="${PWD}"
fi

if [[ ! ( -v package_path ) ]]; then
    package_path="${PWD}"
fi

#BUILD_USER=$(get_build_user "${build_path}")

php_versions='5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1'
source_folders='newrelic-daemon newrelic-php5 newrelic-php5-common'

clone_git_repo "${build_path}"
build_path="${build_path}"'/newrelic-php-agent'
mkdir "${build_path}"

install_build_deps
install_newrelic_repo
install_php_repo

print_section_header '-' 32 'Acquiring and Extracting Packages'

for package in ${source_folders}; do
    prepare_source_package "${package}" "${package_path}"
done

first_build='true'
cd "${build_path}" || exit 1

for version in ${php_versions}; do
    print_section_header '-' 32 "Installing PHP ${version}..."
    
    if install_php_version "${version}"; then
        print_section_header '=' 32 "Building for PHP ${version} ..."
        
        set_php_version "${version}"
        
        if [[ -v first_build ]]; then
            make
            capture_nonlib_output "${build_path}" "${package_path}"
            unset first_build
        else
            make agent
        fi
        
        make agent-install
        
        capture_lib_output "${package_path}" "${version}"
        
        make agent-clean
    fi
done

print_section_header '-' 32 'Building packages'

for source in ${source_folders}; do
    print_section_header '=' 32 "Packaging ${source} ..."
    # Packaging
    regenerate_hashfile "${package_path}" "${source}"
    update_control_file "${package_path}" "${source}"
    build_deb_package   "${package_path}" "${source}"
    # Do we want to automate the S3 upload?
done

# Cleanup
restore_php_version

exit 0

