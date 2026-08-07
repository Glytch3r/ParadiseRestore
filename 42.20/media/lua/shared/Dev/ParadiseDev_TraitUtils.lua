ParadiseDev = ParadiseDev or {}

function ParadiseDev.getTrait(trait)
    if not trait then return nil end
    if type(trait) ~= "string" then return trait end
    if not CharacterTrait or not CharacterTrait.get or not ResourceLocation or not ResourceLocation.of then return nil end
    return CharacterTrait.get(ResourceLocation.of(trait))
end

function ParadiseDev.hasTrait(pl, trait)
    if not pl or not pl.hasTrait then return false end
    trait = ParadiseDev.getTrait(trait)
    return trait and pl:hasTrait(trait) or false
end
