# TotemNesia

**A totem management addon for Shaman in OctoWoW**

TotemNesia tracks your totems, gives you a quick-cast totem bar, and reminds you to recall your totems after combat or when you walk away from them. **Never be that Shaman that causes an accidental totem pull again.**

You can also download TotemNesia from OctoWoW's [Gitea](https://octowow.st/git/Fayz/TotemNesia).

## What's New in 2.0

- The addon is split into separate files by feature, which makes it much easier to maintain and fix
- New settings window with four tabs: General, Totem Bar, Totem Sets, and Alerts
- Voice alerts with four voices to choose from (Jenny, Aria, Roger, and Libby), with more to come
- New aggro alert, plus group announcements for low mana, aggro, and line of sight
- Totem sets drop every totem in one press with Nampower
- Weapon enchants can be assigned to the weapon slot, just like totems

**Upgrading from 1.x:** delete your old `TotemNesia` folder before installing 2.0. Your settings should be maintained post update.

## Features

### Totem Bar
A 6-slot quick-cast bar: Fire, Earth, Water, and Air totems, plus a weapon enchant slot and a shield slot.
- **Flyouts** - Hold Shift and mouse over a slot to pick from every totem or enchant for it
- **Click** a flyout totem to cast it, or **Shift + right-click** it to assign it to the slot
- **Alt-click** a flyout totem to make it the slot's fallback, cast when the slot totem is on cooldown
- **Slot modes** - Quick swaps for when a fight calls for a cleansing or Tremor totem. While a mode is on, the slot casts that totem instead of your assigned one and shows a letter on the icon. Assigning a totem to the slot turns its mode off.
  - **Water slot:** right-click to cycle Anti-Poison (P), Anti-Disease (D), and off
  - **Earth slot:** right-click to turn Tremor mode (T) on or off
- **Weapon slot** - Click to reapply your assigned enchant. Greys out when your weapon has no enchant.
- **Shield slot** - Click to recast your shield. Shows charges left and can flash when you're low.
- **Timers** on every slot, and a slot with no assigned totem shows the one you have out
- **Red** icon: you're out of that totem's range. **Blue** icon: you don't have the mana to cast it.
- **Key Bind Mode** - Hover a slot and press a key to bind it (button on the Totem Bar tab)
- Horizontal or vertical layout, lock, hide, and scale options

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar%20Closed.png?raw=true">

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar.png?raw=true">

### Totem Sets
- Save up to 5 sets with one totem from each element
- Each set has its own keybind
- **With Nampower:** one press drops the whole set
- **Without Nampower:** each press drops the next totem in the set (Fire, Earth, Water, Air)
- Totems that are already down with more than 10 seconds left are skipped, so pressing again only replaces what's missing, expiring, or left behind
- Slot modes on the totem bar apply to sets too, so a set drops Tremor or a cleansing totem while that mode is on

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

Click the minimap button or type `/tn` to open the settings window (right-click and drag to move the button). `/tn bind` starts Key Bind Mode.

- **General** - Recall notification, totem tracker, totem range, which group types the addon runs in, debug mode, and appearance
- **Totem Bar** - Slots, layout, flyout direction, scale, key bindings, and a how-to-use guide
- **Totem Sets** - Build your 5 sets
- **Alerts** - Voice, alert sounds, mana thresholds, aggro alert, and group announcements

Keybinds are in ESC > Key Bindings > TotemNesia: Totem Set 1-5, Totem Bar 1-4, and Recast Shield. To recall totems with a key, put `/script TotemNesia_RecallTotems()` in a macro.

## Optional Client Mods

TotemNesia works on a plain client. These add extras when installed:

- **Nampower** - One-press totem sets. If Nampower's instant spell queuing is off, TotemNesia turns it on for that key press and puts your setting back right after.
- **pfUI** - The settings window, totem bar, flyouts, totem tracker, and recall notification match pfUI's look. Each part can be turned off under General > Appearance.
- **SuperWoW** - Exact distance to each totem (without it, range is judged by whether the totem's buff is still on you), and an aggro alert that can see mobs nobody has targeted (enemy nameplates need to be on)

## For Developers

Each feature lives in its own file: `Core.lua`, `Recall.lua`, `TotemBar.lua`, `Options.lua`, `Mana.lua`, `Alerts.lua`, `Casting.lua`, and `Events.lua`.

To add a voice, put four files in `Sounds` named `Totems - Name.mp3`, `Low Mana - Name.mp3`, `Mana Potion - Name.mp3`, and `Aggro - Name.mp3`, then add the name to `TNC.VOICES` in `Core.lua`.

## Feedback

Something not working? Check [Troubleshooting.md](Troubleshooting.md) first. Found a bug or have a feature request? Please open an issue on GitHub.

This addon is provided as-is for use with OctoWoW. If you'd like to edit or fork it, feel free to reach out.

**Please keep forks private.** Public copies floating around make it hard for people to tell which version is the original one and where to get updates or report bugs. If you want your own copy to tinker with, please clone it into a private repo. If you have a change or feature you think everyone would benefit from, please open an issue and we can look at getting it into the main addon.

Special thanks to all the testers and community members who gave feedback during development.

**May your totems always be where you need them!**
