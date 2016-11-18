# Basic test to make sure grsecurity works

import ./make-test.nix ({ pkgs, ...} : {
  name = "grsecurity";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ copumpkin joachifm ];
  };

  machine = { config, pkgs, ... }:
    { security.grsecurity.enable = true;
      boot.kernel.sysctl."kernel.grsecurity.deter_bruteforce" = 0;
    };

  testScript = ''
    subtest "grsec-lock", sub {
      $machine->succeed("systemctl is-active grsec-lock");
      $machine->succeed("grep -Fq 1 /proc/sys/kernel/grsecurity/grsec_lock");
      $machine->fail("echo -n 0 >/proc/sys/kernel/grsecurity/grsec_lock");
    };

    subtest "paxtest", sub {
      # TODO: running paxtest blackhat hangs the vm
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/anonmap") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/execbss") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/execdata") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/execheap") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/execstack") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/mprotanon") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/mprotbss") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/mprotdata") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/mprotheap") =~ /Killed/ or die;
      $machine->succeed("${pkgs.paxtest}/lib/paxtest/mprotstack") =~ /Killed/ or die;
    };

    subtest "tpe", sub {
      # With Trusted Path Execution, users should fail to execute
      # binaries under directories writable by other, non-root users
      $machine->execute("mkdir -m 777 bad");
      $machine->execute("echo true >bad/badprog; chmod +x bad/badprog");
      $machine->fail("su - alice -c $PWD/bad/badprog");

      # We do, however, want to allow custom scripts under e.g., ~/bin
      # by default
      $machine->execute("mkdir good; chown alice:alice good");
      $machine->execute("echo true >good/goodprog; chmod +x good/goodprog");
      $machine->succeed("su - alice -c $PWD/good/goodprog");
    };

    # tcc -run executes run-time generated code and so allows us to test whether
    # paxmark actually works (otherwise, the process should be terminated)
    subtest "tcc", sub {
      $machine->execute("echo -e '#include <stdio.h>\nint main(void) { puts(\"hello\"); return 0; }' >main.c");
      $machine->succeed("${pkgs.tinycc.bin}/bin/tcc -run main.c");
    };

    subtest "RBAC", sub {
      $machine->succeed("[ -c /dev/grsec ]");
    };
  '';
})
