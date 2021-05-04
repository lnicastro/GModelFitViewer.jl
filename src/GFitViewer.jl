module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit, Statistics
using Pkg, Pkg.Artifacts

export ViewerData, viewer


include("todict.jl")

struct ViewerData
    params::OrderedDict
    gfit::OrderedDict
    extra::Vector{OrderedDict}

    function ViewerData(args...; kw...)
        params = OrderedDict()
        gfit = todict(args...; kw...)

        extra = Vector{MDict}()
        for id in 1:length(gfit[:predictions])
            push!(extra, MDict())
        end
        return new(params, gfit, extra)
    end
end

#=
function tostring(dict::OrderedDict)
    io = IOBuffer()
    JSON.print(io, dict)
    return String(take!(io))
end
=#

function save_html(vd::ViewerData, filename::AbstractString; offline=false)
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
    end
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, vd.gfit)
    write(io, readuntil(input, "JSON_CUSTOM_PARAMS"))
    JSON.print(io, vd.params)    
    write(io, readuntil(input, "JSON_TAB_EXTRA"))
    JSON.print(io, vd.extra)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end

function save_json(vd::ViewerData, filename::AbstractString)
    io = open(filename, "w")
    JSON.print(io, vd.gfit)
    close(io)
    return filename
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

end
