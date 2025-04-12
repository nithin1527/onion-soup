label = "Points and Polygons"
methods = {{ label = "Onion Peeling", run = runOnionPeeling }}
revertOriginal = _G.revertOriginal
about = [[
    This ipelet creates an onion peeling of the selected points.
    It is based on the convex hull algorithm.
]]

function incorrect(title, model) model:warning(title) end

-- ========================================================================================================================
--! CONVEX HULL (GRAHAM SCAN)
-- https://www.codingdrills.com/tutorial/introduction-to-divide-and-conquer-algorithms/convex-hull-graham-scan

-- Function to calculate the squared distance between two points
function squared_distance(p1, p2)
    return (p1.x - p2.x)^2 + (p1.y - p2.y)^2
end

-- Function to compare two points with respect to a given 'lowest' point
-- Closure over the lowest point to create a compare function
function create_compare_function(lowest, model)
    return function(p1, p2) -- anonymous function

        -- Determine the orientation of the triplet (lowest, p1, p2)
        local o = orientation(lowest, p1, p2, model)

        -- If p1 and p2 are collinear with lowest, choose the farther one to lowest
        if o == 0 then
            return squared_distance(lowest, p1) < squared_distance(lowest, p2)
        end

        -- For non-collinear points, choose the one that forms a counterclockwise turn with lowest
        return o == 2
    end
end

-- Function to find the orientation of ordered triplet (p, q, r).
-- The function returns the following values:
-- 0 : Collinear points
-- 1 : Clockwise points
-- 2 : Counterclockwise  
function orientation(p, q, r, model)
    -- print the vectors and val
    -- print_vertices({p, q, r}, "Orientation", model)
    local val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
    -- print(val, "Orientation", model)
    if val == 0 then return 0  -- Collinear
    elseif val > 0 then return 2  -- Counterclockwise
    else return 1  -- Clockwise
    end
end

function convex_hull(points, model)
    local n = #points
    if n < 3 then return {} end  -- Less than 3 points cannot form a convex hull

    -- Find the point with the lowest y-coordinate (or leftmost in case of a tie)
    local lowest = 1
    for i = 2, n do
        if points[i].y < points[lowest].y or (points[i].y == points[lowest].y and points[i].x < points[lowest].x) then
            lowest = i
        end
    end

    -- Swap the lowest point to the start of the array
    points[1], points[lowest] = points[lowest], points[1]

    -- Sort the rest of the points based on their polar angle with the lowest point
    local compare = create_compare_function(points[1], model) -- closure over the lowest point
    table.sort(points, compare)

    -- Sorted points are necessary but not sufficient to form a convex hull.
    --! The stack is used to maintain the vertices of the convex hull in construction.

    -- Initializing stack with the first three sorted points
    -- These form the starting basis of the convex hull.
    local stack = {points[1], points[2], points[3]}
    local non_stack = {}

    -- Process the remaining points to build the convex hull
    for i = 4, n do
        -- Check if adding the new point maintains the convex shape.
        -- Remove points from the stack if they create a 'right turn'.
        -- This ensures only convex shapes are formed.
        while #stack > 1 and orientation(stack[#stack - 1], stack[#stack], points[i]) ~= 2 do
            table.remove(stack)
        end
        table.insert(stack, points[i])  -- Add the new point to the stack
    end

    -- The stack now contains the vertices of the convex hull in counterclockwise order.
    return stack
end
-- ========================================================================================================================

function create_shape_from_vertices(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do
		table.insert(shape, {type="segment", v[i], v[i+1]})
	end
  	table.insert(shape, {type="segment", v[#v], v[1]})
	return shape
end

function point_on_segment(p, s)
    local cross_product = (p.x - s[1].x) * (s[2].y - s[1].y) - (p.y - s[1].y) * (s[2].x - s[1].x)
    if cross_product ~= 0 then return false end

    local dot_product = (p.x - s[1].x) * (s[2].x - s[1].x) + (p.y - s[1].y) * (s[2].y - s[1].y)
    if dot_product < 0 then return false end
    if dot_product > squared_distance(s[1], s[2]) then return false end

    return true
end

function create_segments_from_vertices(vertices)
	local segments_start_finish = {}
	for i=1, #vertices-1 do
		table.insert( segments_start_finish, {vertices[i],vertices[i+1]} )
	end

	table.insert( segments_start_finish, {vertices[#vertices], vertices[1]} )
	return segments_start_finish
end

function not_in_table(t, v)
    for i=1, #t do
        if t[i] == v then return false end
    end
    return true
end


local creation_objects = {}
function onion_peeling(points, model)

    if points == nil or #points <= 1 then return end
    if #points == 2 then
        table.insert(creation_objects, create_shape_from_vertices(points, model))
        return
    end
    local hull = convex_hull(points, model)
    local shape = create_shape_from_vertices(hull, model)
    table.insert(creation_objects, shape)

    
    local non_hull = {}
    local segments = create_segments_from_vertices(hull)
    for i=1, #points do
        if not_in_table(hull, points[i]) then
            local on_boundary = false
            for j=1, #segments do
                if point_on_segment(points[i], segments[j]) then
                    on_boundary = true
                    break
                end
            end
            if not on_boundary then table.insert(non_hull, points[i]) end
        end
    end
    
    onion_peeling(non_hull, model)
end

function runOnionPeeling(model)
    local p = model:page()
    if not p:hasSelection() then incorrect("Please select at least 1 points", model) return end

	local referenceObjects = {}
	local count = 0
	for _, obj, sel, _ in p:objects() do
		if sel then
		count = count + 1
			if obj:type() ~= "reference" then
				incorrect("One or more selections are not points", model)
				return
			else
				table.insert(referenceObjects, obj:matrix() * obj:position())
			end
		end
	end
	
    if count < 1 then incorrect("Please select at least 1 points", model) return end

    
    onion_peeling(referenceObjects, model)
    
    for i=1, #creation_objects do
        local shape = creation_objects[i]
        model:creation("onion peeling", ipe.Path(model.attributes, {shape}))
    end
    creation_objects = {};
end