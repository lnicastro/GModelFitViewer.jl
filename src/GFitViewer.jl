module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit

export viewer

function add_default_meta!(model::Model)
    for id in 1:length(model.preds)
        meta = model.meta[id]
        haskey(meta, :rebin)   ||  (meta[:rebin] = GFit.todict_opt[:rebin])
        haskey(meta, :label)   ||  (meta[:label] = "Prediction $id")
        haskey(meta, :label_x) ||  (meta[:label_x] = "")
        haskey(meta, :scale_x) ||  (meta[:scale_x] =  1)
        haskey(meta, :unit_x ) ||  (meta[:unit_x]  = "")
        haskey(meta, :label_y) ||  (meta[:label_y] = "")
        haskey(meta, :scale_y) ||  (meta[:scale_y] =  1)
        haskey(meta, :unit_y ) ||  (meta[:unit_y]  = "")

        for (cname, cmeta) in model.meta[id][:components]
            haskey(cmeta, :label)            ||  (cmeta[:label] = string(cname))
            haskey(cmeta, :color)            ||  (cmeta[:color] = "auto")
            haskey(cmeta, :default_visible)  ||  (cmeta[:default_visible] = false)
            cmeta[:use_in_plot] = (GFit.todict_opt[:addcomps]  ||  (cname in GFit.todict_opt[:selcomps]))
            for (pname, pmeta) in model.meta[id][:components][cname][:params]
                haskey(pmeta, :scale)   ||  (pmeta[:unit] =  1)
                haskey(pmeta, :unit )   ||  (pmeta[:unit] = "")
                haskey(pmeta, :note )   ||  (pmeta[:note] = "")
            end
        end

        for (rname, rmeta) in model.meta[id][:reducers]
            haskey(rmeta, :label)            ||  (rmeta[:label] = string(rname))
            haskey(rmeta, :color)            ||  (rmeta[:color] = "auto")
            haskey(rmeta, :default_visible)  ||  (rmeta[:default_visible] = true)
            rmeta[:use_in_plot] = true
        end
    end
end

function add_default_meta!(data::GFit.Measures_1D)
    haskey(data.meta, :label)            ||  (data.meta[:label] = "Empirical data")
    haskey(data.meta, :use_in_plot)      ||  (data.meta[:use_in_plot] = true)
    haskey(data.meta, :default_visible)  ||  (data.meta[:default_visible] = true)
    haskey(data.meta, :color)            ||  (data.meta[:color] = "auto")
end


function todict(model::Model,
                data::Union{Nothing, Vector{GFit.Measures_1D}}=nothing,
                bestfit::Union{Nothing, GFit.BestFitResult}=nothing;
                rebin::Int=1, addcomps::Bool=false, selcomps=Vector{Symbol}())

    GFit.todict_opt[:rebin] = rebin
    GFit.todict_opt[:addcomps] = addcomps
    GFit.todict_opt[:selcomps] = selcomps

    add_default_meta!(model)
    if !isnothing(data)
        for d in data
            add_default_meta!(d)
        end
    end

    if isnothing(data)
        dict = GFit.todict(model)
    elseif isnothing(bestfit)
        dict = GFit.todict(model, data)
    else
        dict = GFit.todict(model, data, bestfit)
    end
    return dict
end


function tostring(dict::OrderedDict)
    io = IOBuffer()
    JSON.print(io, dict)
    return String(take!(io))
end

function save_html(dict::OrderedDict, filename::AbstractString)
    io = open(filename, "w")
    template = dirname(@__DIR__) * "/src/viewer.html"
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, dict)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end

function save_json(dict::OrderedDict, filename::AbstractString)
    io = open(filename, "w")
    JSON.print(io, dict)
    close(io)
    return filename
end

viewer(model::Model, data::GFit.Measures_1D) = viewer(model, [data])
viewer(model::Model, data::GFit.Measures_1D, bestfit::GFit.BestFitResult) = viewer(model, [data], bestfit)
function viewer(args...; kw...)
    dict = todict(args...; kw...)
    path = tempdir()
    fname = save_json(dict, "$(path)/gfitviewer.json")
    fname = save_html(dict, "$(path)/gfitviewer.html")
    DefaultApplication.open(fname)
end


end
