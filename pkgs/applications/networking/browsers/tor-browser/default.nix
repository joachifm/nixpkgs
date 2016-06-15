{ stdenv

# build helpers
, fetchurl
, makeDesktopItem

# firefox run-time dependencies
, alsaLib
, atk
, cairo
, dbus
, dbus_glib
, fontconfig
, freetype
, gdk_pixbuf
, glib
, gtk
, libX11
, libXext
, libXrender
, libXt
, pango

# tor run-time dependencies
, zlib

# pluggable transport dependencies
, python27Packages
, gmp
}:

let
  # When updating to a new version, please
  # 1) always derive the hash from the official sources, preferably after
  #    having verified their signatures; and
  # 2) test build both x86 and x86_64 variants:
  #    nix-build -A tor-browser -A pkgsi686Linux.tor-browser

  version = "6.0.2";

  binary = {
    "x86_64-linux" = {
      sha256 = "08zik2id1rkcl5cw4yscdgb8rdahx342j1fps576465sziy5z06x";
      arch = "linux64";
    };
    "i686-linux" = {
      sha256 = "062ddifhdbzj9hjcnvjnqb1is2ydrv9x7hzam4jkpsfvllf4hxcg";
      arch = "linux32";
    };
  };

  inherit (binary.${stdenv.system} or (throw "unsupported system: ${stdenv.system}"))
    sha256 arch;
  platforms = stdenv.lib.attrNames binary;

  # The "state version": change this whenever the user's state must be
  # re-initialized from the Nix store.  This is to prevent the situation where
  # the user updates tor-browser but continues to use old data files.
  #
  # When version is bumped, the suffix should be reset to 1.
  stateVersion = "${version}-1";
in

stdenv.mkDerivation rec {
  pname = "tor-browser";
  name = "${pname}-${version}";

  inherit stateVersion;

  src = fetchurl {
    url = "https://archive.torproject.org/tor-package-archive/torbrowser/${version}/tor-browser-${arch}-${version}_${lang}.tar.xz";
    inherit sha256;
  };

  lang = "en-US";

  # The library path contains anything not included in the tor browser bundle.
  # For example, tor also requires libevent, gmp, and openssl, but we use the
  # bundled versions to ensure parity with upstream.
  libPath = stdenv.lib.makeLibraryPath [
    stdenv.cc.cc glib alsaLib dbus dbus_glib gtk atk pango freetype
    fontconfig gdk_pixbuf cairo libXrender libX11 libXext libXt
    zlib
  ];

  desktopItem = makeDesktopItem {
    name = pname;
    exec = pname;
    icon = pname;
    desktopName = "Tor Browser";
    genericName = "Tor Browser";
    comment = meta.description;
    categories = "Network;WebBrowser;Security;";
  };

  # python interpreter used by some pluggable transports
  python27 = python27Packages.python.interpreter;

  # library search path for the fte transport
  fteLibPath = stdenv.lib.makeLibraryPath [ stdenv.cc.cc gmp ];

  builder = ./builder.sh;
  wrapper = ./wrapper.sh;

  meta = with stdenv.lib; {
    inherit platforms;
    description = "Anonymous browsing with Firefox and Tor";
    homepage = https://www.torproject.org/;
    maintainers = with maintainers; [ offline matejc doublec thoughtpolice joachifm ];
  };
}
