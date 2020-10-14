module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit

export viewer

function add_default_meta!(model::Model)
    for i in 1:length(model.preds)
        meta = metadict(model, i)
        haskey(meta, :__label)   ||  (meta[:__label] = "Prediction $i")
        haskey(meta, :__label_x) ||  (meta[:__label_x] = "")
        haskey(meta, :__scale_x) ||  (meta[:__scale_x] =  1)
        haskey(meta, :__unit_x ) ||  (meta[:__unit_x]  = "")
        haskey(meta, :__label_y) ||  (meta[:__label_y] = "")
        haskey(meta, :__scale_y) ||  (meta[:__scale_y] =  1)
        haskey(meta, :__unit_y ) ||  (meta[:__unit_y]  = "")

        for (cname, comp) in model.comps
            meta = metadict(model, cname)
            haskey(meta, :__label)    ||  (meta[:__label] = string(cname))
            haskey(meta, :__visible)  ||  (meta[:__visible] = false)
            haskey(meta, :__color)    ||  (meta[:__color] = "auto")
            for (pname, param) in GFit.getparams(comp)
                meta = param.meta
                haskey(meta, :__scale)   ||  (meta[:__unit] =  1)
                haskey(meta, :__unit )   ||  (meta[:__unit] = "")
                haskey(meta, :__note )   ||  (meta[:__note] = "")
            end            
        end

        for pred in model.preds
            for (rname, reval) in pred.revals
                meta = metadict(model, rname)
                haskey(meta, :__label)    ||  (meta[:__label] = string(rname))
                haskey(meta, :__visible)  ||  (meta[:__visible] = true)
                haskey(meta, :__color)    ||  (meta[:__color] = "auto")
            end
        end
    end
end

function add_default_meta!(data::GFit.Measures_1D)
    haskey(data.meta, :__label)    ||  (data.meta[:__label] = "Empirical data")
    haskey(data.meta, :__visible)  ||  (data.meta[:__visible] = true)
    haskey(data.meta, :__color)    ||  (data.meta[:__color] = "auto")
end


viewer(model::Model, data::GFit.Measures_1D) = viewer(model, [data])
viewer(model::Model, data::GFit.Measures_1D, bestfit::GFit.BestFitResult) = viewer(model, [data], bestfit)

function viewer(model::Model,
                data::Union{Nothing, Vector{GFit.Measures_1D}}=nothing,
                bestfit::Union{Nothing, GFit.BestFitResult}=nothing; path=nothing)

    add_default_meta!(model)
    if !isnothing(data)
        for d in data
            add_default_meta!(d)
        end
    end

    if isnothing(data)
        d = GFit.todict(model)
    elseif isnothing(bestfit)
        d = GFit.todict(model, data)
    else
        d = GFit.todict(model, data, bestfit)
    end

    if isnothing(path)
        path = tempdir() * "/gfitviewer.html"
    end
    io = open(path, "w")

    template = dirname(@__DIR__) * "/src/viewer.html"
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, d)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)

    # io = IOBuffer()
    # JSON.print(io, d)
    # return String(take!(io))

    DefaultApplication.open(path)
    return path
end

end
