{ inputs }:
final: prev:

{
  dwm-enhanced = prev.dwm.overrideAttrs (_: rec {
    pname = "dwm-enhanced";
    version = inputs.dwm-enhanced.rev or "git";
    src = inputs.dwm-enhanced;
  });

  st-enhanced = prev.st.overrideAttrs (old: rec {
    pname = "st-enhanced";
    version = inputs.st-enhanced.rev or "git";
    src = inputs.st-enhanced;
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.harfbuzz ];
  });

  dmenu-enhanced = prev.dmenu.overrideAttrs (_: rec {
    pname = "dmenu-enhanced";
    version = inputs.dmenu-enhanced.rev or "git";
    src = inputs.dmenu-enhanced;
  });

  dwmblocks-enhanced = prev.dwmblocks.overrideAttrs (_: rec {
    pname = "dwmblocks-enhanced";
    version = inputs.dwmblocks-enhanced.rev or "git";
    src = inputs.dwmblocks-enhanced;
  });

  slock-enhanced = prev.slock.overrideAttrs (old: rec {
    pname = "slock-enhanced";
    version = inputs.slock-enhanced.rev or "git";
    src = inputs.slock-enhanced;
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.xorg.libXrandr ];
  });

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
