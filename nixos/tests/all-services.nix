import ./make-test.nix ({ pkgs, ...} : {
  name = "all-services";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ ];
  };

  nodes.machine = import ./all-services-configuration.nix;

  testScript = ''
    $machine->waitForUnit("multi-user.target");
  '';
})
