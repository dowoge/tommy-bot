# tommy-bot

### Steps for hosting

1. Add the `Token.lua` and `APIKeys.lua` files inside `src/Modules`.

2. `Token.lua` should be solely comprised of your Discord bot token. (See example below)
```lua
return "bot.token"
```

3. `APIKeys.lua` should contain any other external API key. Currently only the following are required:
```lua
return {
    StrafesNET = "strafes_aabbcc"
}
```

### T.O.S.
TBD

### PRIVACY POLICY
TBD
