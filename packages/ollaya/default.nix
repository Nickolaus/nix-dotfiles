{ lib
, stdenvNoCC
, fetchurl
, version
, darwinArm64Hash
, defaultHost ? "127.0.0.1:11435"
, defaultKeepAlive ? "5m"
}:

# Prebuilt upstream release (ONNX Runtime statically linked, llama.cpp dylibs
# resolved via @loader_path, ad-hoc signed). Nothing is rebuilt or patched.
stdenvNoCC.mkDerivation {
  pname = "ollaya";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ollaya-dev/ollaya/releases/download/v${version}/ollaya-darwin-arm64.tgz";
    hash = darwinArm64Hash;
  };

  sourceRoot = ".";

  # Stripping or fixup would invalidate the ad-hoc code signature.
  dontStrip = true;
  dontFixup = true;
  dontConfigure = true;
  dontBuild = true;

  # The real binary must keep the basename `ollaya`: `ollaya stop` identifies
  # the daemon it started by process name, so a makeWrapper-style
  # `.ollaya-wrapped` rename makes it refuse to stop and drop its pidfile.
  # The daemon inherits the environment of whichever client starts it, so
  # every entry point sets the same defaults here.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/ollaya $out/bin
    cp -R bin lib share $out/libexec/ollaya/

    cat > $out/bin/ollaya <<EOF
    #!/bin/sh
    : "\''${OLLAYA_HOST:=${defaultHost}}"
    : "\''${OLLAYA_MODELS:=\$HOME/.local/share/ollaya/models}"
    : "\''${OLLAYA_LOG_DIR:=\$HOME/.local/state/ollaya}"
    : "\''${OLLAYA_KEEP_ALIVE:=${defaultKeepAlive}}"
    : "\''${OLLAYA_MAX_LOADED_MODELS:=1}"
    export OLLAYA_HOST OLLAYA_MODELS OLLAYA_LOG_DIR OLLAYA_KEEP_ALIVE OLLAYA_MAX_LOADED_MODELS
    exec $out/libexec/ollaya/bin/ollaya "\$@"
    EOF
    chmod +x $out/bin/ollaya

    runHook postInstall
  '';

  passthru = { inherit defaultHost; };

  meta = {
    description = "Local daemon for open decision models (Ollama-style CLI and API)";
    homepage = "https://github.com/ollaya-dev/ollaya";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "ollaya";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
