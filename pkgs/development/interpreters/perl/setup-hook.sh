setDeterministicPerlHashSeed() {
    export PERL_HASH_SEED=0 # implies PERL_PERTURB_KEYS=0
}

addPerlLibPath () {
    addToSearchPath PERL5LIB $1/lib/perl5/site_perl
}

envHooks+=(setDeterministicPerlHashSeed addPerlLibPath)
