module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit, Statistics
using Pkg, Pkg.Artifacts

export ViewerData, viewer

include("todict.jl")

struct ViewerData
    dict::OrderedDict

    function ViewerData(model::Model,
                        data::Union{Nothing, T, Vector{T}}=nothing,
                        bestfit::Union{Nothing, GFit.BestFitResult}=nothing;
                        rebin::Int=1,
                        showcomps::Union{Bool, Vector{Symbol}}=false) where T <: GFit.AbstractData

        todict_opt[:rebin] = rebin
        todict_opt[:showallcomps] = (isa(showcomps, Bool)  &&  showcomps)
        todict_opt[:showcomps] = Vector{Symbol}()
        if !isa(showcomps, Bool)
            todict_opt[:showcomps] = showcomps
        end

        out = MDict()

        out[:predictions] = Vector{MDict}()
        for id in 1:length(model.preds)
            push!(out[:predictions], todict(id, model.preds[id]))
        end

        if !isnothing(data)
            out[:data] = Vector{MDict}()
            if isa(data, Vector)
                @assert length(model.preds) == length(data)
                for id in 1:length(data)
                    push!(out[:data], todict(model.preds[id], data[id]))
                end
            else
                @assert length(model.preds) == 1
                push!(out[:data], todict(model.preds[1], data))
            end
        end

        if !isnothing(bestfit)
            out[:bestfit] = todict(bestfit)
        end

        out[:meta] = MDict()
        out[:extra] = Vector{MDict}()
        for id in 1:length(model.preds)
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
    save_json(vd, fname * ".json")
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

end
