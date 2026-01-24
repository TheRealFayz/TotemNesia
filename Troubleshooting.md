### Debug Mode
Enable debug mode in the options menu to see detailed information about:
- When individual totems are summoned
- When totems fade or die
- Combat state changes
- Totem recall events
- Element categorization
- Distance warnings
- Weapon enchant detection and timing
- Sequential totem casting (v4.0+)

This is useful for troubleshooting or understanding how the addon tracks your totems.

## Troubleshooting

**The Totemic Recall icon appears but nothing happens when I click it**
- Make sure "Lock UI Frame" is checked in options
- Enable debug mode and check for error messages
- Verify you have Totemic Recall learned

**The icon shows even when I don't have totems**
- Enable debug mode to see when the addon detects totems
- Make sure you're running the latest version.
- Try `/reload` to reset the addon state

**The icon doesn't appear after combat**
- Verify you actually placed totems during or before combat
- Enable debug mode to see if totems are being detected
- Check if "Hide UI element" is enabled in options
- Verify the addon is enabled for your current group type (Solo/Parties/Raids)
- Check if distance tracking triggered it earlier (it may have already shown)

**The weapon enchant icon doesn't show**
- Apply a weapon enchant from the flyout menu (icon only appears after using the flyout)
- Check that "Hide Weapon Enchant Slot" is not enabled
- Enable debug mode to see weapon enchant detection messages
- Note: Icon won't show on login/reload for existing enchants (API limitation)

**The weapon enchant timer is wrong**
- Timer uses the game's API and should be accurate
- Enable debug mode to see "Weapon enchant detected, expires in X seconds"
- Try `/reload` if the timer seems stuck

**Sequential totem casting doesn't work (v4.0+)**
- Make sure you have totems assigned to Totem Bar slots (Ctrl-click in flyouts)
- Check ESC > Key Bindings > TotemNesia to verify keybind is set
- Enable debug mode to see "Sequential cast: [element] - [totem name]"
- If it says "No totem assigned", you need to assign totems to slots first

**Sequential cast keeps resetting to Fire**
- This is normal if you wait more than 5 seconds between presses
- The auto-reset prevents confusion when you come back later
- Press the key 4 times quickly to drop all totems

**Totem sets keybind only casts one totem at a time**
- This is normal if you don't have nampower client mod installed
- Spam the keybind 4 times to cast all totems (Fire→Earth→Water→Air)
- Each keypress respects Vanilla WoW's one-spell-per-keypress limitation
- With nampower, all 4 cast instantly with one keypress

**Gold borders don't show on my selected totems**
- Make sure you're on the "Totem Sets" tab in settings
- Click the set number button (1-5) to switch between sets
- Borders only appear for totems assigned to the currently selected set
- Try `/reload` if borders seem stuck

**My totem set assignments aren't saving**
- Assignments save automatically when you click a totem
- Check that you don't have multiple WoW clients running
- Try `/reload` after making changes
- Verify your WTF folder isn't read-only

**Icons show question marks in totem sets tab**
- This happens on fresh login before spellbook loads
- Should auto-fix after a few seconds
- Try `/reload` if icons stay as question marks
- Enable debug mode to see "Refreshed X totem icons" message

**The totem tracker isn't showing my totems**
- Make sure "Hide Totem Tracker" is unchecked in options
- Enable debug mode to see what totems are being tracked
- Verify the totems are actually active (some expire quickly)

**Totem tracker shows wrong totems**
- This shouldn't happen, but enable debug mode to see what's being tracked
- The addon parses combat log messages - make sure you're seeing totem cast messages
- Try `/reload` to reset

**The flyout menus won't open**
- Make sure you're mousing over the actual slot, not the space between slots
- Check that "Hide Totem Bar" is not enabled
- Try `/reload` if menus seem stuck

**Ctrl-click doesn't assign totems**
- Make sure you're holding Ctrl while clicking
- Ctrl-click does NOT work for weapon enchants (they're click-to-cast only)
- Enable debug mode to see if assignment is being detected
- Try `/reload` and reassign

**Tooltips don't show or show incorrect information**
- Make sure you have the totem spell learned in your spellbook
- Some totems may not have proper tooltip data - this is normal
- Enable debug mode if you see errors

**I can't move the frames**
- Open options (`/tn`) and uncheck the appropriate lock option
- Make sure you're dragging from the frame itself
- Try `/reload` if frames seem stuck

**The Totemic Recall icon doesn't hide when I re-lock it**
- This is expected if you have an active countdown timer running
- The icon will hide once the timer expires or you leave combat without totems
- You can also hide it by checking "Hide UI element"

**The elemental indicators don't match my totems**
- Enable debug mode to see how totems are being categorized
- Make sure you're using the standard totem names (not renamed by other addons)
- Some totems may be categorized unexpectedly - report these as bugs

**The addon isn't working in my group**
- Check the "Will be enabled when in" settings
- Make sure the checkbox for your current group type (Solo/Parties/Raids) is checked
- All options are enabled by default

**Distance alerts trigger too often/not often enough**
- Distance threshold is set at 30 yards (standard totem range)
- This is working as intended to prevent range loss
- If you're frequently moving in combat, alerts help you reposition totems