# tommy-bot

### Steps for hosting

1. Insert an `apikey.lua` file under the `src/modules` folder, make it return a string like so:

```lua
return 'key'
```

2. Insert a `token.lua` file under the `src/modules` folder, make it also return a string like said above.

3. Run `start.bat` to start the bot.

###### Note: `token.lua` should be your discord login bot token and `apikey.lua` should be your StrafesNET API key.
