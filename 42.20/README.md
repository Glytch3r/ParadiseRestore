# B42 Trait Sandbox

Minimal Build 42.20 mod demonstrating the two B42 trait patterns:

- `b42traitsandbox:goober` is registered and has a `character_trait_definition`, so it appears in character creation as **Goober**. Its cost is 1 and it deliberately has no gameplay effects.
- `b42traitsandbox:bongocat` is registered and has a hidden `IsProfessionTrait = true` definition. It stays out of character creation, but appears on character-info and admin trait-management screens once assigned.

## Multiplayer

Install and enable the same mod on the server and every client. `media/registries.lua` is the B42 early-registration file, loaded before trait script definitions and player data are processed.

## Use from Lua

Resolve the registered trait by its namespaced ID, then use the normal character-trait API:

```lua
local goober = CharacterTrait.get(ResourceLocation.of("b42traitsandbox:goober"))
local bongocat = CharacterTrait.get(ResourceLocation.of("b42traitsandbox:bongocat"))

-- Server authority:
player:getCharacterTraits():add(bongocat)
sendSyncPlayerFields(player, 2) -- only needed when clients need the updated trait state immediately

if player:hasTrait(bongocat) then
    -- enforce your server-side condition
end
```

Keep the IDs stable after release: traits are stored in player saves by their namespaced registry IDs.
