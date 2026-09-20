{ version, revision, release ? false }:
let
  cleanRevision = builtins.replaceStrings [ "-dirty" ] [ "" ] revision;
  dirty = cleanRevision != revision;
  gitRevision = builtins.match "[0-9a-f]{7,64}(-dirty)?" revision != null;
  sourceRevision = builtins.match "source-[0-9a-f]{64}" revision != null;
in
assert builtins.match "(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)" version != null;
assert gitRevision || sourceRevision || revision == "unknown";
assert !release || (gitRevision && !dirty);
if release then version
else version + "-dev." + (
  if gitRevision then builtins.substring 0 12 cleanRevision + (if dirty then ".dirty" else "")
  else if sourceRevision then "source." + builtins.substring 7 12 revision
  else "unknown"
)
