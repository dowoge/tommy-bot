# tommy-bot

### Steps for hosting

1. Add the `Token.lua`, `APIKeys.lua` and `RankConstants.lua` files inside `src/Modules`. Optionally add `ProxyConfig.lua` to route Roblox API requests through the Cloudflare Worker proxy in `cloudflare-proxy/`.

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

5. (Optional) `ProxyConfig.lua` should contain the Cloudflare Worker URL and shared key used for proxied Roblox requests. Without it, requests go direct.
```lua
return {
    WorkerUrl = "https://your-worker.example.workers.dev",
    ProxyKey = "shared-secret-from-wrangler-secret"
}
```

### T.O.S.
TBD

### PRIVACY POLICY
TBD
