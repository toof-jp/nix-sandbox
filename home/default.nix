{ pkgs, lib, inputs, ... }:

let
  dotfiles = inputs.dotfiles;

  # lazy.nvim writes lazy-lock.json with a plain `io.open(path, "wb")`,
  # which follows symlinks and truncates the target in place — that fails
  # with "Read-only file system" for anything symlinked into the Nix
  # store, no matter how the containing directory is linked. So
  # lazy-lock.json is stripped out of the managed tree entirely and
  # seeded separately as a real, freely-writable file (see
  # home.activation.seedLazyLock below).
  luaNvimManaged = pkgs.runCommand "lua-nvim-managed" { } ''
    mkdir -p $out
    cp -r --no-preserve=mode ${dotfiles}/.config/lua-nvim/. $out/
    rm -f $out/lazy-lock.json
  '';
in
{
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    fzf
    starship
    mise
    gnupg
    git
    kubectl
    krew
    k9s
    bat
    gomi
    gh
    tree
    ghq
    neovim
    tmux
    difftastic
    zsh
    claude-code
    codex
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];

  # zsh — reproduced verbatim from ../dotfiles, including the herdr autostart
  # line and vite-plus env sourcing (vite-plus itself is not packaged; that
  # line is a harmless no-op unless its installer has also been run by hand).
  home.file.".zshrc".source = "${dotfiles}/.zshrc";
  home.file.".zsh/git-prompt.sh".source =
    "${pkgs.git}/share/git/contrib/completion/git-prompt.sh";

  xdg.configFile."starship.toml".source = "${dotfiles}/.config/starship.toml";

  xdg.configFile."git/config".source = "${dotfiles}/.config/git/config";
  xdg.configFile."git/gpg.config".source = "${dotfiles}/.config/git/gpg.config";
  xdg.configFile."git/ignore".source = "${dotfiles}/.config/git/ignore";

  xdg.configFile."tmux".source = "${dotfiles}/.config/tmux";

  xdg.configFile."nvim".source = "${dotfiles}/.config/nvim";

  # recursive = true makes ~/.config/lua-nvim a real, writable directory
  # containing per-file symlinks, instead of one symlink for the whole
  # tree. lazy-lock.json is excluded from luaNvimManaged so nothing is
  # symlinked at that path at all — see the comment above.
  xdg.configFile."lua-nvim" = {
    source = luaNvimManaged;
    recursive = true;
  };

  home.file.".cargo/config.toml".source = "${dotfiles}/.cargo/config.toml";
  xdg.configFile."rustfmt".source = "${dotfiles}/.config/rustfmt";

  home.file.".ssh/config".source = "${dotfiles}/.ssh/config";
  home.file.".ssh/config.mac".source = "${dotfiles}/.ssh/config.mac";

  xdg.configFile."claude/settings.json".source =
    "${dotfiles}/.config/claude/settings.json";
  home.file.".codex/config.toml".source = "${dotfiles}/.codex/config.toml";

  xdg.configFile."herdr/config.toml".source =
    "${dotfiles}/.config/herdr/config.toml";

  home.activation.krewImagesPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.krew}/bin/krew install images || true
  '';

  # Seed the pinned plugin versions once; left alone afterwards so
  # lazy.nvim is free to update this file itself.
  home.activation.seedLazyLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/lua-nvim/lazy-lock.json" ]; then
      $DRY_RUN_CMD install -m 0644 "${dotfiles}/.config/lua-nvim/lazy-lock.json" "$HOME/.config/lua-nvim/lazy-lock.json"
    fi
  '';
}
