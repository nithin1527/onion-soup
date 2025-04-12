label = "Points and Polygons"
methods = {{ label = "Dragon Curve", run = runDragonCurve }}
about = "Creates Dragon Curve from right-angled L shape (with equal sides). Make sure the L is right-angled and has equal sides." -- replace with an appropriate description of your ipelet 

-- ---------------------------------------------------------------------------
-- All Helper functions go here!

function incorrect(title, model) model:warning(title) end

function create_shape_from_vertices(v, model)
    local shape = { type = "curve", closed = false, }
    for i = 1, #v - 1 do
        table.insert(shape, { type = "segment", v[i], v[i + 1] })
    end
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
function sub_vectors(a, b) return ipe.Vector((a.x - b.x), (a.y - b.y)) end
function scale_vector(v, scale) return ipe.Vector(v.x * scale, v.y * scale) end

function merge(t1, t2)
    local merged = {}

    for _, v in ipairs(t1) do
        merged[#merged + 1] = v
    end
    for _, v in ipairs(t2) do
        merged[#merged + 1] = v
    end

    return merged
end

function dragon(v, iterations)
    if iterations > 0 then
        -- directions (to manipulate later)
        local d1to2 = sub_vectors(v[2], v[1])
        local d2to3 = sub_vectors(v[3], v[2])

        -- sin/cos of 45 degrees (they are the same for 45 degrees)
        local sqrt2o2 = (2 ^ (1 / 2)) / 2
        
        -- iteration on "left" side of curve (extending outward), 45 degree counterclockwise rotation
        local d1to2rot = ipe.Vector(d1to2.x * sqrt2o2 - d1to2.y * sqrt2o2, d1to2.x * sqrt2o2 + d1to2.y * sqrt2o2)
        -- making vector shorter to create proper right angle isosceles triangle edge
        local new_v1 = scale_vector(d1to2rot, sqrt2o2)

        -- new point for next iteration
        local btw1to2 = add_vectors(v[1], new_v1)
        local t1 = dragon({ v[1], btw1to2, v[2] }, iterations - 1)
        
        -- iteration on "top" side of curve (extending inward), 45 degree clockwise rotation
        local d2to3rot = ipe.Vector(d2to3.x * sqrt2o2 - d2to3.y * (-sqrt2o2), d2to3.x * (-sqrt2o2) + d2to3.y * sqrt2o2)
        -- making vector shorter to create proper right angle isosceles triangle edge
        local new_v2 = scale_vector(d2to3rot, sqrt2o2)

        -- new point for next iteration
        local btw2to3 = add_vectors(v[2], new_v2)
        local t2 = dragon({ v[2], btw2to3, v[3] }, iterations - 1)

        -- the vertices of the sides get merged to one big table.
        -- this is then drawn!
        return merge(t1, t2)
    else
        -- vertices at lowest level simply returned.
        -- the table of vertices then gets passed to ipe to
        -- be drawn.
        return v
    end
end

function is_L(v)
    if #v ~= 3 then
        return false
    else

        -- gets lengths of sides
        local s1 = (v[1].x - v[2].x) ^ 2 + (v[1].y - v[2].y) ^ 2
        local s2 = (v[2].x - v[3].x) ^ 2 + (v[2].y - v[3].y) ^ 2

        -- dot product (for right angle check)
        local dp = (v[1].x - v[2].x)*(v[2].x - v[3].x) + (v[1].y - v[2].y)*(v[2].y - v[3].y)

        return s1 == s2 and dp == 0
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
    if points == nil then 
        incorrect("No points selected", model)
        return 
    end

    for i = 1, #points do
        if (not_in_table(uniquePoints, points[i])) then
                    table.insert(uniquePoints, points[i])
                end
    end
    return uniquePoints
end

-- ---------------------------------------------------------------------------

function runDragonCurve(model)
    local v = get_selected_poly_vertices(model)
    local vu = unique_points(v, model)

    if vu == nil then
        incorrect("waiter! waiter! more vertices, please!", model)
        return
    end

    if not is_L(vu) then
        incorrect("Make sure the L is right-angled and has equal sides.", model)
        return
    end

    local out = model:getString("Enter iterations. Anything above 15-17\nwill take a while and may slow your computer.\nYou need to delete the original L.")

    if string.match(out, "^%d+$") then
        local dr = dragon(vu, tonumber(out))

        local shape = create_shape_from_vertices(dr, model)
        local obj = ipe.Path(model.attributes, { shape })
        model:creation(1, obj)
    else
        incorrect("waiter! waiter! i need a number!", model)
        return
    end
end
