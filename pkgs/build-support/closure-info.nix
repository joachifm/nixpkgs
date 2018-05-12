# This derivation builds two files containing information about the
# closure of 'rootPaths': $out/store-paths contains the paths in the
# closure, and $out/registration contains a file suitable for use with
# "nix-store --load-db" and "nix-store --register-validity
# --hash-given".

{ runCommand, coreutils, jq }:

{ rootPaths }:

assert builtins.langVersion >= 5;

runCommand "closure-info"
{ __structuredAttrs = true;
  exportReferencesGraph.closure = rootPaths;
  nativeBuildInputs = [ coreutils jq ];
  preferLocalBuild = true;
  allowSubstitutes = false;
}
''
. .attrs.sh
out=''${outputs[out]}
mkdir $out

jq -r ".closure | map(.narSize) | add" < .attrs.json > $out/total-nar-size
jq -r '.closure | map([.path, .narHash, .narSize, "", (.references | length)] + .references) | add | map("\(.)\n") | add' < .attrs.json | head -n -1 > $out/registration
jq -r .closure[].path < .attrs.json > $out/store-paths
''
