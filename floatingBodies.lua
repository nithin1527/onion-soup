label = "New Convex"

-- Returns a table of the vertecies in all selected polygons
-- In the event that multiple polygons are selected, only one is chosen
function get_pts_and_segment_selection(model)
    local p = model:page()
    if not p:hasSelection() then
        return
    end

    local tab = {}

    for _, obj, sel, _ in p:objects() do
        local transform = obj:matrix()
        if sel then
            if obj:type() == "path" then 
                local shape = obj:shape()
                for _, subpath in ipairs(shape) do
                    if subpath.type == "curve" then
                        local max = 0
                        for j, vertices in ipairs(subpath) do
                            table.insert(tab, transform*vertices[1])
                            max = max + 1
                        end
                        table.insert(tab, transform*subpath[max][2])
                    end
                end
                -- Only finds the first selected path object
                break
            end
        end
    end

    return tab
end

-- Reorders a table of sequential points starting at a provided value
-- Courtesy of GPT
function reorderTable(t, startElement)
    -- Find the index of the start element
    local startIndex = nil
    for i, v in ipairs(t) do
        if v == startElement then
            startIndex = i
            break
        end
    end

    -- If the element is not found, return the original table
    if startIndex == nil then
        print("Element not found in the table")
        return t
    end

    -- Create a new table to store the reordered result
    local reordered = {}

    -- Add the elements from the start index to the end
    for i = startIndex, #t do
        table.insert(reordered, t[i])
    end

    -- Add the elements from the beginning to the start index - 1
    for i = 1, startIndex - 1 do
        table.insert(reordered, t[i])
    end

    return reordered
end

-- Givena table of adjacent points of a polygon, returns true if it is convex
function isConvex(vertices)
    function orient(p, q, r) return p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y) end
    local side = nil
    local i = 1
    while i < #vertices do
        local temp = orient(vertices[i], vertices[(i % #vertices)+1], vertices[((i+1)%#vertices)+1])
        if side == nil then
            if temp > 0 then
                side = 1
            end
            if temp < 0 then
                side = -1
            end
        else
            if side*temp < 0 then
                return false
            end
        end
        i = i + 1

    end
    return true
end

-- Calculate the area of a polygon given its vertices (Shoelace algorithm)
-- Code generated via Copilot
function calculate_polygon_area(vertices)
    local area = 0
    local num_vertices = #vertices

    for i = 1, num_vertices do
        local j = (i % num_vertices) + 1
        area = area + (vertices[i].x * vertices[j].y) - (vertices[j].x * vertices[i].y)
    end

    return math.abs(area) / 2
end

-- Function to compare points based on dot product, then x value, then y
-- (Allows a certain chain to always be on a certain side of another)
function compare(a, b)
    if a[1] < b[1] then
        return true
    end

    if a[1] > b[1] then
        return false
    end

    if a[2].x < b[2].x then
        return true
    end

    if a[2].x > b[2].x then
        return false
    end

    if a[2].y < b[2].y then
        return true
    end

    return false
end

-- Orders points based on dot product
function get_closest(points, dir, model)
    -- Stores the dot product to sort by
    local temp = {}
    for _, pt in ipairs(points) do
        table.insert(temp, {dir^pt, pt})
    end

    --table.sort(temp, compare) Just trying it, shouldn't matter though
    table.sort(temp, function(a,b) return a[1]<b[1] end)

    -- Convert it back into a table of vertices
    local newPoints = {}
    for _, pt in ipairs(temp) do
        table.insert(newPoints, pt[2])
    end

    return newPoints
end


--[=[
Given:
 - vertices, segments of polygon A: () -> {Vector}, () -> {Segment} 
 - vertices, segments of polygon B: () -> {Vector}, () -> {Segment} 
Return:
 - table of interection points: () -> {Vector}
--]=]
function get_intersection_points(s1,s2, model)
	local intersections = {}
     
    local end_point = s1[#s1]
    for i=1,#s1 do
        local intersection = ipe.Segment(s1[i], end_point):intersects(s2)
        if intersection then
            table.insert(intersections, intersection)
        end
        end_point = s1[i]
    end
	return intersections
end



-- euclidean distance between two points
function euclidean_distance(p1, p2)
    return math.sqrt(math.pow((p1.x-p2.x), 2) + math.pow((p1.y-p2.y), 2))
end


-- Use the first and last point in sorted to construct the chains
function get_segments_sorted(coordinates, sorted, model)
    local chain1 = {}
    local chain2 = {}
    local first = sorted[1]
    local last = sorted[#sorted]
    local index

    for i, x in ipairs(coordinates) do
        if first == x then
            index = i
            break
        end
    end

    if index == nil then
        model:warning("Issue finding segment in get_segments_sorted: ")
    end

    local i = index - 1
    local chainFlag = true

    local cur

    local flag = true
    while flag or i ~= index-1 do
        flag = false
        cur = coordinates[i+1]
        if cur == last then
            chainFlag = false
        end

        if chainFlag then
            table.insert(chain1, cur)
        else
            table.insert(chain2, 1, cur)
        end

        i = (i + 1) % #coordinates
    end

    -- In order to make sure they have access to the segments, we add the first and last node to both
    -- It is easy enough to check to see if it is the first or the last node. 
    -- Requires a check for othogonality
    table.insert(chain1, last)
    table.insert(chain2, 1, first)
    return {chain1, chain2}

end

-- Used for get_angle
function get_magnitude(p1)
    return math.sqrt(math.pow(p1.x, 2) + math.pow(p1.y, 2))
end

-- get the difference between two vertices
function get_slope(a,b)
    return ipe.Vector(a.x-b.x, a.y-b.y)
end

-- Given two angle vectors, get the angle between them (Used in get_angle_between_segments)
function get_angle(a, b)
    return math.acos(a^b/(get_magnitude(a) * get_magnitude(b)))
end

-- Given a segment and direction vector, get the angle between
function get_angle_between_segments(a1, a2, dir)
    return get_angle(get_slope(a1, a2), dir)
end

-- Find the area using a given h value
function get_area(gamma, h, theta1, theta2, model)
    if h < 0.001 then
        model:warning("Tiny h")
        return 0
    end
    local temp = gamma * h + h^2/2 * (math.tan(theta1) + math.tan(theta2))
    
    if temp < 0 then
        model:warning("Negative area")
        model:warning("Gamma = " .. gamma .. "H = " .. h .. ", theta1 = " .. theta1 .. " Theta2 = " .. theta2)
        model:warning(temp)
    end
    return gamma * h + h^2/2 * (math.tan(theta1) + math.tan(theta2))
end

-- Make a line at a given point in the direction dir
function get_line(point, dir, model)
    local temp_point = ipe.Vector(point.x + dir.x*20, point.y + dir.y*20)
    if point.x == nil then
        model:warning("Breaky1")
    end
    
    local temp = ipe.LineThrough(point, temp_point)
    return temp
end

-- Returns the inverse of the given vertex direction
function get_inverse(dir, model)
    return ipe.Vector(-1 * dir.y, 1 * dir.x)
end

-- Make a line perpendicular to the given vertex direction at point (used for the lines at each vertex)
function get_perp_line(point, dir, model)
    local temp = get_line(point, get_inverse(dir, model), model)
  return temp
end


-- Pass in 2 line segments and a line for the direction vector, returns the min distance between the two vectors
-- While you could solve the direction yourself as it is orthogonal to the segments, to reduce unneeded calculations
-- I just pass it in
-- Will break if the lines are parallel to dir, but not if they overlap


function get_dist_between_lines(seg1, seg2, dir, model)
    local p1 = seg1:intersects(get_line(ipe.Vector(0,0), dir, model))
    local p2 = seg2:intersects(get_line(ipe.Vector(0,0), dir, model))

    return euclidean_distance(p1, p2)
end


function get_dist_for_points(p1, p2, dir, model)
    --model:warning("1" .. dir.x .. dir.y)
    return get_dist_between_lines(get_perp_line(p1, dir, model), get_perp_line(p2, dir, model), dir, model)
end




-- Issue lies in thetas, with figuring out whether to make it positive or negative
-- Given a location (1) and a point for direction (2), get the area of that step
function calc_area(a1, a2, b1, b2, dir, gamma, h, model)
    local seg1 = ipe.Segment(a1, a2)
    local seg2 = ipe.Segment(b1, b2)

    local temp1 = seg1:line():dir()
    local temp2 = seg2:line():dir()


    local theta1 = get_angle(temp1, dir)
    local theta2 = get_angle(temp2, dir)

    -- Needs to adjust the angle depending on if it should increase or decrease the area
    if temp1.x*dir.y - temp1.y*dir.x < 0 then
        theta1 = -theta1
    end
    if temp2.x*dir.y - temp2.y*dir.x > 0 then
        theta2 = -theta2
    end

    return math.abs(get_area(gamma, h, theta1, theta2, model))
end

function reverseTable(t)
    local n = #t
    for i = 1, math.floor(n / 2) do
        t[i], t[n - i + 1] = t[n - i + 1], t[i]
    end
end

-- Issue lies in thetas, with figuring out whether to make it positive or negative
-- Given a location (1) and a point for direction (2), get the area of that step
function find_h(a1, a2, b1, b2, dir, gamma, area, model)
    if area < 0.001 then
        return 0
    end


    local seg1 = ipe.Segment(a1, a2)
    local seg2 = ipe.Segment(b1, b2)

    local temp1 = seg1:line():dir()
    local temp2 = seg2:line():dir()


    local theta1 = get_angle(temp1, dir)
    local theta2 = get_angle(temp2, dir)


    -- How do i make this work? Seems like which chain is which doesn't tend to be consistent, so it
    -- Needs to rely on orientation or be modified before the function to be consistent
    if temp1.x*dir.y - temp1.y*dir.x < 0 then
        theta1 = -theta1
    end
    if temp2.x*dir.y - temp2.y*dir.x > 0 then
        theta2 = -theta2
    end

    if math.abs(math.tan(theta1) + math.tan(theta2)) < 0.001 then
        if math.abs(gamma) < 0.001 then
            return 0
        end
        return area/gamma
    end

    local t1 = (-gamma + math.sqrt(gamma*gamma+2*(math.tan(theta1)+math.tan(theta2))*area))/(math.tan(theta1)+math.tan(theta2))
    local t2 = (-gamma - math.sqrt(gamma*gamma+2*(math.tan(theta1)+math.tan(theta2))*area))/(math.tan(theta1)+math.tan(theta2))

    if t1 < 0 then
        return t2
    else
        if t2 < 0 then
            return t1
        else
            return math.min(t1,t2)
        end
    end
end

-- Used for intersections
function removeDuplicates(tbl)
    local seen = {}
    local result = {}
    
    for _, value in ipairs(tbl) do
        if not seen[value] then
            seen[value] = true
            table.insert(result, value)
        end
    end
    
    return result
end

--Prints out a vector
function print_vector(vector, name, model)
    model:warning(name.." = (" .. vector.x .. ", " .. vector.y .. ")")
end


function run(model)

    -- Stores the unmodified coordinates in ncoordinates
    local ncoordinates = get_pts_and_segment_selection(model)
    if ncoordinates == nil or #ncoordinates == 0 then
        model:warning("No/Not enough coordinates found, exiting")
        return
    end

    -- The polygon must be convex, if not, we exit
    if not isConvex(ncoordinates) then
        model:warning("The provided shape is not convex, exiting ipelet (If three adjacent points are on the same line, it breaks)")
        return
    end

    -- Takes in the desired amount of area, doesn't accept 0 or 100 since those would do nothing
    local delta = model:getString("Enter delta value (1-99, where x means x% of the total area)")
    delta = tonumber(delta)
    if delta == nil or delta < 1 or delta > 99 then
        model:warning("Invalid delta input")
        return
    end


    -- We don't check this one since we have a default value
    local showType = model:getString("Would you like the halfspace lines (Default) or a polygon of midpoints (1)")


    local midpoints = {}
    local target_area = calculate_polygon_area(ncoordinates) * delta/100


    -- Iterates over 1 degree, 2 degrees ... 359 degrees
    for i = 0, 359 do
        -- Creates a directional vector
        local dir = ipe.Vector(math.cos(i/180*math.pi), math.sin(i/180*math.pi))

        -- Sorts the coordinates based on dot product value to the direction vector, then puts the 1st node first in the table
        local points = get_closest(ncoordinates, dir, model)
        local coordinates = reorderTable(ncoordinates, points[1])


        -- Reorders it so that chain 1 is always clockwise of dir
        if (coordinates[1].x-coordinates[2].x)*dir.y - (coordinates[1].y-coordinates[2].y)*dir.x > (coordinates[1].x-coordinates[#coordinates].x)*dir.y - (coordinates[1].y-coordinates[#coordinates].y)*dir.x then
            reverseTable(coordinates)
            coordinates = reorderTable(coordinates, points[1])
        end

        -- Gets the chains, stored as {chain1, chain2}
        local chains = get_segments_sorted(coordinates, points,  model)

        -- Indexes for chain 1 and chain 2
        local c1 = 1
        local c2 = 1

        local chain1 = chains[1]
        local chain2 = chains[2]

        -- IMPORTANT
        -- Gamma updates at the end of each segment for the following segment
        local gamma = 0
        local total_area = 0

        -- They both start on the initial point, so we just skip that useless step (Breaks index - 1 otherwise)
        if chain1[2]^dir < chain2[2]^dir then
            c1 = c1 + 1
        else
            c2 = c2 + 1
        end

        -- While neither have gone too far (This really doesn't matter, just acts as a failsafe to prevent)
        -- Infinite looping if something breaks
        while c1 <= #chain1 and c2 <= #chain2 do

            --Vectors that show the direction of a segment from a1 or b1
            local a2
            local b2

            -- Gets the length of the next segment
            local h = get_dist_for_points(points[c1+c2-2], points[c1+c2-1], dir, model)

            -- If they are just about on the same line, we don't need to account for it. Issue with == due to floating point error
            if h > 0.00001 then

                -- We need to know which point is first, so we have two cases
                -- We modify the second point using temp slope instead of just taking the other value in order to flip it around
                -- This ensures angle calculation works
                if chain1[c1]^dir < chain2[c2]^dir then   
                    a2 = chain1[c1+1]
                    b2 = chain2[c2]
                    local temp_slope = get_slope(chain2[c2-1], chain2[c2])
                    b2 = ipe.Vector(b2.x + temp_slope.x, b2.y + temp_slope.y)
                else
                    b2 = chain2[c2+1]
                    a2 = chain1[c1]
                    local temp_slope = get_slope(chain1[c1-1], chain1[c1])
                    a2 = ipe.Vector(a2.x + temp_slope.x, a2.y + temp_slope.y)
                end

                -- Calculates the max area of the segment
                local temp_area = calc_area(chain1[c1], a2, chain2[c2], b2, dir, gamma, h, model)

                -- If it overshoots, we need to find the h that works
                if temp_area + total_area > target_area then

                    local h = find_h(chain1[c1], a2, chain2[c2], b2, dir, gamma, target_area-total_area, model)
                    
                    -- Takes the first point and advances along dir by h, so we can find the orthogonal line to it
                    local last_point
                    if chain1[c1]^dir < chain2[c2]^dir then
                        last_point = ipe.Vector(chain1[c1].x + dir.x*h, chain1[c1].y + dir.y*h)
                    else
                        last_point = ipe.Vector(chain2[c2].x + dir.x*h, chain2[c2].y + dir.y*h)
                    end

                    -- Finds the intersection points in the main shape
                    local temp_perp_line = get_perp_line(last_point, dir, model)
                    local intersect_points = get_intersection_points(coordinates, temp_perp_line, model)


                    -- This one is possible when a line goes through a vertex
                    if #intersect_points > 2 then
                        intersect_points = removeDuplicates(intersect_points)
                    end

                    -- Shouldn't trigger, but this prevents a crash
                    if #intersect_points < 2 then
                        model:warning("Didn't intersect. You shouldn't see this message")
                        break
                    end

                    -- If half space lines, draw them
                    if showType ~= "1" then
                        local start = intersect_points[1]
                        local finish = intersect_points[2]

                        -- Create the path between the two vectors
                        local segment = {type="segment", start, finish}
                        local shape = { type="curve", closed=false, segment}
                        local pathObj = ipe.Path(model.attributes, { shape })
                        
                        -- Draw the path
                        model:creation("create basic path", pathObj)
                    end

                    -- Adds the midpoint to a table
                    table.insert(midpoints, ipe.Vector((intersect_points[1].x + intersect_points[2].x)/2,(intersect_points[1].y + intersect_points[2].y)/2))
                    
                    break

                end

                -- Update gamma. I wish it was simpler, but if the next point is on the same line as the first point, we need
                -- To update the gamma there instead of at the other chain
                if chain1[c1]^dir < chain2[c2]^dir then   
                    local temp_point
                    if chain1[c1+1]^dir < chain2[c2]^dir then
                        temp_point = get_perp_line(chain1[c1+1], dir, model):intersects(ipe.Segment(chain2[c2], chain2[c2-1]):line())
                        gamma = euclidean_distance(temp_point, chain1[c1+1])
                    else
                        temp_point = get_perp_line(chain2[c2], dir, model):intersects(ipe.Segment(chain1[c1], chain1[c1+1]):line())
                        gamma = euclidean_distance(temp_point, chain2[c2])
                    end
                else
                    local temp_point
                    if chain2[c2+1]^dir < chain1[c1]^dir then
                        temp_point = get_perp_line(chain2[c2+1], dir, model):intersects(ipe.Segment(chain1[c1], chain1[c1-1]):line())
                        gamma = euclidean_distance(temp_point, chain2[c2+1])
                    else
                        temp_point = get_perp_line(chain1[c1], dir, model):intersects(ipe.Segment(chain2[c2], chain2[c2+1]):line())
                        gamma = euclidean_distance(temp_point, chain1[c1])
                    end

                end

                total_area = total_area + temp_area
            else
                -- If h is basically 0, we can just find the distance between those two points
                gamma = euclidean_distance(chain1[c1], chain2[c2])
            end

            


            -- Advancing on the chain (Basically, whichever segment is next we update)
            if c1 == #chain1 then
                c2 = c2 + 1
            else
                if c2 == #chain2 then
                    c1 = c1 + 1
                else
                    -- Floating point issues
                    if math.abs(chain1[c1]^dir - chain2[c2]^dir) < 0.001 then
                        if chain1[c1+1]^dir < chain2[c2+1]^dir then
                            c1 = c1 + 1
                        else 
                            c2 = c2+1
                        end
                    else
                        if chain1[c1]^dir < chain2[c2]^dir then
                            c1 = c1 + 1
                        else 
                            c2 = c2+1
                        end
                    end
                end
            end
            
        end
    end

    -- Midpoint polygon
    if showType == "1" then
        local closest_points = midpoints
        local start = closest_points[#closest_points]
        local finish
        local lines = {}
        for _, point in ipairs(closest_points) do
            finish = ipe.Vector(point.x, point.y)
            local segment = {type="segment", start, finish}
            local shape = { type="curve", closed=false, segment}
            table.insert(lines, shape)
            start = finish
        end
        local pathObj = ipe.Path(model.attributes, lines)
        model:creation("create basic path", pathObj)
    end

end