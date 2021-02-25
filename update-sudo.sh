#!/usr/bin/env bash

#
# references:
# https://ubuntu.com/security/CVE-2021-3156
# https://ubuntu.com/security/notices/USN-4705-1?_ga=2.80187031.1643722137.1613783816-1605013953.1613783816
# https://ubuntu.com/security/notices/USN-4705-2?_ga=2.89755035.1643722137.1613783816-1605013953.1613783816
#
# sudo before 1.9.5p2 has a Heap-based Buffer Overflow, allowing
# privilege escalation to root via "sudoedit -s" and a command-line
# argument that ends with a single backslash character.
#
# sudo patched versions:
# Ubuntu 21.04 (Hirsute Hippo)  Released (1.9.4p2-2ubuntu2)
# Ubuntu 20.10 (Groovy Gorilla) Released (1.9.1-1ubuntu1.1)
# Ubuntu 20.04 LTS (Focal Fossa)        Released (1.8.31-1ubuntu1.2)
# Ubuntu 18.04 LTS (Bionic Beaver)      Released (1.8.21p2-3ubuntu1.4)
# Ubuntu 16.04 LTS (Xenial Xerus)       Released (1.8.16-0ubuntu1.10)
# Ubuntu 14.04 ESM (Trusty Tahr)        Released (1.8.9p5-1ubuntu1.5+esm6)
#

#set -o errexit
#set -o nounset
#set -o xtrace


# set vars
PKG_NAME="sudo"
OS_VERSION=$(lsb_release -sr)
declare -A pkg_query

# list of patched versions per advisory
case ${OS_VERSION} in
   '12.04')
       PATCHED_VERSION="1.8.3p1-1ubuntu3.10"
       ;;
   '14.04')
       PATCHED_VERSION="1.8.9p5-1ubuntu1.5+esm6"
       ;;
   '16.04')
       PATCHED_VERSION="1.8.16-0ubuntu1.10"
       ;;
   '18.04')
       PATCHED_VERSION="1.8.21p2-3ubuntu1.4"
       ;;
   '20.04')
       PATCHED_VERSION="1.8.31-1ubuntu1.2"
       ;;
   '20.10')
       PATCHED_VERSION="1.9.1-1ubuntu1.1"
       ;;
   '21.04')
       PATCHED_VERSION="1.9.4p2-2ubuntu2"
       ;;
   *)
       PATCHED_VERSION="unknown"
       ;;
esac


# functions
err() {
  echo "[$(date +'%F %T %Z')]: $@" >&2
  exit 1
}

check_pkg_status() {
  local pkg_to_check="$1"
  dpkg-query --show --showformat='Package:${binary:Package}\nVersion:${Version}\nStatus:${db:Status-Status}\nEFlag:${db:Status-Eflag}\n' ${pkg_to_check}
}

collect_pkg_info() {
   local pkg_to_check="$1"

   local q=$(check_pkg_status ${pkg_to_check} 2>&1)
   if [[ "${q}" =~ ^Package:${pkg_to_check}.* ]]; then
      while IFS=':' read -r key value
      do
         pkg_query["$key"]="$value"
      done <<< "${q}"
   fi
}

compare_pkg_versions() {
   local version_to_check="$1"
   local comparison_operation="$2"
   dpkg --compare-versions ${version_to_check} ${comparison_operation} ${PATCHED_VERSION}
}

update_pkg() {
  local pkg_to_upgrade="$1"
  sudo apt update && sudo apt-get install --only-upgrade ${pkg_to_upgrade}
}

verify_update(){
  local pkg_to_verify="$1"

  collect_pkg_info ${pkg_to_verify}
  local version_to_verify="${pkg_query[Version]}"
  printf "Updated Version: %s %s\n" ${pkg_to_verify} ${version_to_verify}
  compare_pkg_versions ${version_to_verify} eq
}



# run it
printf "** check_pkg_status ** :: Check if package exists. exit if package is not present\n\n"
check_pkg_status ${PKG_NAME} || exit 1

printf "\n** collect_pkg_info ** :: collect package information\n\n"
collect_pkg_info ${PKG_NAME}
if [[ ${pkg_query[Status]} == installed ]] && [[ ${pkg_query[EFlag]} == ok ]] && [[ ${pkg_query[Package]} == ${PKG_NAME} ]]; then
   printf "** compare_pkg_versions ** :: Check if package is already at patched version. Update package if required\n\n"
   ( compare_pkg_versions ${pkg_query[Version]} lt && update_pkg ${PKG_NAME} ) \
           || err "don't update -> installed version is not less than ${PATCHED_VERSION}"

   # verify updated version
   printf "\n\n** verify_update ** :: Verify update\n\n"
   ( verify_update ${PKG_NAME} && printf "Verification successful\n" ) \
           || err "Verification failed"
fi

exit 0
#--DONE
