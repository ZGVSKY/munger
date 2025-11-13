cell_class = {}

function cell_class:create(noise)
    -- function to create a cell object, which is a minimal part of the world
    cell = {}

    cell.owner = nil
    cell.type = nil
    cell.noise = noise

    return cell
end

return cell_class
