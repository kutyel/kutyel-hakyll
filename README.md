# hakyll-nix-template

[![Github Actions](https://github.com/kutyel/kutyel-hakyll/actions/workflows/main.yml/badge.svg)](https://github.com/kutyel/kutyel-hakyll/actions/workflows/main.yml)
[![NixCI Badge](https://nix-ci.com/badge/gh:kutyel:kutyel-hakyll)](https://nix-ci.com/account/repo/gh:kutyel:kutyel-hakyll/suite/main)

[Hakyll](https://jaspervdj.be/hakyll/) + [Nix](https://nixos.org) template

## Features

- Build your site into the `./result/dist` folder:
  ```
  λ nix build
  ```
- Start hakyll's dev server that reloads when changes are made:
  ```
  λ nix run . watch
  Listening on http://127.0.0.1:8000
  ...more logs
  ```
- Run any hakyll command through `nix run .`!
  ```
  λ nix run . clean
  Removing dist...
  Removing ssg/_cache...
  Removing ssg/_tmp...
  ```
- Start a development environment that

  - has your shell environment
  - has `hakyll-site` (for building/watching/cleaning hakyll projects)
  - has `hakyll-init` (for generating new projects)
  - can have anything else you put in the `shell.buildInputs` of the
    `hakyllProject` in `flake.nix`
  - is set up to run `ghci` with some defaults and the modules loaded so you can
    make your own changes and test them out in the ghci REPL

  ```
  λ nix develop

  [hakyll-nix]λ hakyll-site build
  ...
  Success

  [hakyll-nix]λ ghci
  ...
  [1 of 1] Compiling Main    ( ssg/src/Main.hs, interpreted )
  ...

  λ >
  ```

### hakyll

All of this is custmomizable, and here are some things that are already done for
you:

- [pandoc](https://github.com/jgm/pandoc/) markdown customization to make it as
  close to GitHub's markdown style as possible
- [`slugger`](https://hackage.haskell.org/package/slugger) module is included that makes nice link URIs based on post titles
- RSS & Atom XML feed generation
- Sitemap generation
- Code syntax highlighting customization
- ...other reasonable defaults

Configure the dev server, cache & tmp directories, and more in
`./ssg/src/Main.hs`.

### Deployment

Deployment is set up through a [GitHub
Action](https://github.com/features/actions) with [cachix](https://cachix.org),
and it deploys to a [GitHub Pages](https://pages.github.com/) branch,
`gh-pages`, when you merge code into your main branch.

Setup information can be found below in the "Cachix" section.

Note: If your main branch's name isn't `main`, ensure `'refs/heads/main'` gets
updated to `'refs/heads/my-main-branch'` in `./github/workflows/main.yml`.

## Setup

### Nix & Flakes

If you don't have [nix](https://nixos.org), follow [the nix installation
instructions](https://nixos.org/download.html).

Once you have nix installed, follow the instructions here to get access to
flakes: https://nixos.wiki/wiki/Flakes.

### Editor integration (HLS)

[Haskell Language Server](https://github.com/haskell/haskell-language-server)
needs to run inside this project's Nix dev shell (which provides the matching
GHC, the site's dependencies, HLS, `hlint`, and `ormolu`) to work in your
editor. Two ways to wire that up:

* **VS Code — Nix Env Selector (simplest).** Install the [Nix Env
  Selector](https://marketplace.visualstudio.com/items?itemName=arrterian.nix-env-selector)
  extension; this repo's `.vscode/settings.json` already points it at
  `shell.nix` (which re-exports the flake's dev shell). No extra system tooling
  required — this is what the bundled `.vscode/` recommends.
* **Any editor / terminal — direnv (editor-agnostic).** Install
  [`direnv`](https://direnv.net) and
  [`nix-direnv`](https://github.com/nix-community/nix-direnv), then run `direnv
  allow` in this directory. The bundled `.envrc` (`use flake`) loads the dev
  shell in your terminal and any editor with direnv integration (Emacs `envrc`,
  vim, etc.).

Both reuse the single dev-shell definition in `flake.nix`, and HLS loads the
Haskell project from `ssg/` automatically.

This repo ships `.vscode/` defaults: on first open, VS Code recommends the
[Haskell](https://marketplace.visualstudio.com/items?itemName=haskell.haskell)
and [Nix Env
Selector](https://marketplace.visualstudio.com/items?itemName=arrterian.nix-env-selector)
extensions; `.vscode/settings.json` points Nix Env Selector at `shell.nix` and
sets `haskell.manageHLS` to `"PATH"` so the Haskell extension uses HLS from the
Nix dev shell rather than downloading its own. That HLS bundles **hlint**, so
lint diagnostics and "Apply hint" code actions appear automatically — no
separate linter needed. Add a `.hlint.yaml` at the repo root to customize the
hlint rules (this repo already has one).

### Cachix

The `./.github/workflows/main.yml` file builds with help from
[cachix](https://app.cachix.org), so you'll need to generate a signing key to be
able to do this.

1. Create a cache on cachix for your project
1. Follow cachix's instructions to generate a signing keypair
1. Copy the signing keypair value to a new `CACHIX_SIGNING_KEY` secret on
   https://github.com/settings/secrets
