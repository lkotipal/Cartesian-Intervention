-- Make sure we have an up-to-date version of MWSE.
--[[
if (mwse.buildDate == nil) or (mwse.buildDate < 20200521) then
    event.register("initialized", function()
        tes3.messageBox("[Daedric Intervention] Your MWSE is out of date!" ..
                            " You will need to update to a more recent version to use this mod.")
    end)
    return
end
--]]

local saveData
local divineMarkers = {}
local almsiviMarkers = {}

local function findClosestReference(effectId)
    local cell = tes3.mobilePlayer.cell
    local lastPos = tes3vector3.new(saveData.lastPos.x, saveData.lastPos.y)
    -- Check cells for position override (guild guides, Mournhold?)

    local markers
    if (effectId == tes3.effect.divineIntervention) then
        markers = divineMarkers
    else if (effectId == tes3.effect.almsiviIntervention) then
        markers = almsiviMarkers
    else
        return nil
    end

    table.sort(markers, 
        function(a, b)
            return lastPos:distanceXY(a.position) < lastPos:distanceXY(b.position)
        end
    )

    return table[1]
end

local function teleportTick(e)
    local teleportDisabled = tes3.worldController.flagTeleportingDisabled

    if (e.effectId == tes3.effect.mark and saveData.lastPos) then
        -- Store mark position
        saveData.markPos = saveData.lastPos
        return true
    end

    if (e.effectId == tes3.effect.recall and not teleportDisabled and saveData.markPos) then
        -- Retrieve mark position
        saveData.lastPos = saveData.markPos
        return true
    end

    if (e.effectId != tes3.effect.divineIntervention and e.effectId != tes3.effect.almsiviIntervention) then
        -- Only intercept interventions
        return true
    end

    if (teleportDisabled) then
        -- Fall back to default behavior when teleportation is disabled
        return true
    end

    local reference = tes3.findClosestReference(e.effectID)

    if (reference) then
        tes3.positionCell({
            reference = tes3.player,
            position = reference.position,
            orientation = reference.orientation,
            cell = reference.cell
        })
    else
        -- Fall back to default behavior if we can't find a reference
        return true
    end

    -- Suppress default behavior if we're successful
    e.effectInstance.state = tes3.spellState.retired
    return false
end

event.register(tes3.event.spellTick, teleportTick)

-- Unfortunately getLastExteriorPosition isn't actually the last exterior position...
local function onSimulate(e)
    if (tes3dataHandler.currentCell.isInterior)
        if (not saveData.pos) then
            local pos = getLastExteriorPosition()
            saveData.lastPos.x = pos.x
            saveData.lastPos.y = pos.y
        end
        return
    end

    local pos = tes3.mobilePlayer.position
    saveData.lastPos.x = pos.x
    saveData.lastPos.y = pos.y
end

event.register(tes3.event.simulate, onSimulate)

local function onInitialize(e)
    -- TODO figure these out
    local divineMarkerId
    local almsiviMarkerId
    for _, cell in ipairs(tes3dataHandler.tes3nonDynamicData.cells) do
        -- TODO filter object type
        for ref in cell.iterateReferences() do
            -- Assuming it's faster to check a bool before doing string comparison
            if (ref.isLocationMarker) then 
                if (ref.object.id == divineMarkerId) then
                    table.insert(divineMarkers, ref)
                else if (ref.object.id == almsiviMarkerId) then
                    table.insert(almsiviMarkers, ref)
                end
            end
        end
    end
end

event.register(tes3.event.initialized, onInitialize)

local function onLoad(e)
    saveData = tes3.player.data.cartesianIntervention
end

event.register(tes3.event.loaded, onLoad)
