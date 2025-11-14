# Tidecaller

> An admin script for roblox scripts executors, featuring a themable command palette, auto-complete, and a highly-extensible plugin system designed for luau developers.

## Script

```lua
loadstring(game:HttpGet('https://raw.githubusercontent.com/riptxde/tidecaller/master/tidecaller.luau'))()
```

## Usage

### Opening the Palette

Press the **`'`** key to toggle the command palette.

?> You can change this hotkey via the `changehotkey` command.

### Running Commands

Type a command name and press Enter:

```
notify hello hi!
fly
unfly
goto partial_name
```

### Using Chat

Commands can also be executed via chat using the `'` prefix:

```
'notify hello hi!
'goto player123
```

?> You can change this prefix via the `changeprefix` command.

### Keyboard Controls

| Key | Action |
|-----|--------|
| Hotkey (default `'`) | Open palette |
| `ESC` | Close palette |
| `UP` / `DOWN` | Navigate commands |
| `ENTER` | Execute command |

## Command Structure

Commands follow this format:

```
commandname [alias] [another_alias] <required_arg> <optional_arg: default> ...
```

- `[alias]` - Alternative command name
- `<argname>` - Required argument
- `<argname: auto>` - Optional argument (default value dynamically/automatically determined)
- `<argname: value>` - Optional argument (specific default value specified)

### Arguments

Arguments are separated by spaces. Use quotes for multi-word arguments:

```lua
-- Single words
notify hello world

-- Multi-word arguments (use quotes)
notify "Hello World" "This is a message"

-- Mixing both
notify "My Title" simple_message
```

### Quotes and Escaping

Use quotes when arguments contain spaces or special characters:

```lua
-- Double or single quotes
notify "Title" "Message"
notify 'Title' 'Message'

-- Use opposite quote type for nested quotes
notify "It's working!" 'She said "hello"'

-- Or escape with backslash
notify "It's \"quoted\"" "Path: C:\\Users"
```

**Escape sequences:**
- `\"` - Double quote
- `\'` - Single quote
- `\\` - Backslash

## Installing Themes

Tidecaller supports custom themes to personalize the visual appearance.

**To install a theme:**

1. Place theme `.json` files in `workspace/tidecaller/themes/`
2. Use the `changetheme` command:
   ```lua
   changetheme themename
   ```
3. Run `quit` and re-execute the script to apply

?> For more information about themes, see the [Themes documentation](/themes.md).

## Installing Plugins

Tidecaller has a powerful plugin system that allows you to extend functionality with custom commands.

**To install a plugin:**

1. Place plugin `.tc.luau` files in your executor's auto-execute folder (e.g., `autoexec/`)
2. Restart (rejoin) your game, or manually execute the plugin file

?> Plugins automatically load when your executor starts. For more information, see the [Plugin documentation](/plugins/README.md).

## Credits

**Developer:** riptxde
