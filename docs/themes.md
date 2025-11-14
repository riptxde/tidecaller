# Themes

Themes define Tidecaller's visual appearance including colors and fonts.

## Installing Themes

1. Place theme `.json` files in `workspace/tidecaller/themes/`
2. Use the `changetheme` command to activate:
   ```lua
   changetheme themename
   ```
3. Run `quit` and re-execute the script to apply the theme

?> Theme files should be named without the `.json` extension when using the command. For example, `mytheme.json` becomes `changetheme mytheme`.

## Changing Themes

```lua
changetheme <theme>
```

**Example:**
```lua
changetheme catppuccin_latte
changetheme catppuccin_mocha
```

After changing themes, run `quit` and re-execute the script to apply.

## Built-in Themes

- **catppuccin_mocha** - Dark theme (default)
- **catppuccin_latte** - Light theme

## Theme File Structure

Themes are JSON files in `workspace/tidecaller/themes/`.

**Structure:**
```json
{
    "Font": "rbxasset://fonts/families/BuilderSans.json",
    "MonoFont": "rbxasset://fonts/families/Inconsolata.json",
    "Colors": {
        "Base": [30, 30, 46],
        "Mantle": [24, 24, 37],
        "Crust": [17, 17, 27],
        "Surface0": [49, 50, 68],
        "Surface1": [69, 71, 90],
        "Surface2": [88, 91, 112],
        "Overlay0": [108, 112, 134],
        "Overlay1": [127, 132, 156],
        "Overlay2": [147, 153, 178],
        "Text": [205, 214, 244],
        "Subtext1": [186, 194, 222],
        "Subtext0": [166, 173, 200],
        "Blue": [137, 180, 250],
        "Lavender": [180, 190, 254],
        "Sapphire": [116, 199, 236],
        "Sky": [137, 220, 235],
        "Teal": [148, 226, 213],
        "Green": [166, 227, 161],
        "Yellow": [249, 226, 175],
        "Peach": [250, 179, 135],
        "Maroon": [235, 160, 172],
        "Red": [243, 139, 168],
        "Mauve": [203, 166, 247],
        "Pink": [245, 194, 231],
        "Flamingo": [242, 205, 205],
        "Rosewater": [245, 224, 220]
    }
}
```

## Creating Custom Themes

1. Create a new `.json` file in `workspace/tidecaller/themes/`
2. Copy the structure from an existing theme
3. Modify the color RGB values (0-255)
4. Activate with `changetheme yourtheme`
5. Reload to apply

### Required Colors

Themes must include all of these colors following the [Catppuccin color palette](https://catppuccin.com/palette/) standards:

**Background:**
- Base, Mantle, Crust

**Surfaces:**
- Surface0, Surface1, Surface2

**Overlays:**
- Overlay0, Overlay1, Overlay2

**Text:**
- Text, Subtext1, Subtext0

**Accents:**
- Blue, Lavender, Sapphire, Sky, Teal, Green, Yellow, Peach, Maroon, Red, Mauve, Pink, Flamingo, Rosewater

All colors must be RGB arrays: `[R, G, B]` where values are 0-255.

### Required Fonts

**Font** - Primary font for UI text

**MonoFont** - Monospace font for code/technical text

Fonts must be Roblox font family asset IDs. Various examples can be found in the [Roblox Font Documentation](https://create.roblox.com/docs/reference/engine/datatypes/Font).

**Example font values:**
```json
"Font": "rbxasset://fonts/families/BuilderSans.json"
"MonoFont": "rbxasset://fonts/families/Inconsolata.json"
```
