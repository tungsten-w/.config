# Installation process

> Automated dotfiles installer for Tungsten's Hyprland setup.
> Handles package installation, config symlinking, and script setup in one run.

---

## Requirements

- An Arch-based distro (CachyOS, EndeavourOS, Manjaro, Arch, Garuda)
- `paru` or `yay` installed (required only if you want to install packages)
- Bash 5+

---

## What it does

The script runs three steps in order:

### 1. Package installation *(optional)*

If you answer `y` at the prompt, it will install the following packages via your AUR helper:

```
hyprland  hyprpanel  rofi  ghostty  awww  hyprlock
cava  playerctl  grim  slurp  hyprshot  nwg-look
ttf-jetbrains-mono-nerd
```

Uses `--needed` so already-installed packages are skipped.
Uses `--noconfirm` so no manual confirmation is required.

### 2. Config symlinking

Symlinks each config folder from the repo into `~/.config/`:

| Source (repo)       | Destination              |
|---------------------|--------------------------|
| `hypr/`             | `~/.config/hypr/`        |
| `hyprpanel/`        | `~/.config/hyprpanel/`   |
| `rofi/`             | `~/.config/rofi/`        |
| `ghostty/`          | `~/.config/ghostty/`     |
| `awww/`             | `~/.config/awww/`        |
| `.tmux.conf`        | `~/.tmux.conf`           |

**If a config folder already exists** and is not already a symlink, it is backed up as `foldername.bak` before being replaced.

**If a source folder is missing** from the repo (e.g. you cloned a partial version), it is skipped with a warning — the script does not crash.

### 3. Scripts setup

Makes every script in `.scripts/` executable via `chmod +x`.
The scripts stay in place at `~/.config/.scripts/` — nothing is moved or copied.

To use them from anywhere in your terminal, make sure `~/.config/.scripts` is in your PATH.
If you use Fish, add this to your `config.fish`:

```fish
fish_add_path ~/.config/.scripts
```

---

## Usage 🩷

```bash
git clone https://github.com/tungsten-w/.config ~/.config
cd ~/.config/install-w
chmod +x install.sh
bash install.sh
```

Then follow the prompt:

```
Install AUR packages? [y/N]
```

```
Install hyprpanel as main bar [y/N]
```
Answer `y` to install everything, `N` to only set up symlinks and scripts.

---

## After install

Relaunch Hyprland to apply all changes:

```bash
hyprctl reload
# or simply log out and back in
```

---


## Notes

- The script uses `set -e`: it stops immediately if any critical command fails.
- Symlinking means updates from `git pull` are applied automatically — no need to re-run the installer.
- This installer does **not** set up Fish config, Spicetify, or Hyprpanel themes. Those are manual steps documented in the main README.
- if you have any problem during the instlalation process you can dm me on discord: ```@tungsten.inc```
