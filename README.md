# TotemNesia

**A comprehensive totem management addon for Shaman in OctoWoW**

TotemNesia helps Shamans efficiently manage their totems by providing visual feedback, quick-cast functionality, and a clickable notification to recall totems after leaving combat. The addon intelligently tracks all your active totems with a dynamic tracker bar, provides instant access to your favorite totems through a quick-cast bar, and monitors your distance from placed totems. **Never be that Shaman that causes an accidental totem pull again.**

## What's New in 2.0

Version 2.0 is a big rewrite of how the addon is put together. The old single `TotemNesia.lua` file is now split into separate files by feature, which makes the addon much easier to maintain and fix going forward.

- `Core.lua` - shared setup, saved settings, and helpers
- `Recall.lua` - recall notification and totem distance checks
- `TotemBar.lua` - totem bar, flyouts, shield and weapon slots
- `Options.lua` - settings window and minimap button
- `Mana.lua` - mana alerts
- `Casting.lua` - keybind and macro casting
- `Events.lua` - game event handling

Other changes in 2.0:
- New settings window with four tabs: General, Totem Bar, Totem Sets, and Alerts
- Voice alerts for Totems, Low Mana, and Mana Potion, with three voices to choose from (Jenny, Aria, and Roger) and more to come
- Each audio alert can be muted on its own
- Totem sets now drop every totem in one press with Nampower
- Totem bar slots with no assigned totem now show the icon of the totem you have out for that element, and clear it when the totem is gone
- Weapon enchants can be assigned to the weapon slot with Ctrl-click, the same way totems are
- Clicking the weapon slot casts your assigned enchant
- When your weapon has no enchant, the weapon slot shows your assigned enchant greyed out as a reminder

**Upgrading from 1.x:** delete your old `TotemNesia` folder before installing 2.0. The old `TotemNesia.lua` is no longer used. Your settings should be maintained post update.

## Optional Client Mods

TotemNesia works on a plain client. Two client mods add extra features when they're installed:

- **Nampower** - Totem set keybinds drop every totem in the set with one press. This needs Nampower's instant spell queuing turned on. If only one totem drops per press, run this once in game:
  `/script SetCVar("NP_QueueInstantSpells", "1")`
- **SuperWoW** - Real distance to each totem instead of an estimate, and totem bar icons turn red when you're out of a totem's range.

## Features

### Totem Bar (Quick-Cast System)
- **6-slot quick-cast bar** - Fire, Earth, Water, and Air totems, plus a weapon enchant slot and a shield slot
- **Flyout menus** - Hold Shift and mouse over a slot to see every totem or enchant for it, with tooltips (the Shift requirement can be turned off)
- **Ctrl-click assignment** - Ctrl-click a flyout totem to put it in the slot (saved between sessions)
- **Fallback totems** - Alt-click a flyout totem to make it the slot's fallback. It's cast instead when the slot totem is on cooldown. Alt-click it again to clear it.
- **Always an icon** - A slot with no assigned totem shows the totem you currently have out for that element
- **Duration timers** - Shows countdown for active totems and weapon enchants
- **Range warning** - With SuperWoW, a slot's icon turns red when you're out of that totem's range
- **Flexible layouts** - Horizontal or Vertical orientation, with flyouts opening up, down, left, or right
- **Independent controls** - Separate lock, hide, and scale settings
<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar%20Closed.png?raw=true">

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar.png?raw=true">

### Water Slot Cleansing Modes
- **Right-click the water slot** to cycle Anti-Poison, Anti-Disease, and off
- **Anti-Poison (P)** and **Anti-Disease (D)** swap the water slot to Poison Cleansing Totem or Disease Cleansing Totem, so it's one click away during poison or disease heavy fights
- The mode letter shows on the slot so you always know which one is active

### Weapon Enchant Slot (5th Slot)
- **Automatic icon display** - Shows your currently active weapon enchant
- **Flyout menu** - Access all weapon enchants (Rockbiter, Flametongue, Frostbrand, Windfury)
- **Click-to-cast** - Click enchants in the flyout to apply them
- **Ctrl-click assignment** - Ctrl-click an enchant in the flyout to make it the slot's enchant (saved between sessions)
- **One-click reapply** - Click the weapon slot to cast your assigned enchant
- **Missing enchant reminder** - With no enchant on your weapon, the slot shows your assigned enchant greyed out
- **Duration timer** - Countdown in minutes (30m, 1m) or seconds (59, 30, 1) when under 1 minute
- **Hide option** - Optional checkbox to hide this slot if not needed

### Shield Slot (6th Slot)
- **Click to recast** - Click the slot, or use the Recast Shield keybind, to recast your shield
- **Pick your shield** - Choose which shield the slot tracks from its flyout
- **Charge count** - Shows how many charges your shield has left
- **Missing shield reminder** - The icon greys out when your shield is gone
- **Low charge flash** - Optional flashing border when your shield is about to run out
- **Hide option** - Optional checkbox to hide this slot if not needed

### Totem Sets
- **5 configurable sets** - Create up to 5 different totem combinations for various situations
- **Visual assignment interface** - Click totems to assign one from each family (Fire, Earth, Water, Air) to each set
- **Gold border highlighting** - Selected totems show a gold border for easy identification
- **Quick-switch selector** - Buttons to switch between sets instantly
- **Individual keybinds** - Set up separate keybinds for each of the 5 totem sets in ESC > Key Bindings > TotemNesia
- **Adaptive casting modes:**
  * **With Nampower**: Press the keybind once to drop every totem in the set
  * **Without Nampower**: Press the keybind repeatedly to cast the set one totem at a time (Fire, Earth, Water, Air). The order resets to Fire after 10 seconds without a press.
- **Works with cleansing modes and fallbacks** - Set casting follows the water slot's cleansing mode and uses fallback totems when a totem is on cooldown
- **Persistent storage** - All set configurations saved between sessions

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/1%20button%20totems.gif?raw=true">

### Distance Tracking
- **Automatic alerts** - The recall notification pops up when you move too far from your totems
- **Adjustable range** - Choose anywhere from 10 to 40 yards (30 by default)
- **Works in combat** - Prevents totem loss during mobile fights
- **Smart monitoring** - Checks distance every 0.5 seconds without impacting performance

### Totem Tracker Bar
- **Real-time totem display** - Shows icons and duration timers for all currently active totems
- **Automatic updates** - Icons appear when totems are placed, disappear when they expire or are recalled
- **Flexible layouts** - Horizontal or Vertical orientation with 20x20 pixel icons
- **Elemental indicators** - 16x16 pixel indicators positioned to match in-game totem layout
- **Fully customizable** - Drag to position, lock in place, hide completely, or scale from 50% to 200%

### Totemic Recall Notification
- **Clickable interface** - Click the icon to instantly recall all totems
- **Keybind support** - Create a macro to recall totems with a hotkey
- **Countdown timer** - Adjustable 15-60 second countdown before auto-hide
- **Elemental indicators** - Small corner icons show which element totems are active
  - Fire (top-left), Earth (top-right), Air (bottom-left), Water (bottom-right)
- **Combat-aware** - Automatically hides when you re-enter combat
- **Voice alert** - Optional spoken alert when the notification appears
- **Scalable** - Adjust size from 50% to 200%
- Shows up once you're level 10 and have learned Totemic Recall

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totemic%20Recall.png?raw=true">

### Voice and Mana Alerts
- **Three voices** - Jenny, Aria, and Roger, with more to come. Every alert uses the voice you pick.
- **Test button** - Hear the selected voice before you commit to it
- **Totems alert** - Plays with the recall notification
- **Low mana alert** - Plays when your mana drops below a threshold you set (30% by default)
- **Mana potion alert** - A second threshold to remind you to use a potion (30% by default)
- **Separate mutes** - Mute any of the three alerts on its own
- **No spam** - Each alert has a 30 second cooldown and only plays when you cross below the threshold. Set a threshold to 0% to turn that alert off.
- **Public mana message** - At 15% mana, says "I am low on mana, I need to drink." in /say so your group knows. Can be turned off.

### Smart Detection
- **Combat log tracking** - Monitors individual totem summons and expirations
- **Fire Nova handling** - Intelligently ignores self-destructing Fire Nova Totems
- **Element categorization** - Automatically identifies Fire, Water, Earth, and Air totems
- **Efficient updates** - All visual elements update every 0.5 seconds

## Settings

Click the minimap button to open the settings window. Right-click and drag the button to move it. Settings are split into four tabs:

- **General** - Recall notification, totem tracker, totem range, which group types the addon runs in (solo, party, raid), keybind help, the recall macro, and debug mode
- **Totem Bar** - Enable, lock, slot options, layout, flyout direction, scale, and a quick guide to the bar's clicks
- **Totem Sets** - Build your 5 totem sets
- **Alerts** - Voice choice, alert mutes, mana thresholds, and the public mana message

## Keybinds

Found in ESC > Key Bindings > TotemNesia:

- **Totem Set 1-5** - Cast a totem set
- **Totem Bar 1-4 (Fire, Earth, Water, Air)** - Cast the totem in that bar slot
- **Recast Shield** - Recast your shield

To recall totems with a key, make a macro with `/script TotemNesia_RecallTotems()` and put it on your action bar. The macro text is also on the General tab, ready to copy.

## Technical Details

### Why Click Instead of Automatic?
Vanilla WoW (1.12) has API restrictions that prevent addons from automatically casting spells outside of combat without player input. TotemNesia works around this by:
- Detecting active totems via combat log parsing
- Providing a clickable UI element that counts as player-initiated input
- Allowing you to recall totems with a single click instead of manually casting
- Helping keep Shamans from forgetting their totems and causing accidental pulls

### Weapon Enchant Detection
The weapon enchant system uses the `GetWeaponEnchantInfo()` API to detect active enchants and their expiration times. Because weapon enchants don't show as scannable buffs in Vanilla WoW, the addon reads the enchant name from your main hand weapon's tooltip to work out which one is active. That means the correct icon shows up even after a reload or login. If the tooltip can't be read, it falls back to the last enchant you cast from the flyout or the weapon slot.

### Totem Sets and Nampower
The totem sets system stores 5 independent configurations in `TotemNesiaDB.totemSets`, each containing one totem from each family. On login, the addon calls `GetNampowerVersion()` to check whether Nampower is installed.

With Nampower, a set keybind casts every totem in the set during the same key press. Each totem is cast with `CastSpell()` using its spellbook index, the same way an action bar button casts it, and Nampower queues them so they all land. This needs Nampower's `NP_QueueInstantSpells` setting turned on.

Without Nampower, the client only allows one spell per key press, so each press casts the next totem in order (Fire, Earth, Water, Air). The addon remembers which totem is next and resets to Fire after 10 seconds without a press. This requires the `Bindings.xml` file to be present for keybind registration.

### Adding Voices
Voice files live in the `Sounds` folder and are named `<Alert> - <Voice>.mp3`, for example `Totems - Jenny.mp3`. Each voice needs three files: `Totems`, `Low Mana`, and `Mana Potion`. To add a voice, drop in its three files and add the name to the `TNC.VOICES` list in `Core.lua`.

## Contributing

Found a bug or have a feature request? Please submit an issue on the GitHub repository.

## License

This addon is provided as-is for use with OctoWoW.  If you wish to make edits or forks to the code, please feel free to reach out. 

## Credits

Special thanks to all the beta testers and community members who provided feedback during development.

**Enjoy your enhanced totem management, and may your totems always be where you need them!**
