# rsurf-doge

### Steps for hosting

1. Insert an `apikey.lua` file under the `src/modules` folder, make it return a string like so:

```lua
return 'key'
```

2. Insert a `token.lua` file under the `src/modules` folder, make it also return a string like said above.
3. Insert the discordia library under a new folder `deps/discordia` by running `install_discordia.bat`.
