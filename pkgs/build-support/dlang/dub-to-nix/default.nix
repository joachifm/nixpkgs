{
  lib,
  runCommand,
  makeWrapper,
  python3,
  nix,
}:

runCommand "dub-to-nix"
  {
    nativeBuildInputs = [ makeWrapper ];
    buildInputs = [ python3 ];
  }
  ''
    install -Dm755 ${./dub-to-nix.py} "$out/bin/dub-to-nix"
    patchShebangs "$out/bin/dub-to-nix"
    wrapProgram "$out/bin/dub-to-nix" \
        --prefix PATH : ${lib.makeBinPath [ nix ]}
  ''
