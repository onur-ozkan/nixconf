{ inputs }:
final: prev:

let
  mkSucklessOverride =
    {
      basePackage,
      pname,
      srcName,
      extraBuildInputs ? [ ],
      extraNativeBuildInputs ? [ ],
    }:
    basePackage.overrideAttrs (old: {
      inherit pname;
      version = inputs.${srcName}.rev or "git";
      src = inputs.${srcName};
      buildInputs = (old.buildInputs or [ ]) ++ extraBuildInputs;
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ extraNativeBuildInputs;
      makeFlags = (old.makeFlags or [ ]) ++ [ "PREFIX=$(out)" ];
      installFlags = (old.installFlags or [ ]) ++ [ "PREFIX=$(out)" ];
    });
in {
  dwm-enhanced = mkSucklessOverride {
    basePackage = prev.dwm;
    pname = "dwm-enhanced";
    srcName = "dwm-enhanced";
  };

  st-enhanced = mkSucklessOverride {
    basePackage = prev.st;
    pname = "st-enhanced";
    srcName = "st-enhanced";
    extraBuildInputs = [ prev.harfbuzz ];
  };

  dmenu-enhanced = mkSucklessOverride {
    basePackage = prev.dmenu;
    pname = "dmenu-enhanced";
    srcName = "dmenu-enhanced";
  };

  dwmblocks-enhanced = mkSucklessOverride {
    basePackage = prev.dwmblocks;
    pname = "dwmblocks-enhanced";
    srcName = "dwmblocks-enhanced";
  };

  slock-enhanced = mkSucklessOverride {
    basePackage = prev.slock;
    pname = "slock-enhanced";
    srcName = "slock-enhanced";
    extraBuildInputs = [ prev.xorg.libXrandr ];
  };

  sbs = prev.stdenv.mkDerivation rec {
    pname = "sbs";
    version = inputs.sbs.rev or "git";
    src = inputs.sbs;

    nativeBuildInputs = with prev; [ meson ninja pkg-config ];
    buildInputs =
      (with prev; [
        harfbuzz
        imlib2
        libconfig
        libdrm
        libev
        pcre
        pixman
      ])
      ++ (with prev.xorg; [
        libX11
        libXrandr
        libXrender
        xcbutilimage
        xcbutilrenderutil
      ]);

    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      meson setup builddir --prefix=$out
      ninja -C builddir
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      ninja -C builddir install
      runHook postInstall
    '';
  };
}
