inputs:
final: prev:

let
  inherit (prev) lib;

  mkSucklessPackage = {
    pname,
    srcName,
    buildInputs ? [ ],
    extraNativeBuildInputs ? [ ],
    description ? "Personal build of ${pname}",
  }:
    prev.stdenv.mkDerivation rec {
      inherit pname buildInputs;
      version = inputs.${srcName}.rev or "git";
      src = inputs.${srcName};

      nativeBuildInputs = [ prev.pkg-config ] ++ extraNativeBuildInputs;
      strictDeps = true;

      buildPhase = ''
        runHook preBuild
        make
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        make PREFIX=$out install
        runHook postInstall
      '';

      meta = with lib; {
        inherit description;
        homepage = "https://github.com/onur-ozkan/${srcName}";
        license = licenses.mit;
        platforms = platforms.linux;
      };
    };

  xCommon = with prev.xorg; [
    libX11
    libXft
    libXinerama
    libXrandr
  ];
in {
  dwm-enhanced = mkSucklessPackage {
    pname = "dwm-enhanced";
    srcName = "dwm-enhanced";
    buildInputs = xCommon ++ [ prev.xorg.libXi ];
    description = "Personal dwm build with custom patches";
  };

  st-enhanced = mkSucklessPackage {
    pname = "st-enhanced";
    srcName = "st-enhanced";
    buildInputs = (with prev.xorg; [ libX11 libXft ]) ++ [ prev.harfbuzz ];
    description = "Personal st (simple terminal) build with custom patches";
  };

  dmenu-enhanced = mkSucklessPackage {
    pname = "dmenu-enhanced";
    srcName = "dmenu-enhanced";
    buildInputs = (with prev.xorg; [ libX11 libXft libXinerama ]);
    description = "Custom dmenu fork with personal tweaks";
  };

  dwmblocks-enhanced = mkSucklessPackage {
    pname = "dwmblocks-enhanced";
    srcName = "dwmblocks-enhanced";
    buildInputs = with prev.xorg; [ libX11 ];
    description = "Personal dwmblocks build";
  };

  slock-enhanced = mkSucklessPackage {
    pname = "slock-enhanced";
    srcName = "slock-enhanced";
    buildInputs = [ prev.pam prev.xorg.libX11 ];
    description = "Personal slock fork";
  };

  sbs = mkSucklessPackage {
    pname = "sbs";
    srcName = "sbs";
    buildInputs = (with prev; [
      harfbuzz
      imlib2
      libconfig
      libdrm
      libev
      pcre
      pixman
    ]) ++ (with prev.xorg; [
      libX11
      libXrandr
      libXrender
      xcbutilimage
      xcbutilrenderutil
    ]);
    extraNativeBuildInputs = [ prev.meson prev.ninja ];
    description = "Status bar utilities";
  };
}
