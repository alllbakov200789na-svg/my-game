
# Jujutsu Cursed Survival — AI Instructions

## Project
We are two developers building a multiplayer Roblox
anime-inspired survival and combat game.

## Tech Stack
- Roblox Studio
- Luau
- Rojo 7.7.1
- Rokit
- Wally 0.3.2
- Trove 1.8.0
- GitHub
- VS Code

## Project Structure
- src/Server: server gameplay systems
- src/Client: client gameplay systems
- src/Shared: shared modules
- assets/Maps: maps
- assets/Lobby.rbxmx: lobby model
- default.project.json: Rojo mapping
- wally.toml: package dependencies

## Coding Rules
- Prefer strict Luau types.
- Use modular architecture.
- Never trust the client for damage or rewards.
- Validate RemoteEvent inputs on the server.
- Avoid memory leaks and clean up resources with Trove.
- Avoid unnecessary loops and expensive operations.
- Reuse existing modules where appropriate.

## Collaboration Rules
- Never overwrite unrelated changes.
- Do not modify files assigned to another developer.
- Explain major architecture changes before implementing.
- Make small, reviewable changes.

## Safety
- Do not publish the game automatically.
- Do not modify production DataStores.
- Never delete maps or existing mechanics without approval.
- Ask before installing new libraries.

## Verification
- Run rojo build default.project.json -o test.rbxl
  after code changes.
- Report build failures.
- Never claim gameplay tests passed without running them.
- List all changed files after each task.
