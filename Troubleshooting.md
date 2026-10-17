# TotemNesia Troubleshooting

Type `/tn` to open the settings window, or `/tn bind` to start Key Bind Mode.

## Updating

**After updating, the addon still acts like the old version**
- Delete your old `TotemNesia` folder before installing the new one
- Some launchers keep a cached copy of addons and put it back. Clear or refresh the launcher's copy of TotemNesia after updating.
- Do a full client restart after an update, not just `/reload`. New files are only picked up when the game starts.

## Totemic Recall Notification

**The notification never appears**
- You need to be level 10 and have learned Totemic Recall
- Check that "Hide recall notification" is off (General tab)
- Check "Enabled When In" on the General tab for your current group type (solo, party, raid)
- Make sure you actually had totems down

**Clicking the notification does nothing**
- "Lock recall notification" must be on (General tab). While it's unlocked, the notification can be dragged instead of clicked.

## Totem Sets

**A set key only drops one totem**
- One-press sets need Nampower. Without it, each press drops the next totem in the set, and that's expected.
- To check that Nampower is loaded, type `/script DEFAULT_CHAT_FRAME:AddMessage(tostring(GetNampowerVersion ~= nil))`. It should print `true`.
- TotemNesia turns on Nampower's instant spell queuing for the moment it casts a set, so nothing needs changing in Nampower's settings

**Pressing a set key skips some totems**
- Totems that are already down with more than 10 seconds left, and that you're still in range of, are skipped on purpose

## Totem Bar

**I can't assign a totem to a slot**
- Hold Shift, mouse over the slot to open its flyout, then Shift + right-click the totem. Ctrl-click no longer assigns totems.

**The water or earth slot casts a different totem than the one I picked**
- A slot mode is on. Look for a P, D, or T on the icon. Right-click the slot until the letter is gone, or assign a totem to the slot, which turns its mode off.

**An icon is red**
- You're out of that totem's range. With SuperWoW this uses real distance. Without it, a totem turns red when its buff drops off you, so totems that give no buff (Searing, Magma, Grounding) never turn red this way.

**An icon is blue**
- You don't have the mana to cast it

**My keybinds don't show on the bar**
- Bind them with Key Bind Mode (Totem Bar tab or `/tn bind`) or in ESC > Key Bindings > TotemNesia

## Sounds and Alerts

**No sounds play**
- Check the alert sound boxes on the Alerts tab and the game's own sound settings
- The voice files must be in `TotemNesia\Sounds`. If you added or renamed sound files, do a full client restart.

**The aggro alert never fires**
- It only works in a party or raid while you're in combat, and a mob has to stay on you for a second
- With SuperWoW, turn on enemy nameplates (V key) so it can see mobs nobody in your group has targeted

**The line of sight message isn't sent**
- The player you were healing has to be in your group. The addon checks the player under your mouse first (for mouseover macros and click-casting on raid frames), then your target.
- If you heal with a keybind while your mouse is over someone else's frame, the warning goes to the player under the mouse
- Turn on Debug mode (General tab) to see in chat why a warning wasn't sent
- Check "Announce in parties" or "Announce in raids" and "Announce line of sight" on the Alerts tab

## Appearance

**The window or bars don't match pfUI, or I want the old look back**
- Use the two pfUI boxes under General > Appearance and Debug, then `/reload`

## Reporting a Bug

Turn on Debug mode (General tab), reproduce the problem, and include the chat output when you open an issue on GitHub.
