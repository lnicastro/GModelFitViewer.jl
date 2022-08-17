module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit, Statistics
using Pkg, Pkg.Artifacts

export ViewerData, viewer

include("todict.jl")

struct ViewerData
    dict::OrderedDict
end

function ViewerData(model::Model,
                    data::Union{Nothing, T}=nothing,
                    fitres::Union{Nothing, GFit.FitResult}=nothing;
                    kw...) where T <: GFit.AbstractMeasures
    multi = MultiModel(model)
    isnothing(data)  ||  (data = [data])
    return ViewerData(multi, data, fitres; kw...)
end

function ViewerData(multi::MultiModel,
                    data::Union{Nothing, Vector{T}}=nothing,
                    fitres::Union{Nothing, GFit.FitResult}=nothing;
                    rebin::Int=1,
                    comps::Union{Bool, Vector{Symbol}, Function}=true) where T <: GFit.AbstractMeasures

    todict_opt[:rebin] = rebin
    todict_opt[:include] = comps
    out = MDict()

    out[:models] = Vector{MDict}()
    for id in 1:length(multi.models)
        push!(out[:models], todict(id, multi.models[id]))
    end

    if !isnothing(data)
        out[:data] = Vector{MDict}()
        @assert length(multi.models) == length(data)
        for id in 1:length(data)
            push!(out[:data], todict(multi.models[id], data[id]))
        end
    end

    if !isnothing(fitres)
        out[:fitresult] = todict(fitres)
    end

    out[:meta] = MDict()
    out[:extra] = Vector{MDict}()
    for id in 1:length(multi.models)
        push!(out[:extra], MDict())
    end
    return ViewerData(out)
end


save_json(args...; filename=nothing, kw...) = save_json(ViewerData(args...; kw...), filename=filename)
function save_json(vd::ViewerData; filename::Union{Nothing, AbstractString}=nothing)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.json"))
    io = open(filename, "w")  # io = IOBuffer()
    JSON.print(io, vd.dict)
    close(io)                 # String(take!(io))
    return filename
end


save_html(args...; filename=nothing, offline=false, kw...) = save_html(ViewerData(args...; kw...), filename=filename, offline=offline)
function save_html(vd::ViewerData; filename::Union{Nothing, AbstractString}=nothing, offline=false)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.html"))
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
    end
    # template = joinpath(dirname(pathof(GFitViewer)), "vieweronline.html")
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, vd.dict)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end

viewer(args...; filename=nothing, offline=false, kw...) = viewer(ViewerData(args...; kw...), filename=filename, offline=offline)
function viewer(vd::ViewerData; filename=nothing, offline=false)
    filename = save_html(vd, filename=filename, offline=offline)
    DefaultApplication.open(filename)
end

include("gnuplot.jl")

end
