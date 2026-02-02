# tommy-bot

### Steps for hosting

1. Add the `Token.lua`, `APIKeys.lua` and `RankConstants.lua` files inside `src/Modules`.

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

4. `RankConstants.lua` should contain the magic constants used for rank point calculation.
```lua
return {
    Magic1 = 1,
    Magic2 = 2
}
```

### T.O.S.
TBD

### PRIVACY POLICY
TBD
