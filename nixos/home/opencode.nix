{
  lib,
  resolvePath,
  ...
}: let
  # st-enhanced cannot answer the palette queries used by OpenCode's system
  # theme. Read the same Xresources file as st, including local overrides.
  palette = builtins.listToAttrs (lib.concatMap (line: let
    match = builtins.match ''\*\.([[:alnum:]]+):[[:space:]]*(#[[:xdigit:]]{6})[[:space:]]*'' line;
  in
    lib.optional (match != null) {
      name = builtins.elemAt match 0;
      value = builtins.elemAt match 1;
    }) (lib.splitString "\n" (builtins.readFile (resolvePath ".Xresources"))));
in {
  home.file.".config/opencode/tui.json".source = resolvePath ".config/opencode/tui.json";

  home.file.".config/opencode/themes/terminal.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/theme.json";
    defs = palette;
    theme = {
      primary = "color4";
      secondary = "color5";
      accent = "color3";
      error = "color1";
      warning = "color3";
      success = "color2";
      info = "color4";
      text = "foreground";
      textMuted = "color8";
      selectedListItemText = "background";

      # Keep all surfaces on the terminal background. Explicit colors also
      # work when terminal-default/transparent color detection is unavailable.
      background = "background";
      backgroundPanel = "background";
      backgroundElement = "background";
      backgroundMenu = "background";
      border = "color8";
      borderActive = "color4";
      borderSubtle = "color8";

      diffAdded = "color2";
      diffRemoved = "color1";
      diffContext = "foreground";
      diffHunkHeader = "color4";
      diffHighlightAdded = "color10";
      diffHighlightRemoved = "color9";
      diffAddedBg = "background";
      diffRemovedBg = "background";
      diffContextBg = "background";
      diffLineNumber = "color8";
      diffAddedLineNumberBg = "background";
      diffRemovedLineNumberBg = "background";

      markdownText = "foreground";
      markdownHeading = "color4";
      markdownLink = "color4";
      markdownLinkText = "color3";
      markdownCode = "color2";
      markdownBlockQuote = "color8";
      markdownEmph = "color3";
      markdownStrong = "foreground";
      markdownHorizontalRule = "color8";
      markdownListItem = "color4";
      markdownListEnumeration = "color3";
      markdownImage = "color4";
      markdownImageText = "color3";
      markdownCodeBlock = "foreground";

      syntaxComment = "color8";
      syntaxKeyword = "color5";
      syntaxFunction = "color4";
      syntaxVariable = "foreground";
      syntaxString = "color2";
      syntaxNumber = "color3";
      syntaxType = "color3";
      syntaxOperator = "color5";
      syntaxPunctuation = "foreground";
    };
  };
}
