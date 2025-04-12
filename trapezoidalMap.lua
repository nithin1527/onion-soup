label = "Points and Polygons"
methods = {{ label = "Trapezoidal Map", run = runTrapezoidalMap }}
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
