export PATH=
for i in $initialPath; do
    if [ "$i" = / ]; then i=; fi
    PATH=$PATH${PATH:+:}$i/bin
done

mkdir $out


mkdir $out/bin

real_date=$(type -P date)
if [ -n "$real_date" ]; then
    cat >$out/bin/date <<EOF
#! $shell
exec $real_date -d${SOURCE_DATE_EPOCH:=1} "\$@"
EOF
    chmod +x $out/bin/date
    initialPath="$out $initialPath"
fi

real_gzip=$(type -P gzip)
if [ -n "$real_gzip" ]; then
    cat >$out/bin/gzip <<EOF
#! $shell
exec $real_gzip -n "\${@}"
EOF
    chmod +x $out/bin/gzip
fi


echo "export SHELL=$shell" > $out/setup
echo "initialPath=\"$initialPath\"" >> $out/setup
echo "defaultNativeBuildInputs=\"$defaultNativeBuildInputs\"" >> $out/setup
echo "$preHook" >> $out/setup
cat "$setup" >> $out/setup

# Allow the user to install stdenv using nix-env and get the packages
# in stdenv.
mkdir $out/nix-support
echo $propagatedUserEnvPkgs > $out/nix-support/propagated-user-env-packages
