# Murder Mystery 2 Roblox Script

A complete Murder Mystery 2-style game system built for Roblox Studio in Luau, featuring role assignment, weapon mechanics, coin economy, shop system, interactive maps, and round-based gameplay. This package provides all server and client scripts needed to run a full murder mystery game experience with Murderer, Sheriff, and Innocent roles, complete with leaderboard tracking, kill feed, and player UI.

## Install

1. **Create a new Roblox Place** in Roblox Studio (Baseplate template works fine).
2. **Create the required folders in Workspace**: `SpawnLocations`, `CoinSpawns`, `WeaponSpawns`, `Interactables`, `Maps`, `Shops` (each as a Folder).
3. **Add spawn parts**: Place SpawnLocation parts inside `SpawnLocations`, coin spawn positions inside `CoinSpawns`, weapon spawn positions inside `WeaponSpawns` (you can leave the folders empty if you want to start simple).
4. **Copy the server script files** from the `src` folder (GameManager, RoleAssigner, WeaponManager, Interactables, CoinsManager, ShopHandler, Leaderboard, MapManager) into `ServerScriptService`.
5. **Copy the client script files** (PlayerGui and ClientComms) into `StarterPlayerScripts`.
6. **Create maps**: Add map models (like `Map1`, `Map2`, etc.) into the `Maps` folder. Each map should contain parts for doors, chests, and click detectors as desired.
7. **Add shop models**: Create shop models with ProximityPrompts in the `Shops` folder to let players browse and purchase items.
8. **Play-test** from Studio by pressing the Play button.

## Use

1. **Starting the game**: The game will automatically wait for at least 2 players, then start an intermission countdown, followed by a round.
2. **Playing a round**: Each player is randomly assigned a role — Murderer (kill everyone), Sheriff (kill the murderer), or Innocent (survive and collect coins).
3. **Controls**: 
   - Click to attack with your knife or gun
   - Press **P** to open/close the shop
   - Walk up to shop NPCs and use their prompt to open the shop
4. **Collecting coins**: Walk near glowing yellow coins to collect them, then use coins in the shop to purchase knives, guns, or medkits.
5. **Interacting with the map**: Click on doors to open/close them, and click on chests to open them for bonus coins.
6. **Winning**: The round ends when the murderer is killed (innocents win) or all innocents are eliminated (murderer wins).

---

More Roblox script projects by EnderDevelopment: https://github.com/EnderDevelopment

Project page: https://dash.enderdevelopment.com/community/1be58095-8867-42cd-94a2-aa685eeb868c?utm_source=github&utm_medium=readme&utm_campaign=auto_publish&utm_content=1be58095-8867-42cd-94a2-aa685eeb868c
