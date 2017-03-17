{ stdenv
, fetchurl
, makeDesktopItem

# Common run-time dependencies
, zlib

# libxul run-time dependencies
, alsaLib
, atk
, cairo
, dbus
, dbus_glib
, fontconfig
, freetype
, gdk_pixbuf
, glib
, gtk2
, libX11
, libXext
, libXrender
, libXt
, pango

# Pluggable transport dependencies
, python27

# Media support
, gstreamer
, gst-plugins-base
, gst-plugins-good
, gst-ffmpeg
, gmp
, ffmpeg
, libpulseaudio
, mediaSupport ? false
}:

with stdenv.lib;

let
  libPath = makeLibraryPath ([
    alsaLib
    atk
    cairo
    dbus
    dbus_glib
    fontconfig
    freetype
    gdk_pixbuf
    glib
    gtk2
    libX11
    libXext
    libXrender
    libXt
    pango
    stdenv.cc.cc
    zlib
  ] ++ optionals mediaSupport [
    gstreamer
    gst-plugins-base
    gmp
    ffmpeg
    libpulseaudio
  ]);

  gstPluginsPath = concatMapStringsSep ":" (x:
    "${x}/lib/gstreamer-0.10") [
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gst-ffmpeg
    ];

  # Library search path for the fte transport
  fteLibPath = makeLibraryPath [ stdenv.cc.cc gmp ];

  # Upstream source
  version = "6.5.1";

  lang = "en-US";

  srcs = {
    "x86_64-linux" = fetchurl {
      url = "https://dist.torproject.org/torbrowser/${version}/tor-browser-linux64-${version}_${lang}.tar.xz";
      sha256 = "1p2bgavvyzahqpjg9vp14c0s50rmha3v1hs1c8zvz6fj8fgrhn0i";
    };

    "i686-linux" = fetchurl {
      url = "https://dist.torproject.org/torbrowser/${version}/tor-browser-linux32-${version}_${lang}.tar.xz";
      sha256 = "1zfghr01bhpn39wqaw7hyx7yap7xyla4m3mrgz2vi9a5qsyxmbcr";
    };
  };
in

stdenv.mkDerivation rec {
  name = "tor-browser-${version}";
  inherit version;

  src = srcs."${stdenv.system}" or (throw "unsupported system: ${stdenv.system}");

  preferLocalBuild = true;

  desktopItem = makeDesktopItem {
    name = "torbrowser";
    exec = "tor-browser";
    icon = "torbrowser";
    desktopName = "Tor Browser";
    genericName = "Web Browser";
    comment = meta.description;
    categories = "Network;WebBrowser;Security;";
  };

  buildCommand = ''
    # For convenience ...
    TBB_IN_STORE=$out/share/tor-browser
    interp=$(< $NIX_CC/nix-support/dynamic-linker)

    # Unpack & enter
    mkdir -p "$TBB_IN_STORE"
    tar xf ${src} -C "$TBB_IN_STORE" --strip-components=2
    pushd "$TBB_IN_STORE"

    # Fixup main executables
    for exe in firefox TorBrowser/Tor/tor ; do
      patchelf --set-interpreter "$interp" "$exe"
    done

    # Fixup paths to pluggable transports
    sed -i TorBrowser/Data/Tor/torrc-defaults \
        -e "s,./TorBrowser,$TBB_IN_STORE/TorBrowser,g"

    # Fixup pluggable fte transport
    #
    # Note: the script adds its dirname to search path automatically
    sed -i TorBrowser/Tor/PluggableTransports/fteproxy.bin \
        -e "s,/usr/bin/env python,${python27.interpreter},"

    patchelf --set-rpath "${fteLibPath}" \
      TorBrowser/Tor/PluggableTransports/fte/cDFA.so

    # Fixup obfs &c.  Work around patchelf failing to set
    # interpreter for pre-compiled Go binaries.
    #
    # Note that for meek we're only inserting $interp infront of
    # meek-client; meek-client-torbrowser is reported to have no
    # interpreter and invoking it via $interp causes a segfault.
    sed -i TorBrowser/Data/Tor/torrc-defaults \
        -e "s|\(ClientTransportPlugin obfs2,obfs3,obfs4,scramblesuit\) exec|\1 exec $interp|" \
        -e "s|\(ClientTransportPlugin meek exec .* --\)|\1 $interp|"

    # Hard-coded prefs.  Setting these here instead of in
    # extension-overrides.js avoids writing sure-to-go-bad store
    # references into the local state dir.
    #
    # See https://developer.mozilla.org/en-US/Firefox/Enterprise_deployment
    cat >defaults/pref/autoconfig.js <<EOF
    //
    pref("general.config.filename", "mozilla.cfg");
    pref("general.config.obscure_value", 0);
    EOF
    cat >mozilla.cfg <<EOF
    // First line must be a comment

    // Always update via Nix
    lockPref("app.update.auto", false);
    lockPref("app.update.enabled", false);
    lockPref("extensions.update.autoUpdateDefault", false);
    lockPref("extensions.update.enabled", false);

    // User should never change these.  Locking also helps keep
    // references out of prefs.js.
    lockPref("extensions.torlauncher.torrc-defaults_path", "$TBB_IN_STORE/TorBrowser/Data/Tor/torrc-defaults");
    lockPref("extensions.torlauncher.tor_path", "$TBB_IN_STORE/TorBrowser/Tor/tor");

    // Clear out pref that captures store paths in prefs.js.
    clearPref("extensions.xpiState");

    // Stop obnoxious first-run redirection
    lockPref("noscript.firstRunRedirection", false);
    EOF

    # Hard-code paths to TBB fonts; see also FONTCONFIG_FILE in the wrapper
    # below.
    sed -i $TBB_IN_STORE/TorBrowser/Data/fontconfig/fonts.conf \
        -e "s,<dir>fonts</dir>,<dir>$TBB_IN_STORE/fonts</dir>,"

    # Move default extension overrides into distribution dir, to
    # avoid having to synchronize between local state and store.
    mv TorBrowser/Data/Browser/profile.default/preferences/extension-overrides.js defaults/pref/torbrowser.js

    # Hard-code paths to avoid writing store references into local state dir.
    cat >>TorBrowser/Data/Tor/torrc-defaults <<EOF
    GeoIPFile $TBB_IN_STORE/TorBrowser/Data/Tor/geoip
    GeoIPv6File $TBB_IN_STORE/TorBrowser/Data/Tor/geoip6
    EOF

    # Generate wrapper
    mkdir -p $out/bin
    cat > "$out/bin/tor-browser" << EOF
    #! ${stdenv.shell}
    set -e

    REAL_HOME=\$HOME
    TBB_HOME=\''${TBB_HOME:-''${XDG_DATA_HOME:-\$REAL_HOME/.local/share}/tor-browser}
    HOME=\$TBB_HOME

    mkdir -pv "\$HOME"
    cd "\$HOME"

    mkdir -pv "\$HOME/TorBrowser" "\$HOME/TorBrowser/Data"

    # Initialize the Tor data directory
    mkdir -pv "\$HOME/TorBrowser/Data/Tor"
    touch "\$HOME/TorBrowser/Data/Tor/torrc-defaults" && chmod -w "\$HOME/TorBrowser/Data/Tor/torrc-defaults"

    # Initialize the browser profile state
    mkdir -pv "\$HOME/TorBrowser/Data/Browser/profile.default"
    cp -uv --no-preserve=mode,owner "$TBB_IN_STORE/TorBrowser/Data/Browser/profile.default/bookmarks.html" \
      "\$HOME/TorBrowser/Data/Browser/profile.default/bookmarks.html"

    # Clear out some files that tend to capture store
    # references but are easily generated by firefox at startup
    rm -f "\$HOME/TorBrowser/Data/Browser/profile.default"/{compatibility.ini,extensions.ini,extensions.json}

    # Ensure that we're always using the up-to-date extensions
    ln -snf "$TBB_IN_STORE/TorBrowser/Data/Browser/profile.default/extensions" \
      "\$HOME/TorBrowser/Data/Browser/profile.default/extensions"

    # Initialize the profile used by the meek helpers
    #
    # Remove paths that retain references; also delete lock
    # files which can cause the meek-client to fail due to
    # "being in use" (seems like it fails to clean up properly
    # after itself).
    rm -f "\$HOME/TorBrowser/Data/Browser/profile.meek-http-helper"/{compatibility.ini,extensions.ini,extensions.json,lock,prefs.js}
    mkdir -p "\$HOME/TorBrowser/Data/Browser/profile.meek-http-helper"
    ln -snf "$TBB_IN_STORE/TorBrowser/Data/Browser/profile.meek-http-helper/extensions" \
      "\$HOME/TorBrowser/Data/Browser/profile.meek-http-helper/extensions"
    ln -snf "$TBB_IN_STORE/TorBrowser/Data/Browser/profile.meek-http-helper/user.js" \
      "\$HOME/TorBrowser/Data/Browser/profile.meek-http-helper/user.js"

    # The meek helper is hard-coded to resolve the firefox
    # executable relative to the profile directory.  If we built
    # the helper from source we could patch around this, but
    # here we are ...
    ln -snf "$TBB_IN_STORE/firefox" "\$HOME/firefox"

    ${optionalString mediaSupport ''
      # Figure out some envvars for pulseaudio
      : \''${XDG_RUNTIME_DIR:=/run/user/\$(id -u)}
      : \''${XDG_CONFIG_HOME:=\$REAL_HOME/.config}
      : \''${PULSE_SERVER:=\$XDG_RUNTIME_DIR/pulse/native}
      : \''${PULSE_COOKIE:=\$XDG_CONFIG_HOME/pulse/cookie}
    ''}

    # Font cache files capture store paths; clear them for completeness sake ...
    rm -rf \$HOME/.cache/fontconfig

    # Lift-off
    #
    # DBUS_SESSION_BUS_ADDRESS is inherited to avoid auto-launch;
    # to prevent that, set it to an empty/invalid value prior to
    # running tor-browser.
    #
    # PULSE_SERVER is necessary for audio playback.
    #
    # Setting FONTCONFIG_FILE is required to make fontconfig
    # read the TBB fonts.conf; upstream uses FONTCONFIG_PATH,
    # but FC_DEBUG=1024 indicates that it results in the system
    # fonts.conf being used instead.
    exec env -i \
      HOME="\$HOME" \
      XAUTHORITY="\$XAUTHORITY" \
      DISPLAY="\$DISPLAY" \
      DBUS_SESSION_BUS_ADDRESS="\$DBUS_SESSION_BUS_ADDRESS" \
      \
      PULSE_SERVER="\$PULSE_SERVER" \
      PULSE_COOKIE="\$PULSE_COOKIE" \
      \
      GST_PLUGIN_SYSTEM_PATH="${optionalString mediaSupport gstPluginsPath}" \
      GST_REGISTRY="/dev/null" \
      GST_REGISTRY_UPDATE="no" \
      \
      FC_DEBUG=1024 \
      FONTCONFIG_FILE="$TBB_IN_STORE/TorBrowser/Data/fontconfig/fonts.conf" \
      \
      LD_LIBRARY_PATH="${libPath}:$TBB_IN_STORE/TorBrowser/Tor" \
      \
      "$TBB_IN_STORE/firefox" \
        --class "Tor Browser" \
        -no-remote \
        -profile "\$HOME/TorBrowser/Data/Browser/profile.default" \
        "\''${@}"
    EOF
    chmod +x $out/bin/tor-browser

    # Easier access to docs
    mkdir -p $out/share/doc
    ln -s $TBB_IN_STORE/TorBrowser/Docs $out/share/doc/tor-browser

    # Install .desktop item
    mkdir -p $out/share/applications
    cp $desktopItem/share/applications"/"* $out/share/applications

    # Install icons
    mkdir -p $out/share/pixmaps
    cp browser/icons/mozicon128.png $out/share/pixmaps/torbrowser.png
  '';

  meta = with stdenv.lib; {
    description = "Tor Browser Bundle";
    homepage = https://www.torproject.org/;
    platforms = attrNames srcs;
    maintainers = with maintainers; [ offline matejc doublec thoughtpolice joachifm ];
    hydraPlatforms = [];
    # MPL2.0+, GPL+, &c.  While it's not entirely clear whether
    # the compound is "libre" in a strict sense (some components place certain
    # restrictions on redistribution), it's free enough for our purposes.
    license = licenses.free;
  };
}
