label = "Sierpinski's Triangle"
about = "Creates Sierpinski's Triangle out of a provided triangle (8 iterations)"

-- ---------------------------------------------------------------------------
-- All Helper functions go here!

function incorrect(title, model) model:warning(title) end

function create_shape_from_vertices(v, model)
    local shape = { type = "curve", closed = true, }
    for i = 1, #v - 1 do
        table.insert(shape, { type = "segment", v[i], v[i + 1] })
    end
    table.insert(shape, { type = "segment", v[#v], v[1] })
    return shape
end

function get_polygon_vertices(obj, model)

    local shape = obj:shape()
    local polygon = obj:matrix()

    vertices = {}

    vertex = polygon * shape[1][1][1]
    table.insert(vertices, vertex)

    for i=1, #shape[1] do
        vertex = polygon * shape[1][i][2]
        table.insert(vertices, vertex)
    end

    return vertices
end

function get_selected_poly_vertices(model)
    local shape
    local page = model:page()

    if not page:hasSelection() then
        return
    end

    for _, obj, sel, _ in page:objects() do
        if sel and obj:type() == "path" then
            shape = obj
        end
    end

    return get_polygon_vertices(shape, model)
end

function midpoint(a, b) return ipe.Vector((a.x + b.x) / 2, (a.y+ b.y) / 2) end

function sierpinski_triangle(v, iterations, model)
    if iterations > 0 then
        local p12 = midpoint(v[1], v[2])
        local p13 = midpoint(v[1], v[3])
        local p23 = midpoint(v[2], v[3])
        
        local shape = create_shape_from_vertices({ p12, p13, p23 }, model)

        model:creation(1, ipe.Path(model.attributes, {shape}))
        
        sierpinski_triangle({ v[1], p12, p13 }, iterations - 1, model)
        sierpinski_triangle({ v[2], p12, p23 }, iterations - 1, model)
        sierpinski_triangle({ v[3], p13, p23 }, iterations - 1, model)
    end 
end

function not_in_table(vectors, vector_comp)
    local flag = true
    for _, vertex in ipairs(vectors) do
        if vertex == vector_comp then
            flag = false
        end
    end
    return flag
end

function unique_points(points, model)
    -- Check for duplicate points and remove them
    local uniquePoints = {}
    for i = 1, #points do
        if (not_in_table(uniquePoints, points[i])) then
                    table.insert(uniquePoints, points[i])
                end
    end
    return uniquePoints
end

-- ---------------------------------------------------------------------------

function run(model)
    local v = get_selected_poly_vertices(model)
    local vu = unique_points(v, model)

    local depth = tonumber(model:getString("Enter Depth"))

    if vu == nil then 
        incorrect("waiter! waiter! more vertices, please!", model)
        return
    end

    if #vu ~= 3 then
        incorrect("waiter! waiter! i need a triangle!", model)
        return
    end

    sierpinski_triangle(vu, depth, model)
end
