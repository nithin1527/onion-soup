label = "Triangulate"
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

function run(model)
  math.randomseed()
  local vertices = get_pt_and_polygon_selection(model)
  
  if vertices then
    triangulate(reorient_ccw(vertices), model)
  end
end