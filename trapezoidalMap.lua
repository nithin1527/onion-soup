-- Define the Ipelet
label = "Trapezoidal Map"
about = "Given a set of Line Segments, returns a Trapezoidal Map"

function incorrect(title, model) model:warning(title) end

function get_polygon_segments(obj, model)

	local shape = obj:shape()

	local segment_matrix = shape[1]

	local segments = {}
	for _, segment in ipairs(segment_matrix) do
		table.insert(segments, ipe.Segment(segment[1], segment[2]))
	end
	 
	table.insert(
		segments,
		ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
	)

	return segments
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

	local segment_matrix = shape[1]

	local segments = {}
	for _, segment in ipairs(segment_matrix) do
		table.insert(segments, ipe.Segment(segment[1], segment[2]))
	end
	 
	table.insert(
		segments,
		ipe.Segment(segment_matrix[#segment_matrix][2], segment_matrix[1][1])
	)

	return segments
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

    for i = 1, #path_objects do
        local segments = get_polygon_segments(path_objects[i], model)
        table.insert(segments_table, segments)
    end

    -- Store the points of selected Line Segments and Calculate
    -- the max and min (extremities) of all coordinates

    output_table = {}

    x_min = math.huge
    y_min = math.huge
    x_max = -1 * math.huge
    y_max = -1 * math.huge


    for i = 1, #segments_table do
        startPoint, endPoint = segments_table[i][1]:endpoints()

        x_min = math.min(endPoint.x, startPoint.x, x_min)
        y_min = math.min(endPoint.y, startPoint.y, y_min)
        x_max = math.max(endPoint.x, startPoint.x, x_max)
        y_max = math.max(endPoint.y, startPoint.y, y_max)

        table.insert(output_table, {{startPoint.x, endPoint.x}, {startPoint.y, endPoint.y}})
    end

    table.insert(output_table, {{x_min, x_max}, {y_min, y_max}})
    
    
	return output_table
end

function create_boundary(x_min, x_max, y_min, y_max, scale, model)

    -- Draws a Boundary around the highlighted line sections

    local start = ipe.Vector(x_min - scale, y_min - scale)
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


function run(model)
    segments_table = get_pt_and_polygon_selection(model)

    inpt = get_pt_and_polygon_selection(model) 


    x_min = math.max(0, inpt[#inpt][1][1])
    x_max = inpt[#inpt][1][2]
    y_min = math.max(0, inpt[#inpt][2][1])
    y_max = inpt[#inpt][2][2]

    local scale = 20

    create_boundary(x_min, x_max, y_min, y_max, scale, model)

    local outp = {}
    for i = 1, #inpt - 1 do
         

        local a1, a2 = inpt[i][1][1], inpt[i][1][2]
        local b1, b2 = inpt[i][2][1], inpt[i][2][2]

        local arr_outp = {{a1, b1}, {a2, b2}}

        table.insert(arr_outp, {a1, y_min - scale})
        table.insert(arr_outp, {a1, y_max + scale})
        table.insert(arr_outp, {a2, y_min - scale})
        table.insert(arr_outp, {a2, y_max + scale})

        table.insert(outp, arr_outp)
    end

    
    for segment_index = 1, #outp do
        local segments = outp[segment_index]
        local left, right = segments[1], segments[2]
        for i = 3, #segments do
            for j = 1, #inpt - 1 do

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

    local s = "Array of Segments in the form [Left Endpoint, Right Endpoint, Lower Left Point, Upper Left Point, Lower Right Point, Upper Right Point]"
    local d = ipeui.Dialog(model.ui:win(), "Output")
    d:add("label1", "label", {label=s}, 1, 1, 1, 2)
    d:add("input", "input", {}, 2, 1, 1, 2)
    d:addButton("ok", "&Ok", "accept")
    d:setStretch("column", 2, 1)
    d:setStretch("column", 1, 1)
    d:set("input", tableToString(outp, ""))
    d:execute()

end