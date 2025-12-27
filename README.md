# TotemNesia

**A smart totem management addon for Shaman in Turtle WoW**

TotemNesia helps Shamans efficiently manage their totems by providing a clickable notification to recall totems after leaving combat. The addon intelligently detects when you have active totems and only prompts you when needed, preventing unnecessary UI clutter. **Never be that Shaman that causes an accidental totem pull again.**

## Features

- **Smart Totem Detection** - Only shows notifications when you actually have totems deployed
- **Clickable Interface** - Click the message to instantly recall all totems with Totemic Recall
- **Combat-Aware** - Automatically hides when you re-enter combat
- **Countdown Timer** - 15-second countdown shows how long you have before the window closes
- **Audio Notification** - Optional sound alert when the message appears (custom MP3 support)
- **Customizable Position** - Drag and lock the message frame anywhere on your screen
- **Debug Mode** - Toggle detailed logging for troubleshooting

## Installation

1. Download the addon files
2. Extract the `TotemNesia` folder to your `World of Warcraft\Interface\AddOns\` directory
3. Restart WoW or type `/reload` in-game
4. The addon will automatically load when you log in with a Shaman character

## How It Works

1. When you leave combat, TotemNesia checks if you have any active totems
2. If totems are detected, a message appears: **"Click to recall totems"**
3. The message stays visible for 15 seconds
4. Click anywhere on the message to cast Totemic Recall
5. If you re-enter combat, the message disappears and resets

![AlClick to recall totems](https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totemic%20Recall.png)


## Commands

| Command | Description |
|---------|-------------|
| `/tn` | Display help and list of commands with current status |
| `/tn lock` | Lock the message frame in place |
| `/tn unlock` | Unlock message frame for repositioning |
| `/tn mute` | Mute the audio notification |
| `/tn unmute` | Unmute the audio notification |
| `/tn debug` | Toggle debug messages on/off |
| `/tn test` | Test the notification display |
| `/tn reset` | Reset the frame position to center |


## Usage Tips

### First Time Setup
1. Type `/tn unlock` to unlock the frame
2. Drag the message window to your preferred location
3. Type `/tn lock` to lock it in place
4. The frame will remember its position

### Positioning the Frame
- When **unlocked**: The frame has 100% opacity and can be dragged anywhere on screen
- When **locked**: The frame has 25% transparency and is clickable to cast Totemic Recall
- The lock state is preserved between sessions

### Audio Notifications
- By default, audio notifications are enabled
- Use `/tn mute` to disable the sound
- Use `/tn unmute` to re-enable and hear a test sound
- Audio state is preserved between sessions

### Custom Audio
To use your own custom sound file:
1. Place your MP3 file in `TotemNesia\Sounds\notification.mp3`
2. **Important**: You must completely exit WoW and restart for custom sounds to be recognized
3. WoW caches available sound files at startup, so `/reload` is not sufficient

### Debug Mode
Enable debug mode with `/tn debug` to see detailed information about:
- When totems are summoned
- Combat state changes
- Totem flag status
- Spell casting attempts

This is useful for troubleshooting or understanding how the addon works.

## Technical Details

### Why Click Instead of Automatic?
Vanilla WoW (1.12) has API restrictions that prevent addons from automatically casting spells outside of combat without player input. TotemNesia works around this by:
- Detecting when you have totems via combat log parsing
- Providing a clickable UI element that counts as player-initiated input
- Allowing you to recall totems with a single click instead of manually casting
- Helps keep Shamans from forgetting their totems, causing an accidental pull

### Totem Detection Method
The addon tracks totems through the combat log (`CHAT_MSG_SPELL_SELF_BUFF` event), detecting when you cast any totem spell. It resets the flag when:
- You click to recall totems
- You leave combat without having cast any totems
- Totemic Recall is successfully cast

### Positioning the Frame
- When **unlocked**: The frame has 100% opacity and can be dragged anywhere on screen
- When **locked**: The frame has 25% transparency and is clickable to cast Totemic Recall
- The lock state is preserved between sessions

### Audio Notifications
- By default, audio notifications are enabled
- Use `/tn mute` to disable the sound
- Use `/tn unmute` to re-enable and hear a test sound
- Audio state is preserved between sessions

### Custom Audio
To use your own custom sound file:
1. Place your MP3 file in `TotemNesia\Sounds\notification.mp3`
2. **Important**: You must completely exit WoW and restart for custom sounds to be recognized
3. WoW caches available sound files at startup, so `/reload` is not sufficient

### Compatibility
- **Client Version**: Turtle WoW (1.18.0)
- **Class**: Shaman only
- **Dependencies**: None
- **Conflicts**: None known

## Troubleshooting

**The message appears but nothing happens when I click it**
- Make sure the frame is locked (`/tn lock`)
- Enable debug mode (`/tn debug`) and check for error messages
- Verify you have Totemic Recall learned

**The message shows even when I don't have totems**
- Enable debug mode to see when the addon detects totems
- Make sure you're running the latest version
- Try `/reload` to reset the addon state

**The message doesn't appear after combat**
- Verify you actually placed totems during or before combat
- Enable debug mode to see if totems are being detected

**I can't move the frame**
- Type `/tn unlock` first
- Make sure you're dragging from the frame itself, not just near it
- Try `/reload` if the frame seems stuck

### Positioning the Frame
- When **unlocked**: The frame has 100% opacity and can be dragged anywhere on screen
- When **locked**: The frame has 25% transparency and is clickable to cast Totemic Recall
- The lock state is preserved between sessions

### Audio Notifications
- By default, audio notifications are enabled
- Use `/tn mute` to disable the sound
- Use `/tn unmute` to re-enable and hear a test sound
- Audio state is preserved between sessions

### Custom Audio
To use your own custom sound file:
1. Place your MP3 file in `TotemNesia\Sounds\notification.mp3`
2. **Important**: You must completely exit WoW and restart for custom sounds to be recognized
3. WoW caches available sound files at startup, so `/reload` is not sufficient

## Contributing

Found a bug or have a feature request? Please submit an issue on the repository.

## License

This addon is provided as-is for use with Turtle WoW.

## Credits

Created for the Turtle WoW community to help Shamans manage their totems more efficiently.

---

**Enjoy your totem management, and may your totems always be where you need them!**
