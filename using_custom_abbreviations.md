## Using Custom Abbreviations

ROS-e abbreviations can be customized directly in the AutoHotkey script.

### Locating the Abbreviation Map

1. Open `ros-e.ahk` in a text editor, notepad or IDE.

2. Use the editor's search function to find:

   ```text
   GetAbbreviationMap
   ```

3. Inside `GetAbbreviationMap()`, locate the abbreviation definitions. They look like this:

   ```ahk
   map["a+x+k"] := "return"
   ```

### Adding or Changing Abbreviations

Each abbreviation follows this format:

```ahk
map["key+key+key"] := "output text"
```

For example:

```ahk
map["a+x+k"] := "return"
map["a+x+l"] := "function"
map["f+j"] := "example"
```

The keys inside the quotation marks represent the **physical keys pressed simultaneously**, not the letters that ROS-e would normally produce from those keys.

You may:

* change the output text of an existing abbreviation,
* replace a default abbreviation,
* remove an abbreviation,
* or add a new abbreviation using any physical-key chord.

The order in which the physical keys are written does not matter. ROS-e automatically canonicalizes the chord before matching it.

For example, these definitions refer to the same physical-key chord:

```ahk
map["a+x+k"] := "return"
map["k+a+x"] := "return"
map["x+k+a"] := "return"
```

Only one definition for the chord is necessary.

### Applying the Changes

After editing the abbreviation map:

1. Save `ros-e.ahk`.
2. If ROS-e is already running, exit or reload the existing script.
3. Run `ros-e.ahk` again.

The modified abbreviation set will then be used.

> **Note:** Assigning an abbreviation to a physical-key chord overrides the normal ROS-e output of that chord. It is therefore recommended to choose chords that are unlikely to be needed for ordinary English spelling.
