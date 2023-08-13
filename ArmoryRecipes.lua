local Armory, _ = Armory, nil
local ArmoryDbEntry = ArmoryDbEntry

local tostring = tostring
local table = table
local pairs = pairs
local ipairs = ipairs
local format = format

local container = "Professions"
local itemContainer = "SkillLines"
local recipeContainer = "Recipes"
local reagentContainer = "Reagents"

local recipes = {}

local function IsKnownReagent(id)
    return Armory:GetSharedValue(container, reagentContainer, tostring(id)) ~= nil
end

local function AddCrafters(recipes)
    local currentProfile = Armory:CurrentProfile()

    for _, profile in ipairs(Armory:GetConnectedProfiles()) do
        Armory:SelectProfile(profile)
        local dbEntry = Armory.selectedDbBaseEntry
        if ( dbEntry:Contains(container) ) then
            local character = Armory:GetQualifiedCharacterName()
            for _, recipe in ipairs(recipes) do
                if ( dbEntry:Contains(container, recipe.profession) ) then
                    for i = 1, dbEntry:GetNumValues(container, recipe.profession, itemContainer) do
                        if ( dbEntry:GetValue(container, recipe.profession, itemContainer, i, "Data") == recipe.id ) then
                            table.insert(recipe.crafters, character)
                            break
                        end
                    end
                end
            end
        end
    end

    Armory:SelectProfile(currentProfile)
end

local function GetReagentQuantity(recipe, reagentID)
    local reagents = recipe.Reagents
    if ( reagents ) then
        for i = 1, #reagents do
            local qualityReagents = { ArmoryDbEntry.Load(reagents[i]) }
            if ( tContains(qualityReagents, reagentID) ) then
                return qualityReagents[2]
            end
        end
    end
    return 0
end

local function AddRecipes(recipes, reagentID)
    local recipeDB = Armory:GetSharedValue(container, recipeContainer)
    for recipeID, recipe in pairs(recipeDB) do
        local quantity = GetReagentQuantity(recipe, reagentID)
        if ( quantity > 0 ) then
            local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
            table.insert(recipes, {
                id = recipeID,
                name = Armory:GetNameFromLink(recipe.RecipeLink),
                count = quantity,
                profession = professionInfo and professionInfo.parentProfessionName or UNKNOWN,
                crafters = {}
            })
        end
    end
end

local function UpdateRecipes(recipes, itemID)
    table.wipe(recipes)

    if ( not IsKnownReagent(itemID) ) then
        return
    end

    AddRecipes(recipes, itemID)

    if ( #recipes > 0 ) then
        AddCrafters(recipes)
    end
end

local function FilterRecipes(recipes)
    local filteredRecipes = {}

    if ( IsAltKeyDown() ) then
        filteredRecipes = recipes
    else
        local recipeProfessions = {}
        for _, recipe in ipairs(recipes) do
            if ( not recipeProfessions[recipe.profession] ) then
                recipeProfessions[recipe.profession] = { name = recipe.profession, count = 0, crafters = {} }
            end
            recipeProfessions[recipe.profession].count = recipeProfessions[recipe.profession].count + 1
            for _, crafter in ipairs(recipe.crafters) do
                if ( not tContains(recipeProfessions[recipe.profession].crafters, crafter) ) then
                    table.insert(recipeProfessions[recipe.profession].crafters, crafter)
                end
            end
        end

        for _, recipeProfession in pairs(recipeProfessions) do
            table.insert(filteredRecipes, recipeProfession)
        end
    end

    table.sort(filteredRecipes, function(a, b) return a.name < b.name end)

    return filteredRecipes
end

local currentItemID = nil
local function EnhanceItemTooltip(tooltip, itemID)
    if ( currentItemID ~= itemID ) then
        UpdateRecipes(recipes, itemID)
    end
    currentItemID = itemID

    local filteredRecipes = FilterRecipes(recipes)
    if ( #filteredRecipes > 0 ) then
        tooltip:AddLine(" ")
        if ( IsAltKeyDown() ) then
            tooltip:AddLine(AUCTION_CATEGORY_RECIPES)
        else
            tooltip:AddLine(format("%s <%s - %s>", AUCTION_CATEGORY_RECIPES, ALT_KEY_TEXT, PROFESSIONS_CRAFTING_DETAILS_HEADER))
        end

        for _, recipe in ipairs(filteredRecipes) do
            tooltip:AddDoubleLine(format("%s (%d)", recipe.name, recipe.count), table.concat(recipe.crafters, ", "), 1, 1, 1)
        end
    end
end

do
    if ( not Armory:HasTradeSkills() ) then
        Armory:PrintError("Professions module not enabled")
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if (tooltip == GameTooltip or tooltip == ItemRefTooltip) then
            local _, _, id = tooltip:GetItem()
            EnhanceItemTooltip(tooltip, id)
        end
    end)
end
