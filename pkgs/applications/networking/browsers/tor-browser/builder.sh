. $stdenv/setup

export interp=$(< $NIX_CC/nix-support/dynamic-linker)

tar xf $src
cd tor-browser_$lang

# Fixup the firefox executable.  paxctl + patchelf tends to create
# invalid ELF headers; thus we only apply the PaX markings and set the
# dynamic library path and interpreter in the wrapper script.
paxmark m Browser/firefox

# Fixup tor executable
patchelf \
    --set-interpreter "$interp" \
    --set-rpath "$libPath:$out/share/$pname/Browser/TorBrowser/Tor" \
    Browser/TorBrowser/Tor/tor

# Fixup paths to pluggable transports
sed "s,./TorBrowser,$out/share/$pname/Browser/TorBrowser,g" \
    -i Browser/TorBrowser/Data/Tor/torrc-defaults

# Fixup pluggable fte transport
#
# Note: the script adds its dirname to the search path by itself
sed \
    -e "s,/usr/bin/env python,$python27," \
    -i Browser/TorBrowser/Tor/PluggableTransports/fteproxy.bin

patchelf \
    --set-rpath "$fteLibPath" \
    Browser/TorBrowser/Tor/PluggableTransports/fte/cDFA.so

# Hack around patchelf failing to set interpreter for Go binaries
#
# We have to be somewhat specific here, not all transport plugins are
# statically linked ELFs, some may be Python scripts (e.g., fteproxy).
sed \
    -e "s|\(ClientTransportPlugin obfs2,obfs3,obfs4,scramblesuit\) exec|\1 exec $interp|" \
    -e "s|\(ClientTransportPlugin meek\) exec|\1 exec $interp|" \
    -i Browser/TorBrowser/Data/Tor/torrc-defaults

# Install
mkdir -p $out/share/$pname
cp -R * $out/share/$pname/

mkdir -p $out/share/applications
cp $desktopItem/share/applications/$pname.desktop $out/share/applications/$pname.desktop

mkdir -p $out/share/pixmaps
cp Browser/browser/icons/mozicon128.png $out/share/pixmaps/$pname.png

mkdir -p $out/bin
substituteAll $wrapper $out/bin/$pname
chmod +x $out/bin/$pname

# Post installation test
(
HOME=$TMPDIR
TBB_DEBUG=1 $out/bin/$pname --help >/dev/null
torrc=$out/share/tor-browser/Browser/TorBrowser/Data/Tor/torrc-defaults
$out/share/tor-browser/Browser/TorBrowser/Tor/tor -f "$torrc" --help >/dev/null
)
