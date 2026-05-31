{inputs}: final: prev: {
  mreply = prev.stdenvNoCC.mkDerivation {
    pname = "mreply";
    version = inputs.mreply.rev;
    src = inputs.mreply;

    installPhase = ''
      runHook preInstall
      install -Dm755 mreply $out/bin/mreply
      runHook postInstall
    '';

    postFixup = ''
      patchShebangs $out/bin/mreply
    '';
  };
}
