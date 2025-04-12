label = "Points and Polygons"

-- ========================================================================================================================
-- BETA SKELETON

revertOriginal = _G.revertOriginal
about = [[
    This ipelet creates the beta Skeleton of a set of points.
]]

function incorrect(title, model) model:warning(title) end

-- Creates a shape from a set of vertices
function create_shape_from_vertices(v, model)
	local shape = {type="curve", closed=true;}
	for i=1, #v-1 do 
		table.insert(shape, {type="segment", v[i], v[i+1]})
	end
  	table.insert(shape, {type="segment", v[#v], v[1]})
	return shape
end

-- Function to calculate the angle between three points
local function calculate_angle(p1, p2, p3, model)
    -- Vectors: p1p2 and p2p3
    local v1x = p2.x - p1.x
    local v1y = p2.y - p1.y
    local v2x = p3.x - p2.x
    local v2y = p3.y - p2.y

    -- Dot product of vectors
    local dot_product = v1x * v2x + v1y * v2y

    -- Magnitudes of the vectors
    local magnitude_v1 = math.sqrt(v1x * v1x + v1y * v1y)
    local magnitude_v2 = math.sqrt(v2x * v2x + v2y * v2y)

    -- Cosine of the angle
    local cos_theta = dot_product / (magnitude_v1 * magnitude_v2)

    -- Clamp the cosine value to the range [-1, 1] to avoid errors due to floating-point precision
    cos_theta = math.max(-1, math.min(1, cos_theta))

    -- Calculate the angle in radians and convert to degrees
    local angle_rad = math.acos(cos_theta)
    return angle_rad 
end

-- Function to convert beta to theta
function convert_to_theta(beta)
    local pi = math.pi  -- Constant for Pi

    if beta >= 1 then
        -- Calculate theta = arcsin(1 / beta)
        return math.asin(1 / beta)
    else
        -- Calculate theta = pi - arcsin(beta)
        return pi - math.asin(beta)
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

function runBetaSkeleton(model)
    -- Ok do we have a selection
    local p = model:page()
    local segments = {}
    if not p:hasSelection() then incorrect("Please select at least 3 points", model) return end
    
    -- Now get our beta from the user 
    local beta = model:getString("Input Beta: ")
    if tonumber(beta)<=0.0 then incorrect("Beta must be a positive real", model) end
    local newbeta = convert_to_theta(tonumber(beta)) 
    -- Set up our points
    local points = {}
    local count = 0
    
    -- Count the number of points
    for _, obj, sel, _ in p:objects() do
      if sel then
      count = count + 1
      
      -- Make sure they are points
        if obj:type() ~= "reference" then
          incorrect("One or more selections are not points", model)
          return
        else
          
          -- Stick them in a table
          table.insert(points, obj:matrix() * obj:position())
        end
      end
    end
    
    points = unique_points(points,model)
    -- If there aren't enough points
    if count < 3 then incorrect("Please select at least 3 points", model) return end

    -- Debug pleftover print("Angle", newbeta, model)
    
    -- For every point
    for i = 1, #points do
      local p1 = points[i]
      -- And every other point
      for j = 1, #points do
          if j ~= i then  -- Ensure p1 and p2 are different points
              local p2 = points[j]
              local condition = true
              
              -- Check every third point
              for k = 1, #points do
                  if k ~= i and k ~= j then  -- Ensure p1, p2, p3 are different points
                    
                      local p3 = points[k]

                      -- Calculate the angle at point p3
                      local angle = calculate_angle(p1, p3, p2, model)
                      
                      -- If the angle is less than beta
                      
                      if angle<newbeta then
                        -- We don't want to put a line between p1 and p2
                        condition=false
                      end
                  end
              end
              
              -- If we wanna put a line between p1 and p2, do it
              if condition then
                table.insert(segments,
                              ipe.Path(model.attributes, {create_shape_from_vertices({p1, p2}, model)}))
              end
          end
      end
  end
  model:creation("Beta Skeleton ", ipe.Group(segments)) 
end

-- ========================================================================================================================
-- DRAGON CURVE
about = "Creates Dragon Curve from right-angled L shape (with equal sides). Make sure the L is right-angled and has equal sides." -- replace with an appropriate description of your ipelet 

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

-- ========================================================================================================================
-- Floating Body

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


function runFloatingBodies(model)

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
-- ========================================================================================================================
-- ONION PEELING

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

-- ========================================================================================================================
-- QUADTREE
about = "Given a set of points, draws a respective point-region quadtree or point quadtree"

-- point-region quadtree class
local PointRegionQuadtreeNode = {}

function PointRegionQuadtreeNode.new(boundary, capacity)
    local instance = {
        boundary = boundary,
        capacity = capacity,
        points = {},
        divided = false,
    }

    -- instance methods
    instance.subdivide = PointRegionQuadtreeNode.subdivide
    instance.insert = PointRegionQuadtreeNode.insert
    instance.belongs = PointRegionQuadtreeNode.belongs
    instance.draw = PointRegionQuadtreeNode.draw
    instance.to_string = PointRegionQuadtreeNode.to_string

    return instance
end

-- returns string representation of entire point-region quadtree
function PointRegionQuadtreeNode.to_string(self, depth)
    local indent = string.rep("         ", depth)
    local result = ""

    if #self.points > 0 then
        result = result .. "Points: {"
        for i, point in ipairs(self.points) do
            result = result .. "(" .. point.x .. ", " .. point.y .. ")"
            if i < #self.points then
                result = result .. ", "
            end
        end
        result = result .. "}\n"
    elseif depth ~= 0 then
        result = result .. "\n"
    end

    -- Recursively print child nodes if subdivided
    if self.divided then
        result = result .. indent .. "Northwest: " .. self.northwest:to_string(depth + 1)
        result = result .. indent .. "Northeast: " .. self.northeast:to_string(depth + 1)
        result = result .. indent .. "Southwest: " .. self.southwest:to_string(depth + 1)
        result = result .. indent .. "Southeast: " .. self.southeast:to_string(depth + 1)
    end

    return result
end

-- subdivision of node in equal quadrants when its number of points exceeds capacity
function PointRegionQuadtreeNode.subdivide(self)
    local midX = (self.boundary.min_x + self.boundary.max_x) / 2
    local midY = (self.boundary.min_y + self.boundary.max_y) / 2

    self.northwest = PointRegionQuadtreeNode.new({min_x = self.boundary.min_x, min_y = midY, max_x = midX, max_y = self.boundary.max_y}, self.capacity)
    self.northeast = PointRegionQuadtreeNode.new({min_x = midX, min_y = midY, max_x = self.boundary.max_x, max_y = self.boundary.max_y}, self.capacity)
    self.southwest = PointRegionQuadtreeNode.new({min_x = self.boundary.min_x, min_y = self.boundary.min_y, max_x = midX, max_y = midY}, self.capacity)
    self.southeast = PointRegionQuadtreeNode.new({min_x = midX, min_y = self.boundary.min_y, max_x = self.boundary.max_x, max_y = midY}, self.capacity)

    self.divided = true
end


-- recursively inserts new point into quadtree
function PointRegionQuadtreeNode.insert(self, point, root_boundary)
    
    -- checks if the point even belongs to this node's range 
    if not self:belongs(point, root_boundary) then
        return false
    end

    -- base case of recursive calls: point simply gets added to node
    if #self.points < self.capacity and not self.divided then
        table.insert(self.points, point)
        return true
    
    -- recursively calls insert to insert point into appropriate node (which may or may need subdivisions)
    else

        if not self.divided then
            self:subdivide()

            -- re-inserts each point from the subdivided node to the appropriate quadrant
            for i = #self.points, 1, -1 do

                local removed_point = table.remove(self.points, i)

                if self.northwest:belongs(removed_point, root_boundary) then
                    self.northwest:insert(removed_point, root_boundary)
                elseif self.northeast:belongs(removed_point, root_boundary) then
                    self.northeast:insert(removed_point, root_boundary)
                elseif self.southwest:belongs(removed_point, root_boundary) then
                    self.southwest:insert(removed_point, root_boundary)
                else
                    self.southeast:insert(removed_point, root_boundary)
                end
            end
        end

        if self.northwest:belongs(point, root_boundary) then
            return self.northwest:insert(point, root_boundary)
        elseif self.northeast:belongs(point, root_boundary) then
            return self.northeast:insert(point, root_boundary)
        elseif self.southwest:belongs(point, root_boundary) then
            return self.southwest:insert(point, root_boundary)
        else
            return self.southeast:insert(point, root_boundary)
        end
    end
end


-- returns whether point belongs within the boundary of the current object 
function PointRegionQuadtreeNode.belongs(self, point, root_boundary)
    return point.x >= self.boundary.min_x 
    and point.y >= self.boundary.min_y
    and (point.y < self.boundary.max_y or (point.y == self.boundary.max_y and point.y == root_boundary.max_y)) 
    and (point.x < self.boundary.max_x or (point.x == self.boundary.max_x and point.x == root_boundary.max_x)) 
end


-- recursively draws entire point-region quadtree when called on root
function PointRegionQuadtreeNode.draw(self, model)
    local min_x, min_y, max_x, max_y = self.boundary.min_x, self.boundary.min_y, self.boundary.max_x, self.boundary.max_y

    local box = ipe.Path(model.attributes, {{
        type = "curve",
        closed = true,
        {type = "segment", ipe.Vector(min_x, min_y), ipe.Vector(max_x, min_y)},
        {type = "segment", ipe.Vector(max_x, min_y), ipe.Vector(max_x, max_y)},
        {type = "segment", ipe.Vector(max_x, max_y), ipe.Vector(min_x, max_y)},
        {type = "segment", ipe.Vector(min_x, max_y), ipe.Vector(min_x, min_y)}
    }})

    model:creation("Box around node", box)

    if self.divided then
        self.northwest:draw(model)
        self.northeast:draw(model)
        self.southwest:draw(model)
        self.southeast:draw(model)
    end
end




-- point quadtree class
local PointQuadtreeNode = {}

function PointQuadtreeNode.new(point, boundary)
    local instance = {
        point = point,
        boundary = boundary,
        northwest = nil,
        northeast = nil,
        southwest = nil,
        southeast = nil
    }

    -- instance methods
    instance.insert = PointQuadtreeNode.insert
    instance.belongs = PointQuadtreeNode.belongs
    instance.draw = PointQuadtreeNode.draw
    instance.to_string = PointQuadtreeNode.to_string

    return instance
end

-- returns string representation of entire point quadtree
function PointQuadtreeNode.to_string(self, depth)
    local indent = string.rep("         ", depth)
    local result = ""

    if depth == 0 then 
        result = "Root Node: " 
    end

    result = result .. "(" .. self.point.x .. ", " .. self.point.y .. ")\n"
    indent = string.rep("         ", depth + 1)

    result = result .. indent .. "Northwest: "
    if self.northwest then 
        result = result .. self.northwest:to_string(depth + 1) 
    else
        result = result .. "Null\n"
    end
    
    result = result .. indent .. "Northeast: "
    if self.northeast then 
        result = result .. self.northeast:to_string(depth + 1) 
    else
        result = result .. "Null\n"
    end
    
    result = result .. indent .. "Southwest: "
    if self.southwest then 
        result = result .. self.southwest:to_string(depth + 1)  
    else
        result = result .. "Null\n"
    end
    
    result = result .. indent .. "Southeast: "
    if self.southeast then 
        result = result .. self.southeast:to_string(depth + 1) 
    else
        result = result .. "Null\n"
    end

    return result
end

-- recursively inserts new point into quadtree
function PointQuadtreeNode.insert(self, point, root_boundary)

    -- checks if the point even belongs to this node's range 
    if not self:belongs(point, root_boundary) then
        return false
    end

    -- base case of recursive calls: point simply gets added to node
    if not self.point then
        self.point = point
        return true
        
    -- recursively calls insert to insert point into appropriate node (which may or may need subdivisions)
    else

        -- subdivision necessary
        if point.x < self.point.x then
            if point.y < self.point.y then
                if not self.southwest then
                    self.southwest = PointQuadtreeNode.new(nil, {min_x = self.boundary.min_x, min_y = self.boundary.min_y, max_x = self.point.x, max_y = self.point.y})
                end
                return self.southwest:insert(point, root_boundary)
            else
                if not self.northwest then
                    self.northwest = PointQuadtreeNode.new(nil, {min_x = self.boundary.min_x, min_y = self.point.y, max_x = self.point.x, max_y = self.boundary.max_y})
                end
                return self.northwest:insert(point, root_boundary)
            end
        else
            if point.y < self.point.y then
                if not self.southeast then
                    self.southeast = PointQuadtreeNode.new(nil, {min_x = self.point.x, min_y = self.boundary.min_y, max_x = self.boundary.max_x, max_y = self.point.y})
                end
                return self.southeast:insert(point, root_boundary)
            else
                if not self.northeast then
                    self.northeast = PointQuadtreeNode.new(nil, {min_x = self.point.x, min_y = self.point.y, max_x = self.boundary.max_x, max_y = self.boundary.max_y})
                end
                return self.northeast:insert(point, root_boundary)
            end
        end
    end
end


-- returns whether point belongs within the boundary of the current object 
function PointQuadtreeNode.belongs(self, point, root_boundary)
    return point.x >= self.boundary.min_x 
    and point.y >= self.boundary.min_y
    and (point.y < self.boundary.max_y or (point.y == self.boundary.max_y and point.y == root_boundary.max_y)) 
    and (point.x < self.boundary.max_x or (point.x == self.boundary.max_x and point.x == root_boundary.max_x)) 
end


-- recursively draws entire point quadtree when called on root
function PointQuadtreeNode.draw(self, model)
    if not self.point then return end

    local horizontal_line = ipe.Path(model.attributes, {{
        type = "curve",
        closed = false,
        {type = "segment", ipe.Vector(self.boundary.min_x, self.point.y), ipe.Vector(self.boundary.max_x, self.point.y)}
    }})
    model:creation("Horizontal line through point", horizontal_line)

    local vertical_line = ipe.Path(model.attributes, {{
        type = "curve",
        closed = false,
        {type = "segment", ipe.Vector(self.point.x, self.boundary.min_y), ipe.Vector(self.point.x, self.boundary.max_y)}
    }})
    model:creation("Vertical line through point", vertical_line)

    if self.northwest then self.northwest:draw(model) end
    if self.northeast then self.northeast:draw(model) end
    if self.southwest then self.southwest:draw(model) end
    if self.southeast then self.southeast:draw(model) end
end




local function get_unique_selected_points(model)
    local page = model:page()
    local points = {}

    -- goes through the selected objects on the page and adds the points to the points table
    for i, obj, sel, _ in page:objects() do
        if sel then
            if obj:type() == "reference" then
                local point = obj:position()

                for _, existing_point in ipairs(points) do

                    while existing_point.x == point.x do
                        if math.random() >= 0.5 then
                            point = ipe.Vector(point.x + 0.1, point.y)
                        else
                            point = ipe.Vector(point.x - 0.1, point.y)
                        end
                    end

                    while existing_point.y == point.y do
                        if math.random() >= 0.5 then
                            point = ipe.Vector(point.x, point.y + 0.1)
                        else
                            point = ipe.Vector(point.x, point.y - 0.1)
                        end
                    end
                end

                local dx, dy = point.x - obj:position().x, point.y - obj:position().y
                local new_matrix = obj:matrix() * ipe.Matrix(1, 0, 0, 1, dx, dy)
                obj:setMatrix(new_matrix)

                table.insert(points, point)
            end
        end
    end

    return points
end



-- gets coordinates of top left and bottom right vertices of the box 
local function get_box_vertices(points)

    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, point in ipairs(points) do
        if point.x < min_x then min_x = point.x end
        if point.x > max_x then max_x = point.x end
        if point.y < min_y then min_y = point.y end
        if point.y > max_y then max_y = point.y end
    end

    return {min_x = min_x, min_y = min_y, max_x = max_x, max_y = max_y}
end


-- draws the box on the page
local function draw_box(model, box)

    local box = ipe.Path(model.attributes, {{
        type = "curve",
        closed = true,
        {type = "segment", ipe.Vector(box.min_x, box.min_y), ipe.Vector(box.max_x, box.min_y)},
        {type = "segment", ipe.Vector(box.max_x, box.min_y), ipe.Vector(box.max_x, box.max_y)},
        {type = "segment", ipe.Vector(box.max_x, box.max_y), ipe.Vector(box.min_x, box.max_y)},
        {type = "segment", ipe.Vector(box.min_x, box.max_y), ipe.Vector(box.min_x, box.min_y)}
    }})
    
    model:creation("Box", box)
end


local function create_box_and_get_points(model)

    local points = get_unique_selected_points(model)

    -- no points were selected
    if #points < 1 then
        model:warning("Please select at least one point!")
        return
    end

    -- get coordinates of top left and bottom right vertices of the box 
    local box_vertices = get_box_vertices(points)

    -- draw the bounding box around selected points
    draw_box(model, box_vertices)

    return points
end

local function create_point_region_quadtree(model)

    -- ends if no points have been selected
    local unique_points = get_unique_selected_points(model)

    if #unique_points < 1 then
        model:warning("Please select at least one point!")
        return
    end

    -- getting max node capacity from user (has to be an integer greater than or equal to 1)

    local s = "Please enter an integer greater than or equal to 1.\nThis will be the maximum capacity of each node in the point-region quadtree."
    local d = ipeui.Dialog(model.ui:win(), "Input Validation")
    d:add("label1", "label", {label=s}, 1, 1, 1, 2)
    d:add("label2", "label", {label="Input:"}, 2, 1)
    d:add("input", "input", {}, 2, 2)

    d:add("checkbox_label", "label", {label="Check to print array format:"}, 3, 1)
    d:add("checkbox", "checkbox", {label=""}, 3, 2)

    d:addButton("ok", "&Ok", "accept")
    d:addButton("cancel", "&Cancel", "reject")
    d:setStretch("column", 2, 1)

    local num = -1
    local checkbox_checked
  
    while true do
      if not d:execute() then return end
      num = tonumber(d:get("input"))
      if num and num >= 1 and math.floor(num) == num then
        checkbox_checked = d:get("checkbox")
        break
      else
        ipeui.messageBox(model.ui:win(), "warning", "Invalid Input", "Please enter an integer greater than or equal to 1!")
      end
    end

    -- below only runs if user has inputted valid max node capacity value

    if num and num >= 1 and math.floor(num) == num then

        -- gets all selected points and draws bounding box
        local points = create_box_and_get_points(model)

        local boundary = get_box_vertices(points)
        local quadtree = PointRegionQuadtreeNode.new(boundary, num)

        -- insert all points into the quadtree
        for _, point in ipairs(points) do
            quadtree:insert(point, boundary)
        end

        quadtree:draw(model)

        if checkbox_checked then
        
            model:creation("", ipe.Text(model.attributes, quadtree:to_string(0), ipe.Vector(boundary.min_x, boundary.max_y + 25), 200))

            local s = "Copy the string representation of your quadtree!"
            local d = ipeui.Dialog(model.ui:win(), "Output")
            d:add("label1", "label", {label=s}, 1, 1, 1, 2)
            d:add("input", "input", {}, 2, 1, 1, 2)
            d:addButton("ok", "&Ok", "accept")
            d:setStretch("column", 2, 1)
            d:setStretch("column", 1, 1)
            d:set("input", quadtree:to_string(0))
            d:execute()
        end

    end
end


local function create_point_quadtree(model)

    -- ends if no points have been selected
    local unique_points = get_unique_selected_points(model)

    if #unique_points < 1 then
        model:warning("Please select at least one point!")
        return
    end

    local d = ipeui.Dialog(model.ui:win(), "Array Format Selection")

    d:add("checkbox_label", "label", {label="Check to print array format:"}, 3, 1)
    d:add("checkbox", "checkbox", {label=""}, 3, 2)

    d:addButton("ok", "&Ok", "accept")
    d:addButton("cancel", "&Cancel", "reject")
    d:setStretch("column", 2, 1)

    local checkbox_checked

    if not d:execute() then return end

    checkbox_checked = d:get("checkbox")

    -- gets all selected points and draws bounding box
    local points = create_box_and_get_points(model)

    if not points then return end

    local boundary = get_box_vertices(points)
    local quadtree = PointQuadtreeNode.new(nil, boundary)

    -- insert all points into the quadtree
    for _, point in ipairs(points) do
        quadtree:insert(point, boundary)
    end

    quadtree:draw(model)

    if checkbox_checked then

        model:creation("", ipe.Text(model.attributes, quadtree:to_string(0), ipe.Vector(boundary.min_x, boundary.max_y + 25), 200))

        local s = "Copy the string representation of your quadtree!"
        local d = ipeui.Dialog(model.ui:win(), "Output")
        d:add("label1", "label", {label=s}, 1, 1, 1, 2)
        d:add("input", "input", {}, 2, 1, 1, 2)
        d:addButton("ok", "&Ok", "accept")
        d:setStretch("column", 2, 1)
        d:setStretch("column", 1, 1)
        d:set("input", quadtree:to_string(0))
        d:execute()
    end

end
-- ========================================================================================================================
-- RANDOM POINT TRIANGULATION
revertOriginal = _G.revertOriginal
about = [[
    This ipelet generates random points inside a polygon using the triangulation of a simple polygon.
]]

function incorrect(title, model)
  model:warning(title)
end

function create_shape_from_vertices(v, model)
  local shape = { type = "curve", closed = true }
  for i = 1, #v - 1 do 
    table.insert(shape, { type = "segment", v[i], v[i+1] })
  end
  table.insert(shape, { type = "segment", v[#v], v[1] })
  return shape
end


function get_polygon_vertices(obj, model)
  local shape = obj:shape()
  local m = obj:matrix()
  local vertices = {}
  local vertex = m * shape[1][1][1]
  table.insert(vertices, vertex)
  for i = 1, #shape[1] do
    vertex = m * shape[1][i][2]
    table.insert(vertices, vertex)
  end
  return vertices
end

function get_pt_and_polygon_selection(model)
  local p = model:page()
  if not p:hasSelection() then 
    incorrect("Please select a polygon", model)
    return 
  end

  local pathObject = nil
  local count = 0
  for _, obj, sel, _ in p:objects() do
    if sel then
      count = count + 1
      if obj:type() == "path" then
        pathObject = obj
      end
    end
  end

  if count ~= 1 then 
    incorrect("Please select one item.", model)
    return 
  end

  local vertices = get_polygon_vertices(pathObject, model)
  return vertices
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
  local uniquePoints = {}
  for i = 1, #points do
    if not_in_table(uniquePoints, points[i]) then
      table.insert(uniquePoints, points[i])
    end
  end
  return uniquePoints
end


function triangleArea(A, B, C)
  return 0.5 * math.abs(A.x * (B.y - C.y) + B.x * (C.y - A.y) + C.x * (A.y - B.y))
end



function newNode(value)
  return { value = value, next = nil }
end


function newLinkedList()
  return { head = nil, length = 0 }
end


function ll_add(list, value)
  local node = newNode(value)
  if not list.head then
    list.head = node
  else
    local current = list.head
    while current.next do
      current = current.next
    end
    current.next = node
  end
  list.length = list.length + 1
end


function ll_remove(list, value)
  local current = list.head
  local previous = nil
  while current do
    if current.value == value then
      if previous then
        previous.next = current.next
      else
        list.head = current.next
      end
      list.length = list.length - 1
      return true
    end
    previous = current
    current = current.next
  end
  return false
end


function ll_next_loop(list, node)
  if not list.head then return nil end
  if node.next then
    return node.next
  else
    return list.head
  end
end


function ll_size(list)
  return list.length
end


function angleCCW(a, b)
  local dot = a.x * b.x + a.y * b.y
  local det = a.x * b.y - a.y * b.x
  local angle = math.atan2(det, dot)
  if angle < 0 then
    angle = 2 * math.pi + angle
  end
  return angle
end


function isConvex(vertex_prev, vertex, vertex_next)
  local a = { x = vertex_prev.x - vertex.x, y = vertex_prev.y - vertex.y }
  local b = { x = vertex_next.x - vertex.x, y = vertex_next.y - vertex.y }
  local internal_angle = angleCCW(b, a)
  return internal_angle <= math.pi
end


function insideTriangle(a, b, c, p)
  local v0 = { x = c.x - a.x, y = c.y - a.y }
  local v1 = { x = b.x - a.x, y = b.y - a.y }
  local v2 = { x = p.x - a.x, y = p.y - a.y }
  
  local dot00 = v0.x * v0.x + v0.y * v0.y
  local dot01 = v0.x * v1.x + v0.y * v1.y
  local dot02 = v0.x * v2.x + v0.y * v2.y
  local dot11 = v1.x * v1.x + v1.y * v1.y
  local dot12 = v1.x * v2.x + v1.y * v2.y
  
  local denom = dot00 * dot11 - dot01 * dot01
  if math.abs(denom) < 1e-20 then
    return true
  end
  local invDenom = 1.0 / denom
  local u = (dot11 * dot02 - dot01 * dot12) * invDenom
  local v = (dot00 * dot12 - dot01 * dot02) * invDenom
  
  return (u >= 0) and (v >= 0) and (u + v < 1)
end


function triangulate(vertices, model) 
  local triangles={}
  local n = #vertices
  local indices = {}  

  local vertlist = newLinkedList()
  for i = 1, n do
    ll_add(vertlist, i)
  end

  --local index_counter = 1
  local node = vertlist.head
  while ll_size(vertlist) > 2 do
    local i = node.value
    local j = ll_next_loop(vertlist, node).value
    local k = ll_next_loop(vertlist, ll_next_loop(vertlist, node)).value

    local vert_prev = vertices[i]
    local vert_current = vertices[j]
    local vert_next = vertices[k]
    
    local is_convex = isConvex(vert_prev, vert_current, vert_next)
    local is_ear = true
    if is_convex then
      local test_node = ll_next_loop(vertlist, ll_next_loop(vertlist, ll_next_loop(vertlist, node)))
      while test_node ~= node and is_ear do
        local vert_test = vertices[test_node.value]
        is_ear = not insideTriangle(vert_prev, vert_current, vert_next, vert_test)
        test_node = ll_next_loop(vertlist, test_node)
      end
    else
      is_ear = false
    end

    -- temp
    --[[
    if is_ear then
      indices[index_counter] = {vert_prev, vert_current, vert_next}
      index_counter = index_counter + 1
      ll_remove(vertlist, ll_next_loop(vertlist, node).value)
    end
    --]]
    
    if is_ear then
    --   local triangle = { vert_prev, vert_current, vert_next }
      local triangle_objs = { ipe.Vector(vert_prev.x, vert_prev.y), ipe.Vector(vert_current.x, vert_current.y), ipe.Vector(vert_next.x, vert_next.y)}
      local Tri = create_shape_from_vertices(triangle_objs, model)
      table.insert(triangles, triangle_objs)
      ll_remove(vertlist, j)
    end

    node = ll_next_loop(vertlist, node)
  end

  return triangles
end

--[=[
    Given: 
        
{vertices}
  Return:
{vertices ordered in clockwise fashion}
]=]
function reorient_ccw(vertices)
    if orient(vertices[1], vertices[2], vertices[3]) < 0 then
        return reverse_list(vertices)
    end
    return vertices
end

function orient(p, q, r)
    local val = p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)
    return val
end

function reverse_list(lst)
    local i = 1
    local j = #lst
    while i < j do
        local temp = lst[i]
        lst[i] = lst[j]
        lst[j] = temp
        i = i + 1
        j = j -1
    end

    return lst
end

-- Ok this guy should give us the area of a triangle
function triangleArea(A, B, C)
    return 0.5 * math.abs(A.x*(B.y - C.y) + B.x*(C.y - A.y) + C.x*(A.y - B.y))
end

-- Function to generate random points inside the convex polygon
function generateRandomPoints(numPoints, polygon)
  local triangles = triangulate(reorient_ccw(polygon), model)
  local points = {}
  local totalMass = 0
  
  for _, tri in ipairs(triangles) do
    totalMass = totalMass+triangleArea(tri[1],tri[2],tri[3])
  end
  
  
  -- This is 100% not the best way to do this, I know, but we just keep adding weight until it's greater than choice
  for i = 1, numPoints do
    local currentMass = 0
    local choice = math.random()*totalMass
    for _, tri in ipairs(triangles) do
      currentMass=currentMass+triangleArea(tri[1],tri[2],tri[3])
      if currentMass>=choice then 
        local randomPoint = randomPointInTriangle(tri[1], tri[2], tri[3])
        table.insert(points, randomPoint)
        break
      end
    end
  end

  return points
end


-- Function to generate a random point inside a triangle
function randomPointInTriangle(p1, p2, p3)
  -- Get two random numbers between 0 and 1
  local u = math.random()
  local v = math.random()

  -- Make sure they aleways add up to less than or equal to 1
  if u + v > 1 then
    u = 1 - u
    v = 1 - v
  end

  -- This uses barycentric coordinates 
  local x = (1 - u - v) * p1.x + u * p2.x + v * p3.x
  local y = (1 - u - v) * p1.y + u * p2.y + v * p3.y
  -- returns the thing
  return {x = x, y = y}
end

function runRandomPointTriangulation(model)
    -- Set the seed for random generation (optional but useful for reproducibility)
    math.randomseed()
    local amount = model:getString("How many points to place?")

    local vertices = get_pt_and_polygon_selection(model)

    local points = generateRandomPoints(amount, unique_points(vertices))
  
    for i = 1, amount, 1 do
      -- Add the point
      local pointObj = ipe.Reference(
                                    model.attributes,
                                    model.attributes.markshape, 
                                    ipe.Vector(points[i].x, points[i].y)
                            )
            model:creation("A random Point", pointObj)
    end
end
-- ========================================================================================================================
-- SIERPINSKI'S TRIANGLE
about = "Creates Sierpinski's carpet out of a provided square" 

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



function runSierpinskiCarpet(model)
    local depth = tonumber(model:getString("Enter Depth"))
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

    sierpinski_carpet(vu, depth, model)
end

-- ========================================================================================================================
-- SIERPINSKI'S CARPET
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

function runSierpinskiTriangle(model)
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

-- ========================================================================================================================
-- TRIANGULATE
revertOriginal = _G.revertOriginal
about = [[
    This ipelet triangulates a simple polygon.
]]

function incorrect(title, model)
  model:warning(title)
end

function create_shape_from_vertices(v, model)
  local shape = { type = "curve", closed = true }
  for i = 1, #v - 1 do 
    table.insert(shape, { type = "segment", v[i], v[i+1] })
  end
  table.insert(shape, { type = "segment", v[#v], v[1] })
  return shape
end


function get_polygon_vertices(obj, model)
  local shape = obj:shape()
  local m = obj:matrix()
  local vertices = {}
  local vertex = m * shape[1][1][1]
  table.insert(vertices, vertex)
  for i = 1, #shape[1] do
    vertex = m * shape[1][i][2]
    table.insert(vertices, vertex)
  end
  return vertices
end

function get_pt_and_polygon_selection(model)
  local p = model:page()
  if not p:hasSelection() then 
    incorrect("Please select a polygon", model)
    return 
  end

  local pathObject = nil
  local count = 0
  for _, obj, sel, _ in p:objects() do
    if sel then
      count = count + 1
      if obj:type() == "path" then
        pathObject = obj
      end
    end
  end

  if count ~= 1 then 
    incorrect("Please select one item.", model)
    return 
  end

  local vertices = get_polygon_vertices(pathObject, model)
  return vertices
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
  local uniquePoints = {}
  for i = 1, #points do
    if not_in_table(uniquePoints, points[i]) then
      table.insert(uniquePoints, points[i])
    end
  end
  return uniquePoints
end


function triangleArea(A, B, C)
  return 0.5 * math.abs(A.x * (B.y - C.y) + B.x * (C.y - A.y) + C.x * (A.y - B.y))
end



function newNode(value)
  return { value = value, next = nil }
end


function newLinkedList()
  return { head = nil, length = 0 }
end


function ll_add(list, value)
  local node = newNode(value)
  if not list.head then
    list.head = node
  else
    local current = list.head
    while current.next do
      current = current.next
    end
    current.next = node
  end
  list.length = list.length + 1
end


function ll_remove(list, value)
  local current = list.head
  local previous = nil
  while current do
    if current.value == value then
      if previous then
        previous.next = current.next
      else
        list.head = current.next
      end
      list.length = list.length - 1
      return true
    end
    previous = current
    current = current.next
  end
  return false
end


function ll_next_loop(list, node)
  if not list.head then return nil end
  if node.next then
    return node.next
  else
    return list.head
  end
end


function ll_size(list)
  return list.length
end


function angleCCW(a, b)
  local dot = a.x * b.x + a.y * b.y
  local det = a.x * b.y - a.y * b.x
  local angle = math.atan2(det, dot)
  if angle < 0 then
    angle = 2 * math.pi + angle
  end
  return angle
end


function isConvex(vertex_prev, vertex, vertex_next)
  local a = { x = vertex_prev.x - vertex.x, y = vertex_prev.y - vertex.y }
  local b = { x = vertex_next.x - vertex.x, y = vertex_next.y - vertex.y }
  local internal_angle = angleCCW(b, a)
  return internal_angle <= math.pi
end


function insideTriangle(a, b, c, p)
  local v0 = { x = c.x - a.x, y = c.y - a.y }
  local v1 = { x = b.x - a.x, y = b.y - a.y }
  local v2 = { x = p.x - a.x, y = p.y - a.y }
  
  local dot00 = v0.x * v0.x + v0.y * v0.y
  local dot01 = v0.x * v1.x + v0.y * v1.y
  local dot02 = v0.x * v2.x + v0.y * v2.y
  local dot11 = v1.x * v1.x + v1.y * v1.y
  local dot12 = v1.x * v2.x + v1.y * v2.y
  
  local denom = dot00 * dot11 - dot01 * dot01
  if math.abs(denom) < 1e-20 then
    return true
  end
  local invDenom = 1.0 / denom
  local u = (dot11 * dot02 - dot01 * dot12) * invDenom
  local v = (dot00 * dot12 - dot01 * dot02) * invDenom
  
  return (u >= 0) and (v >= 0) and (u + v < 1)
end


function triangulate(vertices, model) 
  local n = #vertices
  local indices = {}  

  local vertlist = newLinkedList()
  for i = 1, n do
    ll_add(vertlist, i)
  end

  --local index_counter = 1
  local node = vertlist.head
  while ll_size(vertlist) > 2 do
    local i = node.value
    local j = ll_next_loop(vertlist, node).value
    local k = ll_next_loop(vertlist, ll_next_loop(vertlist, node)).value

    local vert_prev = vertices[i]
    local vert_current = vertices[j]
    local vert_next = vertices[k]
    
    local is_convex = isConvex(vert_prev, vert_current, vert_next)
    local is_ear = true
    if is_convex then
      local test_node = ll_next_loop(vertlist, ll_next_loop(vertlist, ll_next_loop(vertlist, node)))
      while test_node ~= node and is_ear do
        local vert_test = vertices[test_node.value]
        is_ear = not insideTriangle(vert_prev, vert_current, vert_next, vert_test)
        test_node = ll_next_loop(vertlist, test_node)
      end
    else
      is_ear = false
    end

    -- temp
    --[[
    if is_ear then
      indices[index_counter] = {vert_prev, vert_current, vert_next}
      index_counter = index_counter + 1
      ll_remove(vertlist, ll_next_loop(vertlist, node).value)
    end
    --]]
    
    if is_ear then
    --   local triangle = { vert_prev, vert_current, vert_next }
      local triangle_objs = { ipe.Vector(vert_prev.x, vert_prev.y), ipe.Vector(vert_current.x, vert_current.y), ipe.Vector(vert_next.x, vert_next.y)}
      local Tri = create_shape_from_vertices(triangle_objs, model)
      model:creation("Triangle", ipe.Path(model.attributes, { Tri }))
      ll_remove(vertlist, j)
    end

    node = ll_next_loop(vertlist, node)
  end

  return indices
end

--[=[
    Given: 
        
{vertices}
  Return:
{vertices ordered in clockwise fashion}
]=]
function reorient_ccw(vertices)
    if orient(vertices[1], vertices[2], vertices[3]) < 0 then
        return reverse_list(vertices)
    end
    return vertices
end

function orient(p, q, r)
    local val = p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)
    return val
end

function reverse_list(lst)
    local i = 1
    local j = #lst
    while i < j do
        local temp = lst[i]
        lst[i] = lst[j]
        lst[j] = temp
        i = i + 1
        j = j -1
    end

    return lst
end

function runTriangulate(model)
  math.randomseed()
  local vertices = get_pt_and_polygon_selection(model)
  
  if vertices then
    triangulate(reorient_ccw(vertices), model)
  end
end
-- ========================================================================================================================
-- TRAPEZOIDAL MAP
about = "Given a set of Line Segments and an optional Bounding Box, returns a Trapezoidal Map"

function incorrect(title, model) model:warning(title) end

function display(title, message, model) 
    local s = title
    local d = ipeui.Dialog(model.ui:win(), "Output")
    d:add("label1", "label", {label=s}, 1, 1, 1, 2)
    d:add("input", "input", {}, 2, 1, 1, 2)
    d:addButton("ok", "&Ok", "accept")
    d:setStretch("column", 2, 1)
    d:setStretch("column", 1, 1)
    d:set("input", message)
    d:execute()
end

function dump(o)
    if _G.type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if _G.type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
         do return s .. '} ' end
       end
       
    else
       return tostring(o)
    end
 end


 function get_polygon_segments(obj, model)

	local shape = obj:shape()
	local transform = obj:matrix()

	local segment_matrix = shape[1]

	local segments = {}
	for _, segment in ipairs(segment_matrix) do
		table.insert(segments, ipe.Segment(transform * segment[1], transform * segment[2]))
	end
	 
	table.insert(
		segments,
		ipe.Segment(transform * segment_matrix[#segment_matrix][2], transform * segment_matrix[1][1])
	)

	return segments
end

function in_box(bbox, startPoint, endPoint)
    local x_min, x_max, y_min, y_max = bbox[1], bbox[2], bbox[3], bbox[4]
    if ((x_min <= endPoint.x and endPoint.x <= x_max) and
        (x_min <= startPoint.x and startPoint.x <= x_max) and
        (y_min <= endPoint.y and endPoint.y <= y_max) and
        (y_min <= startPoint.y and startPoint.y <= y_max)) then
            return true
        else
            return false
        end
end

function get_pt_and_polygon_selection(model)
	local p = model:page()

    if not p:hasSelection() then
        incorrect(dump("Nothing Selected"), model)
        return
	end

	local count = 0

    local path_objects = {}

	for _, obj, sel, _ in p:objects() do
        if sel then
            count = count + 1
            if obj:type() == "path" then 
                table.insert(path_objects, obj)
            end
        end
	end

    local segments_table = {}
    local bounding_box = {}

    for i = 1, #path_objects do
        local segments = get_polygon_segments(path_objects[i], model)
        if #segments == 4 then
            table.insert(bounding_box, segments)
        else
            table.insert(segments_table, segments)
        end
    end

    -- Store the points of selected Line Segments and Calculate
    -- the max and min (extremities) of all coordinates

    local output_table = {{}, {}, {}}

    local x_min, y_min, x_max, y_max = math.huge, math.huge, -1 * math.huge, -1 * math.huge


    if #bounding_box ~= 0 then
        x_min = bounding_box[1][1]:endpoints().x 
        y_min = bounding_box[1][2]:endpoints().y 
        x_max = bounding_box[1][3]:endpoints().x 
        y_max = bounding_box[1][1]:endpoints().y 
    end


    for i = 1, #segments_table do
        local startPoint, endPoint = segments_table[i][1]:endpoints()
        if #bounding_box == 0 then
            x_min = math.min(endPoint.x, startPoint.x, x_min)
            y_min = math.min(endPoint.y, startPoint.y, y_min)
            x_max = math.max(endPoint.x, startPoint.x, x_max)
            y_max = math.max(endPoint.y, startPoint.y, y_max)
        end


        if (startPoint.x > endPoint.x) then -- Ensures Line Segments are organized left to right
            if (#bounding_box == 0 or in_box({x_min, x_max, y_min, y_max}, startPoint, endPoint)) then
                table.insert(output_table[1], {{endPoint.x, startPoint.x}, {endPoint.y, startPoint.y}})
            else
                display("The Following Segment was Ignored - Please Ensure it is fully contained in the bounding box", 
                        tableToString({{endPoint.x, startPoint.x}, {endPoint.y, startPoint.y}}), model)
            end
        else
            if (#bounding_box == 0 or in_box({x_min, x_max, y_min, y_max}, startPoint, endPoint)) then
                table.insert(output_table[1], {{startPoint.x, endPoint.x}, {startPoint.y, endPoint.y}})
            else
                display("The Following Segment was Ignored - Please Ensure it is fully contained in the bounding box", 
                        tableToString({{startPoint.x, endPoint.x}, {startPoint.y, endPoint.y}}), model)
            end
        end

    end

    if  #output_table[1] ~= #segments_table then
        incorrect(dump("Some Points were Ignored - Please draw the Bounding Box after modifying (Translating, Shearing...) segments"), model)
    end

    local scale = 20

    if #bounding_box == 0 then -- bounding box not given
        table.insert(output_table[2], {{x_min - scale, x_max + scale}, {y_min - scale, y_max + scale}})
        table.insert(output_table[3], false)
    else -- bounding box given
        table.insert(output_table[2], {{x_min, x_max}, {y_min, y_max}})
        table.insert(output_table[3], true)
    end
        
	return output_table
end

function create_boundary(x_min, x_max, y_min, y_max, scale, model)

    -- Draws a Boundary around the highlighted line sections

    local start = ipe.Vector(x_min - scale , y_min - scale) 
    local finish = ipe.Vector(x_max + scale, y_min - scale) 

    local segment = {type="segment", start, finish}
    local shape = { type="curve", closed=false, segment}
    local pathObj = ipe.Path(model.attributes, { shape })

    model:creation("create basic path", pathObj) 

    local start = ipe.Vector(x_min - scale, y_min - scale) 
    local finish = ipe.Vector(x_min - scale, y_max + scale)

    local segment = {type="segment", start, finish}
    local shape = { type="curve", closed=false, segment}
    local pathObj = ipe.Path(model.attributes, { shape })

    model:creation("create basic path", pathObj) 

    local start = ipe.Vector(x_min -  scale, y_max + scale) 
    local finish = ipe.Vector(x_max + scale, y_max + scale) 

    local segment = {type="segment", start, finish}
    local shape = { type="curve", closed=false, segment}
    local pathObj = ipe.Path(model.attributes, { shape })

    model:creation("create basic path", pathObj) 

    local start = ipe.Vector(x_max + scale, y_min - scale) 
    local finish = ipe.Vector(x_max + scale, y_max + scale)

    local segment = {type="segment", start, finish}
    local shape = { type="curve", closed=false, segment}
    local pathObj = ipe.Path(model.attributes, { shape })

    model:creation("create basic path", pathObj) 

end

function tableToString(tbl, indent)
    indent = ""
    local str = "{"
    for i, v in ipairs(tbl) do
        if _G.type(v) == 'table' then
            str = str .. tableToString(v, indent .. "  ")
        else
            str = str .. tostring(v)
        end
        if i < #tbl then
            str = str .. ", "
        end
    end
    str = str .. indent .. "}"
    return str
end


function runTrapezoidalMap(model)
    local everything = get_pt_and_polygon_selection(model) 

    local inpt = everything[1]
    local bbox = everything[2][1]
    local given = everything[3][1]


    local x_min = math.max(0, bbox[1][1])
    local x_max = bbox[1][2]
    local y_min = math.max(0, bbox[2][1])
    local y_max = bbox[2][2]

    if given == false then create_boundary(x_min, x_max, y_min, y_max, 0, model) end

    local outp = {}
    for i = 1, #inpt do
         

        local a1, a2 = inpt[i][1][1], inpt[i][1][2]
        local b1, b2 = inpt[i][2][1], inpt[i][2][2]

        local arr_outp = {{a1, b1}, {a2, b2}}

        table.insert(arr_outp, {a1, y_min})
        table.insert(arr_outp, {a1, y_max})
        table.insert(arr_outp, {a2, y_min})
        table.insert(arr_outp, {a2, y_max})

        table.insert(outp, arr_outp)
    end

    
    for segment_index = 1, #outp do
        local segments = outp[segment_index]
        local left, right = segments[1], segments[2]
        for i = 3, #segments do
            for j = 1, #inpt do

                local a1, b1, a2, b2

                if (i == 3 or i == 4) then
                    a1, b1, a2, b2 = left[1], left[2], left[1], segments[i][2]
                else
                    a1, b1, a2, b2 = right[1], right[2], right[1], segments[i][2]   
                end

                local x1, x2 = inpt[j][1][1], inpt[j][1][2]
                local y1, y2 = inpt[j][2][1], inpt[j][2][2]
                
                if (not ((x2 == a1 and y2 == b1) or (a1 == x1 and b1 == y1)) and (x1 <= a1 and a1 <= x2)) then

                    local function f(x)
                        local m = (y2 - y1) / (x2 - x1)
                        local b = y1 - m * x1
                        return m * x + b
                    end
        
                    local func = f(a1)

                    if ((b2 <= func and func <= b1) or (b1 <= func and func <= b2)) then
                        segments[i][2] = func
                    end
                end
            end
        end
    end
    
    for segment_index = 1, #outp do
        local segments = outp[segment_index]
        local left, right = segments[1], segments[2]

        local a1, b1, a2, b2

        for i = 3, #segments do
            if (i == 3 or i == 4) then
                a1, b1, a2, b2 = left[1], left[2], left[1], segments[i][2]
            else
                a1, b1, a2, b2 = right[1], right[2], right[1], segments[i][2]
            end
        
            local start = ipe.Vector(a1,b1)
            local finish = ipe.Vector(a2,b2)

            local segment = {type="segment", start, finish}
            local shape = { type="curve", closed=false, segment}
            local pathObj = ipe.Path(model.attributes, { shape })
            pathObj:set("stroke", "red")

            model:creation("create basic path", pathObj)
        end
    end


    display("Array of Segments in the form [Left Endpoint, Right Endpoint, Lower Left Point, Upper Left Point, Lower Right Point, Upper Right Point]",tableToString(outp, ""), model)
end
-- ========================================================================================================================

methods = {
    { label = "Beta Skeleton", run = runBetaSkeleton},
    { label = "Random Point Triangulation", run = runRandomPointTriangulation},
    { label = "Trapezoidal Map", run = runTrapezoidalMap},
    { label = "Onion Peeling", run = runOnionPeeling},
    { label = "Floating Body", run = runFloatingBody},
    { label = "Quadtree", run = create_point_region_quadtree},
    { label = "Point Quadtree", run = create_point_quadtree},
    { label = "Triangulate", run = runTriangulate},
    { label = "Sierpinski's Triangle", run = runSierpinskiTriangle},
    { label = "Sierpinski's Carpet", run = runSierpinskiCarpet},
    { label = "Dragon Curve", run = runDragonCurve},
}