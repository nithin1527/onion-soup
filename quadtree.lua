-- ipelet information
label = "Points and Polygons"
methods = {
    { label = "Point-region Quadtree", run = create_point_region_quadtree },
    { label = "Point Quadtree", run = create_point_quadtree }
}

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