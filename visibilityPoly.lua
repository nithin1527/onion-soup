-- TIPS
-- 1. for debugging: --> model:warning(tostring(V[i]))
label = "Visibility Polygon"
about = "Replace with description of the ipelet"

Ray = {
    obstacle_id = nil,
    tip_point = nil,
    boundary_point = nil
}

function Ray.new(obstacle_id, tip_point, boundary_point)
    local ray = {}
    ray.obstacle_id = obstacle_id
    ray.tip_point = tip_point
    ray.boundary_point = boundary_point
    return ray
end

local function get_polygon_vertices(obj, model)
    local shape = obj:shape()
    local polygon = obj:matrix()

    local vertices = {}

    local vertex = polygon * shape[1][1][1]
    table.insert(vertices, vertex)

    for i = 1, #shape[1] do
        vertex = polygon * shape[1][i][2]
        table.insert(vertices, vertex)
    end

    return vertices
end

local function get_polygon_segments(obj, model)
    local shape = obj:shape()
    local segment_matrix = shape[1]
    local transform = obj:matrix()

    local segments = {}
    for _, segment in ipairs(segment_matrix) do
        table.insert(segments, ipe.Segment(transform * segment[1], transform * segment[2]))
    end

    table.insert(segments, ipe.Segment(transform * segment_matrix[#segment_matrix][2], transform * segment_matrix[1][1]))

    return segments
end

local function collect_pt_polygons_vertices(model)
    local p = model:page()
    local point = nil
    local polygons = {}
    local vertices = {}
    local all_vertices = {}

    for _, obj, sel, _ in p:objects() do
        if sel then
            local transform = obj:matrix()
            if obj:type() == "path" then
                table.insert(polygons, obj)
                table.insert(vertices, get_polygon_vertices(obj, model))
            end
            if obj:type() == "reference" then
                point = transform * obj:position()
            end
        end
    end

    return point, polygons, vertices
end

-- gets coordinates of top left and bottom right vertices of the box 
local function get_bounding_box_verts(vertices, want_non_ipe_form, model)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for i = 1, #vertices do
        for j = 1, #vertices[i] do
            local vertex = vertices[i][j]

            if vertex.x < minX then
                minX = vertex.x
            end
            if vertex.x > maxX then
                maxX = vertex.x
            end
            if vertex.y < minY then
                minY = vertex.y
            end
            if vertex.y > maxY then
                maxY = vertex.y
            end
        end
    end

    if want_non_ipe_form then
        return {minX, minY, maxX, maxY}
    end

    return {ipe.Vector(minX, minY), ipe.Vector(minX, maxY), ipe.Vector(maxX, maxY), ipe.Vector(maxX, minY)}
end

local function get_bounding_box(polygons, bbox_verts, model)
    for i = 1, #polygons do
        local polygon = polygons[i]
        local vertices = get_polygon_vertices(polygon, model)
        local count = 0
        for j = 1, #vertices do
            for k = 1, #bbox_verts do
                if bbox_verts[k] == vertices[j] then
                    count = count + 1
                end
            end
        end
        if count >= 3 then -- any way to make this more adaptable for any polygon instead of a box
            return polygon
        end
    end
    return nil
end

local function euclidean_distance(p1, p2)
    return math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2)
end

local function point_on_seg(A, B, P)
    local bool = false
    local AB = math.sqrt((A.x - B.x) ^ 2 + (A.y - B.y) ^ 2)
    local AP = math.sqrt((A.x - P.x) ^ 2 + (A.y - P.y) ^ 2)
    local PB = math.sqrt((P.x - B.x) ^ 2 + (P.y - B.y) ^ 2)
    if (AP + PB <= AB + .0001) and (AP + PB >= AB - .0001) then
        bool = true
    end
    return bool

end

local function nextIndexWrap(v, pos)
    local pos = (pos % #v) + 1
    return pos
end

local function point_on_polygon_boundary(arr, point)
    for i = 1, #arr do
        if point_on_seg(arr[i], arr[nextIndexWrap(arr, i)], point) then
            return true
        end
    end
    return false
end

local function is_in_vertices(all_vertices, point, model)
    for i = 1, #all_vertices do
        for j = 1, #all_vertices[i] do
            if all_vertices[i][j].x == point.x and all_vertices[i][j].y == point.y then
                return true
            end
        end
    end
    return false
end

local function not_in_table(vectors, vector_comp)
    local flag = true
    for _, vertex in ipairs(vectors) do
        if vertex == vector_comp then
            flag = false
        end
    end
    return flag
end

local function is_same_line_equation(ray1, ray2, point, model)
    local p1, q1 = ray1:endpoints()
    local p2, q2 = ray2:endpoints()

    -- first check if the rays are in the same direction
    if (q1.x >= p1.x and q2.x >= p2.x) or (q1.x <= p1.x and q2.x <= p2.x) then
        local m1 = (q1.y - p1.y) / (q1.x - p1.x)
        local m2 = (q2.y - p2.y) / (q2.x - p2.x)

        -- float/double checking might mess this up
        if m1 ~= m2 then
            return false
        end

        -- Check if both lines satisfy the same y-intercept (b = y - mx)
        local b1 = p1.y - m1 * p1.x
        local b2 = p2.y - m2 * p2.x

        return b1 == b2
    end
end

local function valid_intersection(bbox_verts, intersection)
    local bottomLeft, topLeft, topRight, bottomRight = table.unpack(bbox_verts)
    if intersection.x >= bottomLeft.x and intersection.x <= topRight.x and intersection.y >= bottomRight.y and
        intersection.y <= topLeft.y then
        return true
    end
    return false
end

function centroid(vertices)
    local sum_x, sum_y = 0, 0
    local n = #vertices
    for i = 1, n do
        sum_x = sum_x + vertices[i].x
        sum_y = sum_y + vertices[i].y
    end
    return {x = sum_x / n, y = sum_y / n}
end

function fattenPolygon(vertices)
    local centroid = centroid(vertices)
    local epsilon = 0.001;
    local newVertices = {}
    for i = 1, #vertices do
        local dx = vertices[i].x - centroid.x
        local dy = vertices[i].y - centroid.y
        local newVertex = {
            x = centroid.x + (1 + epsilon) * dx,
            y = centroid.y + (1 + epsilon) * dy
        }
        local new_v = ipe.Vector(newVertex.x, newVertex.y)
        table.insert(newVertices, new_v)
    end
    return newVertices
end

local function visibility_polygon(point, polygons, all_vertices, bbox, bbox_verts, model)
    local V = {}
    local V_close = {}
    local V_extended = {}
    local rays = {}

    local rayObjs = {}

    -- PART 1: FIND BASE SEGMENTS
    
    for i = 1, #polygons do
        local polygon = polygons[i]
        if polygon ~= bbox then
            local segments = get_polygon_segments(polygon, model)
            local vertices = get_polygon_vertices(polygon, model)
            -- local vertices = fattenPolygon(get_polygon_vertices(polygon, model))

            for j = 1, #vertices do
                local intersections = {}
                local v = vertices[j]

                local ray = ipe.Segment(point, v)

                -- prevents creating duplicated rays
                local ray_is_present = false
                for a = 1, #rays do
                    local temp_ray = rays[a]
                    local p_temp, q_temp = temp_ray:endpoints()
                    local p, q = ray:endpoints()

                    if (p == p_temp and q == q_temp) then
                        ray_is_present = true
                    end
                end

                if not ray_is_present then
                    -- store all intersections of the current polygon's current vertex and ray (case 1)
                    for k = 1, #segments do
                        -- case 1
                        local seg = segments[k]
                        local intersection = seg:intersects(ray)
                        if intersection then
                            table.insert(intersections, intersection)
                        end
                    end

                    -- case 2: edge case of other polygons in the way to the currently processing polygon
                    for x = 1, #polygons do
                        if polygons[x] ~= polygon then
                            local segs = get_polygon_segments(polygons[x], model)
                            for y = 1, #segs do
                                local intersection_pt = segs[y]:intersects(ray)
                                if intersection_pt and not is_in_vertices(all_vertices, intersection_pt, model) then
                                    table.insert(intersections, intersection_pt)
                                end
                            end
                        end
                    end

                    -- case 1: normal vertex intersection
                    if #intersections == 2 then
                        if intersections[1] == intersections[2] then
                            table.insert(V, v)
                            table.insert(rays, ray)
                            table.insert(rayObjs, Ray.new(i, v, nil))
                            table.insert(V_close, v)

                        elseif point.x == v.x or point.y == v.y then
                            local dist1 = euclidean_distance(point, intersections[1])
                            local dist2 = euclidean_distance(point, intersections[2])
                            local closest = (dist1 > dist2) and intersections[1] or intersections[2]
                            local not_closest = (dist1 > dist2) and intersections[2] or intersections[1]
                            
                            table.insert(V, closest)
                            table.insert(rays, ray)
                            table.insert(rays, ray)
                            table.insert(rayObjs, Ray.new(i, closest, nil))
                            table.insert(rayObjs, Ray.new(i, not_closest, nil))
                            table.insert(V_close, not_closest)
                            table.insert(V_close, closest)
                        end
                    end
                end
            end
        end
    end

    -- PART 2: FIND SEGMENTS TO *NOT* EXTEND
    local bad_rays = {}
    -- if i draw a line that intersects anywhere else on one of the ray polygons besides the ray vertex, skip processing that line
    for i = 1, #rays do
        local ray = rays[i]
        local _, ray_vertex = ray:endpoints()

        -- store all polygons that ray vertex is part of (overlapping case)
        local ray_polys = {}
        for _, polygon in ipairs(polygons) do
            local vertices = get_polygon_vertices(polygon)
            if point_on_polygon_boundary(vertices, ray_vertex) then
                table.insert(ray_polys, polygon)
            end
        end

        -- guaranteed to be a bad ray
        if #ray_polys > 1 and not_in_table(ray_polys, bbox) then
            table.insert(bad_rays, ray)
        end

        -- core logic for finding bad rays
        local extended = ray:line()
        for _, ray_poly in ipairs(ray_polys) do
            for _, ray_poly_seg in ipairs(get_polygon_segments(ray_poly)) do
                local intersection = ray_poly_seg:intersects(extended)
                if intersection and intersection ~= point and intersection ~= ray_vertex and
                    valid_intersection(bbox_verts, intersection) then -- ensure intersection is within bounding box
                    -- conditional below prevents ALL horizontal/vertical lines from being considered a bad ray
                    if ray_vertex.x ~= point.x and ray_vertex.y ~= point.y then
                        table.insert(bad_rays, ray)
                    else -- only vertical and horizontal lines will be considered here
                        if #ray_polys > 1 then
                            table.insert(bad_rays, ray)
                        elseif point_on_polygon_boundary(get_polygon_vertices(ray_poly), intersection) and
                            not is_in_vertices(all_vertices, intersection) then -- only cases left are invalid or intersects same polygon multiple times
                            table.insert(bad_rays, ray)
                        end
                    end
                end
            end
        end
    end

    -- PART 3: EXTEND THE GOOD SEGMENTS
    for i = 1, #rays do
        local ray = rays[i]

        -- check if current ray should be processed
        local is_good_ray = true
        for b = 1, #bad_rays do
            if is_same_line_equation(ray, bad_rays[b], point, model) then
                is_good_ray = false
            end
        end

        if is_good_ray then
            local extended_intersections = {}
            local _, ray_vertex = ray:endpoints()

            local extended = ray:line()

            for _, polygon in ipairs(polygons) do
                -- core logic here on assumption that only lines that need to be extended are being processed
                local segments = get_polygon_segments(polygon)
                for _, segment in ipairs(segments) do
                    local intersection = segment:intersects(extended) -- DO NOT CHANGE
                    if intersection and intersection ~= point and intersection ~= ray_vertex then -- including intersections that are not p and q
                        table.insert(extended_intersections, intersection)
                    end
                end
            end

            local filtered_intersections = {}
            -- get all intersections in same direction as original ray
            for _, intersection in ipairs(extended_intersections) do
                if (ray_vertex.x > point.x and intersection.x > ray_vertex.x) then
                    table.insert(filtered_intersections, intersection)
                end
                if (ray_vertex.x < point.x and intersection.x < ray_vertex.x) then
                    table.insert(filtered_intersections, intersection)
                end
                if (ray_vertex.y > point.y and intersection.y > ray_vertex.y) then -- x vertices must be the same at this point
                    table.insert(filtered_intersections, intersection)
                end
                if (ray_vertex.y < point.y and intersection.y < ray_vertex.y) then
                    table.insert(filtered_intersections, intersection)
                end -- y vertices are also the same
            end

            -- of the vertices in the correct direction, get the closest one to the ray vertex
            local min_dist = math.huge
            local intersection_to_add = nil
            for _, intersection in ipairs(filtered_intersections) do
                local cur_dist = euclidean_distance(intersection, ray_vertex)
                if cur_dist <= min_dist then
                    min_dist = cur_dist
                    intersection_to_add = intersection
                end
            end
            table.insert(V, intersection_to_add)
            table.insert(V_extended, intersection_to_add)

            rayObjs[i].boundary_point = intersection_to_add
        end
    end

    return V, rays, V_close, V_extended, rayObjs
end

local function angle_from_observer(point, vertex)
    return math.atan2(vertex.y - point.y, vertex.x - point.x)
end

local function is_between(point, corner, s1, s2)
    local angle_corner = angle_from_observer(point, corner)
    local angle_1 = angle_from_observer(point, s1)
    local angle_2 = angle_from_observer(point, s2)

    -- Ensure angles are sorted counterclockwise
    if angle_1 < angle_2 then
        angle_1, angle_2 = angle_2, angle_1
    end

    -- Check if corner angle is between the two segment angles
    return angle_1 < angle_corner and angle_corner < angle_2
end

local function create_visibility_polygon(V_close, point, bbox_verts, polygons, bbox, V_extended)
    -- Sort vertices by angle from the point
    table.sort(V_close, function(a, b)
        return angle_from_observer(point, a) < angle_from_observer(point, b)
    end)

    table.sort(V_extended, function(a, b)
        return angle_from_observer(point, a) < angle_from_observer(point, b)
    end)

    local triangles = {}
    local attributes = {
        color = "red"
    }

    -- close triangles
    for i = 1, #V_close - 1 do
        local v1 = V_close[i]
        local v2 = V_close[i + 1]

        local triangle = ipe.Path(attributes, {{
            type = "curve",
            closed = true,
            {
                type = "segment",
                point,
                v1
            },
            {
                type = "segment",
                v1,
                v2
            },
            {
                type = "segment",
                v2,
                point
            }
        }})

        table.insert(triangles, triangle)

    end
    local triangle = ipe.Path(attributes, {{
        type = "curve",
        closed = true,
        {
            type = "segment",
            point,
            V_close[#V_close]
        },
        {
            type = "segment",
            V_close[#V_close],
            V_close[1]
        },
        {
            type = "segment",
            V_close[1],
            point
        }
    }})

    table.insert(triangles, triangle)

    -- extended triangles (DOES NOT WORK PROPERLY)
    for i = 1, #V_extended - 1, 2 do
        local v1 = V_extended[i]
        local v2 = V_extended[i + 1]

        local triangle = ipe.Path(attributes, {{
            type = "curve",
            closed = true,
            {
                type = "segment",
                point,
                v1
            },
            {
                type = "segment",
                v1,
                v2
            },
            {
                type = "segment",
                v2,
                point
            }
        }})

        table.insert(triangles, triangle)

    end
    -- local triangle = ipe.Path(attributes, {{
    --     type = "curve",
    --     closed = true,
    --     {
    --         type = "segment",
    --         point,
    --         V_extended[#V_extended]
    --     },
    --     {
    --         type = "segment",
    --         V_extended[#V_extended],
    --         V_extended[1]
    --     },
    --     {
    --         type = "segment",
    --         V_extended[1],
    --         point
    --     }
    -- }})

    -- table.insert(triangles, triangle)

    return triangles
end

-- not necessary
local function draw_rays(point, V, bbox_verts, rays, model)
    local bottomLeft, topLeft, topRight, bottomRight = table.unpack(bbox_verts)
    local bbox_segments = {ipe.Segment(bottomLeft, topLeft), ipe.Segment(topLeft, topRight),
                           ipe.Segment(topRight, bottomRight), ipe.Segment(bottomLeft, bottomRight)}

    local attributes = {
        stroke = "blue",
        fill = "yellow"
    }

    for i = 1, #V do
        local v = V[i]

        local drawn_seg = ipe.Path(attributes, {{
            type = "curve",
            closed = true,
            {
                type = "segment",
                ipe.Vector(point.x, point.y),
                ipe.Vector(v.x, v.y)
            }
        }})
        model:creation("visibility segment", drawn_seg)
    end
end

function run(model)
    local point, polygons, vertices = collect_pt_polygons_vertices(model)

    if not point then
        model:warning("Please add a point for visibility polygon to work!")
    end

    if not polygons or not vertices then
        model:warning("Please add at least one polygon using the Polygons tool!")
    end

    local bbox_verts = get_bounding_box_verts(vertices, false, model) -- ipe vectors
    local bbox_corners = get_bounding_box_verts(vertices, true, model) -- min & max for x & y
    local bbox = get_bounding_box(polygons, bbox_verts, model)

    if not bbox_verts then
        model:warning("Please create a bounding box to define the boundaries of the visibility region!")
    end

    local visibility_verts, visibility_rays, V_close, V_extended, rayObjs =
        visibility_polygon(point, polygons, vertices, bbox, bbox_verts, model)
    draw_rays(point, visibility_verts, bbox_verts, visibility_rays, model)

    local reordered_rayObjs = order_rays_clockwise(rayObjs, point)
    local polygon_path_objs = create_polygons_from_rays(reordered_rayObjs, point, bbox_verts, model)
end

function order_rays_clockwise(rayObjs,observer)
    table.sort(rayObjs, function(a, b)
        return angle_from_observer(observer, a.tip_point) > angle_from_observer(observer, b.tip_point)
    end)
    return rayObjs
end

function filter_rayObjs(rayObjs)
    local filtered_rayObjs = {}
    for i = 1, #rayObjs do
        if rayObjs[i].boundary_point and not rayObjs[i].tip_point then
        
        else 
            table.insert(filtered_rayObjs, rayObjs[i])
        end
    end
    return filtered_rayObjs
end

function create_polygons_from_rays(rayObjs, observer, bbox_verts, model)
    local polygon_path_objs = {}

    rayObjs = filter_rayObjs(rayObjs)

    for i = 1, #rayObjs do
        local curr_ray = rayObjs[i]
        local next_ray = rayObjs[(i % #rayObjs) + 1]

        local vertices = {}
        table.insert(vertices, observer)
        
        if curr_ray.obstacle_id == next_ray.obstacle_id then
            if curr_ray.tip_point and next_ray.tip_point then
                table.insert(vertices, curr_ray.tip_point)
                table.insert(vertices, next_ray.tip_point)
            end
        else
            table.insert(vertices, curr_ray.boundary_point)
            if curr_ray.boundary_point and next_ray.boundary_point then
                local common = find_common_endpoint(curr_ray.boundary_point, next_ray.boundary_point, bbox_verts)
                if common then
                    table.insert(vertices, common)
                end
            end
            table.insert(vertices, next_ray.boundary_point)
        end

        local shape = create_shape_from_vertices(vertices, model)
        local path_obj = ipe.Path({stroke="blue", fill="yellow",pen=3, pathmode="strokedfilled"}, { shape })
        model:creation("visibility polygon", path_obj)
        table.insert(polygon_path_objs, path_obj)
    end

    return polygon_path_objs

end

function create_shape_from_vertices(v, model)
    local shape = {type="curve", closed=true;}
    for i=1, #v-1 do 
        table.insert(shape, {type="segment", v[i], v[i+1]})
    end
    table.insert(shape, {type="segment", v[#v], v[1]})
    return shape
end

function find_bbox_segment_index(boundary_point, bbox_verts)
    local n = #bbox_verts
    for i = 1, n do
        local next_i = (i % n) + 1
        if point_on_seg(bbox_verts[i], bbox_verts[next_i], boundary_point) then
            return i  
        end
    end
    return nil
end

function find_common_endpoint(boundary_point1, boundary_point2, bbox_verts)
    local idx1 = find_bbox_segment_index(boundary_point1, bbox_verts)
    local idx2 = find_bbox_segment_index(boundary_point2, bbox_verts)
    if not idx1 or not idx2 then return nil end
    local n = #bbox_verts
    if ((idx1 % n) + 1) == idx2 then
        return bbox_verts[idx2]
    elseif ((idx2 % n) + 1) == idx1 then
        return bbox_verts[idx1]
    end
    return nil
end