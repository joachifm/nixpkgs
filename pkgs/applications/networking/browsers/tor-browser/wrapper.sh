#! @shell@ -e

HOME=${TBB_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/@pname@/@stateVersion@}

if [[ ! -d "$HOME" ]]; then
    echo "tor-browser: creating a new state directory: $HOME" >&2
    mkdir -p "$HOME"
    cp -R "@out@/share/@pname@/Browser/TorBrowser/Data" "$HOME"
    chmod -R +w "$HOME"
    # See https://gitweb.torproject.org/tor-launcher.git/tree/src/defaults/preferences/prefs.js
    # for a full listing.  As a quick reminder
    #    loglevel: 2 = debug, 4 = note
    #    logmethod: 0 = stdout
    cat >>"$HOME/Data/Browser/profile.default/preferences/extension-overrides.js" <<EOF

// Options set by the Nixpkgs wrapper
pref("extensions.torlauncher.loglevel", 2);
pref("extensions.torlauncher.logmethod", 0);

pref("extensions.torlauncher.tor_path", "@out@/share/@pname@/Browser/TorBrowser/Tor/tor");
pref("extensions.torlauncher.tordatadir_path", "$HOME/Data/Tor/");
pref("extensions.torlauncher.torrc-defaults_path", "$HOME/Data/Tor/torrc-defaults");
pref("extensions.torlauncher.torrc_path", "$HOME/Data/Tor/torrc");

pref("app.update.auto", false);
pref("extensions.update.enabled", false);
EOF
fi

if [[ -z "$TBB_DEBUG" ]] || [[ "$TBB_DEBUG" = "0" ]] ; then
    TBB_LOGFILE=$HOME/tor-browser.log
    mv -f "$TBB_LOGFILE" "${TBB_LOGFILE}.old" 2>/dev/null || true
    echo "tor-browser: stdout and stderr redirected to $TBB_LOGFILE" >&2
    exec  >"$TBB_LOGFILE"
    exec 2>"$TBB_LOGFILE"
fi

tbb_exe=@out@/share/@pname@/Browser/firefox

cd "$HOME"
exec env -i \
     LD_LIBRARY_PATH=@libPath@ \
     HOME=$HOME \
     DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
     XAUTHORITY=$XAUTHORITY \
     DISPLAY=$DISPLAY \
     FONTCONFIG_PATH=$HOME/Data/fontconfig \
     FONTCONFIG_FILE="fonts.conf" \
     "$tbb_exe" \
     --class "Tor Browser" \
     --no-remote \
     --profile "$HOME/Data/Browser/profile.default" \
     "$@"
