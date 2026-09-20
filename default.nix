{ lib, stdenvNoCC, python3
, version ? (builtins.fromJSON (builtins.readFile ./plugin.json)).version
, revision ? null, release ? false }:
let
  metadata = import ./build-metadata.nix { inherit lib version revision release; };
in
stdenvNoCC.mkDerivation {
  pname = lib.toLower metadata.config.pluginDirectory;
  version = metadata.version;
  src = metadata.source;
  nativeBuildInputs = [ python3 ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    python3 scripts/package.py --stage-only --output "$out" \
      --revision ${lib.escapeShellArg metadata.revision} ${lib.optionalString release "--release"}
    runHook postInstall
  '';
}
