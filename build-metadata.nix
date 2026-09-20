{ lib, version ? (builtins.fromJSON (builtins.readFile ./plugin.json)).version
, revision ? null, release ? false }:
let
  source = lib.cleanSourceWith {
    src = ./.;
    filter = path: type:
      lib.cleanSourceFilter path type
      && !(builtins.elem (baseNameOf path) [ "dist" "__pycache__" ".envrc" ]);
  };
  files = lib.filesystem.listFilesRecursive source;
  publicFiles = builtins.filter (path:
    lib.any (extension: lib.hasSuffix extension (baseNameOf path))
      [ ".go" ".qml" ".js" ".json" ".nix" ".py" ".svg" ".png" ]
  ) files;
  sourceRevision = "source-" + builtins.hashString "sha256"
    (lib.concatMapStrings (path: builtins.hashFile "sha256" path) publicFiles);
  buildRevision = if revision == null then sourceRevision else revision;
in
assert version == (builtins.fromJSON (builtins.readFile ./plugin.json)).version;
{
  inherit source;
  revision = buildRevision;
  version = import ./build-version.nix { inherit version release; revision = buildRevision; };
  config = builtins.fromJSON (builtins.readFile ./packaging.json);
}
