-- control.lua

require "util"

-- Function to find the nearest station to a given position, including ghosts
function find_nearest_station(entity_position, surface)
    local stations = surface.find_entities_filtered{type = "train-stop"}
    local ghosts = surface.find_entities_filtered{type = "entity-ghost", ghost_name="train-stop"}
    local all_stations = {}

    -- Include real and ghost stations
    for _, station in pairs(stations) do
        table.insert(all_stations, station)
    end
    for _, ghost in pairs(ghosts) do
        table.insert(all_stations, ghost)
    end

    local nearest_station = nil
    local min_distance = nil
    for _, station in pairs(all_stations) do
        local position
        if station.type == "entity-ghost" then
            position = station.ghost_prototype.position  -- Correct property for ghost position
        else
            position = station.position
        end
        local distance = util.distance(entity_position, position)
        if not nearest_station or distance < min_distance then
            nearest_station = station
            min_distance = distance
        end
    end
    return nearest_station
end


-- Function to set train schedule and mode
function setup_train(entity)
    if entity.type == "locomotive" then
        local train = entity.train
        local nearest_station = find_nearest_station(entity.position, entity.surface)
        if nearest_station and nearest_station.type ~= "entity-ghost" then
            -- Set the train's schedule to real station
            train.schedule = { current = 1, records = { { station = nearest_station.backer_name, wait_conditions = {} } } }
            train.manual_mode = false
        elseif nearest_station then
            -- Schedule a task to check again once the ghost station is built
            global.pending_trains = global.pending_trains or {}
            table.insert(global.pending_trains, { train = train, position = entity.position, surface = entity.surface })
        end
    end
end

-- Update pending trains if a real station is built
function update_pending_trains()
    if global.pending_trains then
        for index, record in ipairs(global.pending_trains) do
            local nearest_station = find_nearest_station(record.position, record.surface)
            if nearest_station and nearest_station.type ~= "entity-ghost" then
                record.train.schedule = { current = 1, records = { { station = nearest_station.backer_name, wait_conditions = {} } } }
                record.train.manual_mode = false
                table.remove(global.pending_trains, index)
            end
        end
    end
end

-- Event handlers for entity placement
script.on_event(defines.events.on_built_entity, function(event)
    setup_train(event.created_entity)
    if event.created_entity.type == "train-stop" then
        update_pending_trains()
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    setup_train(event.created_entity)
    if event.created_entity.type == "train-stop" then
        update_pending_trains()
    end
end)

script.on_event(defines.events.on_entity_cloned, function(event)
    if event.destination.type == "train-stop" then
        update_pending_trains()
    end
end)

-- Initialization of global state
script.on_init(function()
    global.pending_trains = {}
end)
