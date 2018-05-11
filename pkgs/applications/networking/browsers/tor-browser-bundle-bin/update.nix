{ lib
, writeScript
, common-updater-scripts
, bash
, coreutils
, curl
, gnugrep
, gnused
, gnupg
}:
writeScript "update-tor-browser-bundle-bin" ''
#! ${bash}/bin/bash
set -eu -o pipefail

PATH=${lib.makeBinPath [ coreutils curl gnugrep gnused gnupg ]}

# See https://www.torproject.org/docs/signing-keys.html
sig_fprint+=(
    # Tor Browser Developers (signing key)
    "EF6E 286D DA85 EA2A 4BA7 DE68 4E2C 6E87 9329 8290"
)

platforms+=("linux32" "linux64")
langs+=("en-US")

download_page_url=https://dist.torproject.org/torbrowser
version=$(curl ''${CURLOPTS[*]} --list-only -- "$download_page_url" \
    | grep -Po '<a href\="\K([[:digit:]]+\.?)+/' \
    | sed 's,/$,,' \
    | sort -Vu \
    | tail -n1)
src_url_base=https://dist.torproject.org/torbrowser/$version
''