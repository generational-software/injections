# Injections

An [Omarchy](https://omarchy.org/) bar widget for checking off daily injections. The bar shows a syringe and four dots. Green means that injection is done today, blue means it is still due, and grey means that point is switched off. The first time the panel opens on a new local day, the checks clear. A later open the same day keeps them.

Open the panel and choose **Settings** to rename each injection or switch off the ones you do not take. At least one stays on. The checklist shows only the points that are on. A switched-off point stays on the bar as a grey dot.

Checks are stored on this machine at `~/.local/state/omarchy/injections/doses.json`. Names and which points are on are stored with the bar entry in `~/.config/omarchy/shell.json`.

## Install

The plugin id is `peterm.injections`.

```bash
omarchy plugin add https://github.com/generational-software/injections.git --enable --yes
```

From a git checkout of this folder, `omarchy plugin validate .` checks the manifest before you publish.

`omarchy plugin add` clones into `~/.config/omarchy/plugins/peterm.injections`. If that id is already installed, copy these files over that folder instead. The shell reloads plugin code when the files change. A new widget still needs:

```bash
omarchy plugin enable peterm.injections --section right --before omarchy.tray
```

The widget hides itself on a bar narrower than 720 logical pixels.

## Remove

```bash
omarchy plugin remove peterm.injections --yes
```

That takes the widget off the bar, including the names and on/off switches stored with it, and deletes `~/.config/omarchy/plugins/peterm.injections`. The checklist at `~/.local/state/omarchy/injections/doses.json` stays, so a later install keeps today's checks.

## License

This plugin is covered by the MIT license.
