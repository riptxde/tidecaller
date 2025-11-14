# Settings

Tidecaller settings are stored in `workspace/tidecaller/settings.json` and can be changed via commands or by editing the file directly.

## Available Settings

| Setting | Description | Default | Command |
|---------|-------------|---------|---------|
| Hotkey | Key to open command palette | `Quote` (') | `changehotkey` |
| Prefix | Chat command prefix | `'` (Single Quote) | `changeprefix` |

?> Changes to hotkey and prefix take effect immediately.

## Hotkey

The hotkey toggles the command palette open and closed.

### Changing the Hotkey

```lua
changehotkey <keycode>
```

**Examples:**
```lua
changehotkey Backslash
changehotkey F1
changehotkey Semicolon
```

### Valid KeyCodes

The hotkey must be a valid Roblox `Enum.KeyCode` name.

The command palette's *auto-complete* lists the majority of common valid keycodes, however you can check the [Roblox KeyCode Documentation](https://create.roblox.com/docs/reference/engine/enums/KeyCode) for all valid keycodes.

**Note:** Avoid keys commonly used in games (WASD, Space, Shift, etc.) to prevent conflicts.

## Prefix

The prefix identifies commands in chat and appears in the input box placeholder.

### Changing the Prefix

```lua
changeprefix <prefix>
```

**Examples:**
```lua
changeprefix /
changeprefix ;
changeprefix .
changeprefix cmd
```

### Using in Chat

Type the prefix followed by a command:

```
'notify "Hello" "From chat"
/notify "Hello" "From chat"
;notify "Hello" "From chat"
```

?> Note that the input box in your command palette also accepts commands which use your current prefix, however it isn't necessary.

### Special Prefixes

Prefixes can be escaped with quotes. This is extremely useful for,

Prefixes with spaces:
```lua
changeprefix "tc "
```

Or, prefixes with quotes in them (for example, if you're trying to revert to the default prefix of `'`):
```lua
changeprefix "'"
```
