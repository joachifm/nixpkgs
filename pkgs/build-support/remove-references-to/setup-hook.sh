# @param removeReferencesTo list of store paths to remove references to
# @param removeReferencesToOutputs list of output names (defaults to $outputs)

preFixupHooks+=(_removeReferencesTo)
_removeReferencesTo() {
    local cmd="@removeReferencesTo@/bin/remove-references-to"
    local tgt
    for tgt in $removeReferencesTo ; do
        cmd+=" -t $tgt"
    done

    : ${removeReferencesToOutputs:=$outputs}

    local dirs=()
    local outName
    for outName in $removeReferencesToOutputs ; do
        local -n ref=$outName
        dirs+=("$ref")
    done

    find "${dirs[@]}" -type f -print0 | xargs --null -P$NIX_BUILD_CORES -r -n1 $cmd
}
