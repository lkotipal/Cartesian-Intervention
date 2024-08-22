-- TODO check MWSE version we want

local divineMarkers = {}
local templeMarkers = {}

-- Breadth first search of doors to find closest exterior
local function findClosestExteriorPos()
    local explored = {[tes3.mobilePlayer.cell.id] = true}
    local cellQueue = {tes3.mobilePlayer.cell}
    local positionQueue = {tes3.mobilePlayer.position}

    while cellQueue[1] do
        local cell = table.remove(cellQueue, 1)
        local pos = table.remove(positionQueue, 1)

        -- Search is done once we find an exterior
        if (not cell.isInterior) then
            return pos
        end

        for door in cell:iterateReferences(tes3.objectType.door) do
            if (door.destination) then
                if (not explored[door.destination.cell.id]) then
                    explored[door.destination.cell.id] = true
                    cellQueue.insert(door.destination.cell)
                    positionQueue.insert(door.destination.marker.position)
                end
            end
        end
    end

    return nil
end

local function findClosestReference(effectId)
    local markers
    if (effectId == tes3.effect.divineIntervention) then
        markers = divineMarkers
    elseif (effectId == tes3.effect.almsiviIntervention) then
        markers = templeMarkers
    else
        return nil
    end

    local lastPos = findClosestExteriorPos()
    if (not lastPos) then
        -- Tribunal DLC intervention seems to be hardcoded, so no special override required
        lastPos =  tes3.getLastExteriorPosition()
    end

    table.sort(markers,
        function(a, b)
            return lastPos:distanceXY(a.position) < lastPos:distanceXY(b.position)
        end
    )

    return markers[1]
end

local function interventionTick(e)
    if (e.effectId ~= tes3.effect.divineIntervention and e.effectId ~= tes3.effect.almsiviIntervention) then
        -- Only intercept interventions
        return true
    end

    if (tes3.worldController.flagTeleportingDisabled) then
        -- Fall back to default behavior when teleportation is disabled
        return true
    end

    local reference = findClosestReference(e.effectId)

    if (not reference) then
        -- Fall back to default behavior if we can't find a marker
        return true
    end

    tes3.positionCell({
        reference = tes3.player,
        position = reference.position,
        orientation = reference.orientation,
        cell = reference.cell
    })

    -- Suppress default behavior if we're successful
    e.effectInstance.state = tes3.spellState.retired
    return false
end

event.register(tes3.event.spellTick, interventionTick)

local function findMarkers(e)

    for _, cell in pairs(tes3.dataHandler.nonDynamicData.cells) do
        if (not cell.isInterior) then
            for ref in cell:iterateReferences(tes3.objectType.static) do
                -- Assuming it's faster to check a bool before doing string comparison
                if (ref.isLocationMarker) then
                    if (ref.object.id == "DivineMarker") then
                        table.insert(divineMarkers, ref)
                    elseif (ref.object.id == "TempleMarker") then
                        table.insert(templeMarkers, ref)
                    end
                end
            end
        end
    end
end

event.register(tes3.event.initialized, findMarkers)
