-- This ipelet creates the beta Skeleton of a set of points..
label = "Beta Skeleton"
revertOriginal = _G.revertOriginal
about = [[
    This ipelet creates the beta Skeleton of a set of points.
]]

-- ========================================================================================================================

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

function run(model)
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