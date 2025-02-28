label = "Sierpinski's Carpet" -- replace with the title of your ipelet
about = "Creates Sierpinski's carpet out of a provided square" -- replace with an appropriate description of your ipelet 

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

function add_vectors(a, b) return ipe.Vector((a.x + b.x), (a.y + b.y)) end

function sierpinski_carpet(v, iterations, model)

    if iterations > 0 then
        -- distance vectors for splitting v[1] to v[2] to thirds
        local p1to2d = ipe.Vector((v[2].x - v[1].x) / 3, (v[2].y - v[1].y) / 3)
        -- distance vectors for splitting v[2] to v[3] to thirds
        local p2to3d = ipe.Vector((v[3].x - v[2].x) / 3, (v[3].y - v[2].y) / 3)
        -- distance vectors for splitting v[3] to v[4] to thirds
        local p3to4d = ipe.Vector((v[4].x - v[3].x) / 3, (v[4].y - v[3].y) / 3)
        -- distance vectors for splitting v[4] to v[1] to thirds
        local p4to1d = ipe.Vector((v[1].x - v[4].x) / 3, (v[1].y - v[4].y) / 3)
        -- Vectors above get added to the corners of the square to get each mid point

        local m1 = add_vectors(add_vectors(v[1], p1to2d), p2to3d)
        local m2 = add_vectors(add_vectors(v[2], p2to3d), p3to4d)
        local m3 = add_vectors(add_vectors(v[3], p3to4d), p4to1d)
        local m4 = add_vectors(add_vectors(v[4], p4to1d), p1to2d)

        -- points a third of the distance between corners
        local p1to2t = add_vectors(v[1], p1to2d)
        local p2to1t = add_vectors(v[2], p3to4d)

        local p2to3t = add_vectors(v[2], p2to3d)
        local p3to2t = add_vectors(v[3], p4to1d)

        local p3to4t = add_vectors(v[3], p3to4d)
        local p4to3t = add_vectors(v[4], p1to2d)

        local p4to1t = add_vectors(v[4], p4to1d)
        local p1to4t = add_vectors(v[1], p2to3d)

        local shape = create_shape_from_vertices({ m1, m2, m3, m4 }, model)
        local obj = ipe.Path(model.attributes, { shape })
        -- obj:set("fill", "black")
        -- obj:set("pathmode", "filled")
        model:creation(1, obj)
        
        sierpinski_carpet({v[1], p1to2t, m1, p1to4t}, iterations - 1, model)
        sierpinski_carpet({p1to2t, p2to1t, m2, m1}, iterations - 1, model)
        sierpinski_carpet({p2to1t, v[2], p2to3t, m2}, iterations - 1, model)
        sierpinski_carpet({m2, p2to3t, p3to2t, m3}, iterations - 1, model)
        sierpinski_carpet({m3, p3to2t, v[3], p3to4t}, iterations - 1, model)
        sierpinski_carpet({m4, m3, p3to4t, p4to3t}, iterations - 1, model)
        sierpinski_carpet({p4to1t, m4, p4to3t, v[4]}, iterations - 1, model)
        sierpinski_carpet({p1to4t, m1, m4, p4to1t}, iterations - 1, model)
    end
end

function is_square(v, model)
    if #v ~= 4 then
        return false
    else
        local s1 = (v[1].x - v[2].x) ^ 2 + (v[1].y - v[2].y) ^ 2
        local s2 = (v[2].x - v[3].x) ^ 2 + (v[2].y - v[3].y) ^ 2
        local s3 = (v[3].x - v[4].x) ^ 2 + (v[3].y - v[4].y) ^ 2
        local s4 = (v[1].x - v[4].x) ^ 2 + (v[1].y - v[4].y) ^ 2

        local dp = (v[1].x - v[2].x)*(v[2].x - v[3].x) + (v[1].y - v[2].y)*(v[2].y - v[3].y)

        return s1 == s2 and s2 == s3 and s3 == s4 and dp == 0
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

    if vu == nil then
        incorrect("waiter! waiter! more vertices, please!", model)
        return
    end

    if not is_square(vu, model) then
        incorrect("waiter! waiter! i need a square!", model)
        return
    end

    sierpinski_carpet(vu, 5, model)
end
