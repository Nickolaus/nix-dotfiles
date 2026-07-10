{ lib
, pkgs
, pyproject-nix
, uv2nix
, pyproject-build-systems
}:

let
  python = pkgs.python313;
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./.;
  };
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };
  pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      overlay
    ]
  );
  virtualenv = pythonSet.mkVirtualEnv "arize-phoenix-env" workspace.deps.default;
in
pkgs.runCommand "arize-phoenix-17.23.0"
{
  nativeBuildInputs = [ pkgs.makeWrapper ];
  passthru.virtualenv = virtualenv;

  meta = {
    description = "Arize Phoenix local AI observability server";
    homepage = "https://github.com/Arize-ai/phoenix";
    license = lib.licenses.elastic20;
    mainProgram = "phoenix";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
  ''
    mkdir -p "$out/bin"
    makeWrapper "${virtualenv}/bin/phoenix" "$out/bin/phoenix"
  ''
