{ stdenv, lua, fetchFromGitHub, fetchurl, which, llvmPackages, ncurses,
  enableSharedLibraries ? true }:

let llvm     = llvmPackages.llvm;
    toRemove = if enableSharedLibraries
                 then "libterra.a"
                 else "terra.so";

    luajitArchive = "LuaJIT-2.0.4.tar.gz";
    luajitSrc     = fetchurl {
      url = "http://luajit.org/download/${luajitArchive}";
      sha256 = "0zc0y7p6nx1c0pp4nhgbdgjljpfxsb5kgwp4ysz22l1p2bms83v2";
    };
in stdenv.mkDerivation rec {
  name = "terra-git-${version}";
  version = "2016-06-09";

  src = fetchFromGitHub {
    owner = "zdevito";
    repo = "terra";
    rev = "22696f178be8597af555a296db804dba820638ba";
    sha256 = "1c2i9ih331304bh31c5gh94fx0qa49rsn70pvczvdfhi8pmcms6g";
  };

  outputs = [ "dev" "out" "bin" ];

  patchPhase = ''
    substituteInPlace Makefile --replace \
      '-lcurses' '-lncurses'
  '';

  configurePhase = ''
    mkdir -p build
    cp ${luajitSrc} build/${luajitArchive}
  '';

  installPhase = ''
    mkdir -p $out $bin $dev
    cp -r "release/"* $out
    mv $out/lib $dev
    mv $out/include $dev
    mv $out/bin $bin
    rm -f $dev/lib/${toRemove}
  ''
  ;

  buildInputs = [ which lua llvm llvmPackages.clang-unwrapped ncurses ];

  meta = with stdenv.lib; {
    inherit (src.meta) homepage;
    description = "A low-level counterpart to Lua";
    maintainers = with maintainers; [ jb55 ];
    license = licenses.mit;
  };
}
