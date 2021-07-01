module GFitViewer

using DataStructures, JLD2, JSON, DefaultApplication, GFit, Statistics
using Pkg, Pkg.Artifacts

export ViewerData, viewer

include("todict.jl")

struct ViewerData
    dict::OrderedDict

    function ViewerData(model::Model,
                        data::Union{Nothing, T}=nothing,
                        bestfit::Union{Nothing, GFit.BestFitResult}=nothing;
                        kw...) where T <: GFit.AbstractData
        multi = MultiModel(model)
        isnothing(data)  ||  (data = [data])
        if !isnothing(bestfit)
            bestfit = GFit.BestFitMultiResult(bestfit.timestamp, bestfit.elapsed, bestfit.mzer,
                                              [bestfit.comps],
                                              GFit.MDMultiComparison(multi, data))
        end
        return ViewerData(multi, data, bestfit; kw...)
    end

    function ViewerData(multi::MultiModel,
                        data::Union{Nothing, Vector{T}}=nothing,
                        bestfit::Union{Nothing, GFit.BestFitMultiResult}=nothing;
                        rebin::Int=1,
                        showcomps::Union{Bool, Vector{Symbol}}=false) where T <: GFit.AbstractData

        todict_opt[:rebin] = rebin
        todict_opt[:showallcomps] = (isa(showcomps, Bool)  &&  showcomps)
        todict_opt[:showcomps] = Vector{Symbol}()
        if !isa(showcomps, Bool)
            todict_opt[:showcomps] = showcomps
        end

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

        if !isnothing(bestfit)
            out[:bestfit] = todict(bestfit)
        end

        out[:meta] = MDict()
        out[:extra] = Vector{MDict}()
        for id in 1:length(multi.models)
            push!(out[:extra], MDict())
        end
        return new(out)
    end
end


function save_html(vd::ViewerData, filename::AbstractString; offline=false)
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
    end
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, vd.dict)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end


function save_json(vd::ViewerData, filename::AbstractString)
    io = open(filename, "w")
    JSON.print(io, vd.dict)
    close(io)
    return filename
end


function save_binary(vd::ViewerData, filename::AbstractString)
    JLD2.save_object(filename, vd)
    return filename
end


function tostring(vd::ViewerData)
    io = IOBuffer()
    JSON.print(io, vd.dict)
    return String(take!(io))
end


function viewer(vd::ViewerData; filename=nothing, offline=false)
    path = tempdir()
    if filename == nothing
        fname = "$(path)/gfitviewer.html"
    else
        fname = filename
    end
    if splitext(fname)[2] == ".html"
        json_fname = splitext(fname)[1] * ".json"
    else
        json_fname = fname * ".json"
    end
    save_json(vd, json_fname)
    if splitext(fname)[2] == ".html"
        binary_fname = splitext(fname)[1] * ".jld2"
    else
        binary_fname = fname * ".jld2"
    end
    save_binary(vd, binary_fname)
    save_html(vd, fname; offline=offline)
    DefaultApplication.open(fname)
end

function viewer(args...; filename=nothing, offline=false, kw...)
    vd = ViewerData(args...; kw...)
    viewer(vd, filename=filename, offline=offline)
end


function viewer(json::String; filename=nothing, offline=false)
    @assert isfile(json)
    path = tempdir()
    if filename == nothing
        fname = "$(path)/gfitviewer.html"
    else
        fname = filename
    end

    io = open(fname, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
    end
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    write(io, read(json))
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    DefaultApplication.open(fname)
end


include("gnuplot.jl")

end
