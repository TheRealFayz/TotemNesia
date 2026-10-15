# TotemNesia

**A totem management addon for Shaman in OctoWoW**

TotemNesia tracks your totems, gives you a quick-cast totem bar, and reminds you to recall your totems after combat or when you walk away from them. **Never be that Shaman that causes an accidental totem pull again.**

## What's New in 2.0

- The addon is split into separate files by feature, which makes it much easier to maintain and fix
- New settings window with four tabs: General, Totem Bar, Totem Sets, and Alerts
- Voice alerts with four voices to choose from (Jenny, Aria, Roger, and Libby), with more to come
- New aggro alert, plus group announcements for low mana, aggro, and line of sight
- Totem sets drop every totem in one press with Nampower
- Weapon enchants can be assigned to the weapon slot with Ctrl-click, just like totems

**Upgrading from 1.x:** delete your old `TotemNesia` folder before installing 2.0. Your settings should be maintained post update.

## Features

### Totem Bar
A 6-slot quick-cast bar: Fire, Earth, Water, and Air totems, plus a weapon enchant slot and a shield slot.
- **Flyouts** - Hold Shift and mouse over a slot to pick from every totem or enchant for it
- **Ctrl-click** a flyout totem or enchant to assign it to the slot
- **Alt-click** a flyout totem to make it the slot's fallback, cast when the slot totem is on cooldown
- **Right-click the water slot** to cycle Anti-Poison (P), Anti-Disease (D), and off
- **Weapon slot** - Click to reapply your assigned enchant. Greys out when your weapon has no enchant.
- **Shield slot** - Click to recast your shield. Shows charges left and can flash when you're low.
- **Timers** on every slot, and a slot with no assigned totem shows the one you have out
- Horizontal or vertical layout, lock, hide, and scale options

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar%20Closed.png?raw=true">

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar.png?raw=true">

### Totem Sets
- Save up to 5 sets with one totem from each element
- Each set has its own keybind
- **With Nampower:** one press drops the whole set
- **Without Nampower:** each press drops the next totem in the set (Fire, Earth, Water, Air)

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/1%20button%20totems.gif?raw=true">

### Totemic Recall Notification
- Pops up after combat, or when you move too far from your totems (10 to 40 yards, 30 by default)
- Click it to recall all your totems
- Corner icons show which elements you have out
- Shows up once you're level 10 and have learned Totemic Recall

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totemic%20Recall.png?raw=true">

### Totem Tracker
A small bar that shows every active totem with its timer. It can be moved, locked, hidden, or scaled.

### Alerts
- **Voice alerts** for recalling totems, low mana, mana potions, and aggro. Pick a voice and use the play button to hear it.
- **Mana thresholds** - Set when the low mana and potion alerts play
- **Aggro alert** - "You have aggro!" on screen plus a voice cue when a mob is attacking you in a group
- **Group announcements** - Low mana, aggro, and line of sight messages go to party or raid chat (never /say). Each one, and parties or raids as a whole, can be turned off.
- Every alert sound and announcement can be turned on or off on its own

## Settings and Keybinds

Click the minimap button to open the settings window (right-click and drag to move the button).

- **General** - Recall notification, totem tracker, totem range, which group types the addon runs in, and debug mode
- **Totem Bar** - Slots, layout, flyout direction, and scale
- **Totem Sets** - Build your 5 sets
- **Alerts** - Voice, alert sounds, mana thresholds, aggro alert, and group announcements

Keybinds are in ESC > Key Bindings > TotemNesia: Totem Set 1-5, Totem Bar 1-4, and Recast Shield. To recall totems with a key, put `/script TotemNesia_RecallTotems()` in a macro.

## Optional Client Mods

TotemNesia works on a plain client. These add extras when installed:

- **Nampower** - One-press totem sets. If Nampower's instant spell queuing is off, TotemNesia turns it on for that key press and puts your setting back right after.
- **SuperWoW** - Real distance to each totem, red totem bar icons when you're out of range, and an aggro alert that can see mobs nobody has targeted (enemy nameplates need to be on)

## For Developers

Each feature lives in its own file: `Core.lua`, `Recall.lua`, `TotemBar.lua`, `Options.lua`, `Mana.lua`, `Alerts.lua`, `Casting.lua`, and `Events.lua`.

To add a voice, put four files in `Sounds` named `Totems - Name.mp3`, `Low Mana - Name.mp3`, `Mana Potion - Name.mp3`, and `Aggro - Name.mp3`, then add the name to `TNC.VOICES` in `Core.lua`.

## Feedback

Found a bug or have a feature request? Please open an issue on GitHub.

This addon is provided as-is for use with OctoWoW. If you'd like to edit or fork it, feel free to reach out.

Special thanks to all the testers and community members who gave feedback during development.

**May your totems always be where you need them!**
