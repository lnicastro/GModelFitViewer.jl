module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit, Statistics
using Pkg, Pkg.Artifacts

export ViewerData, viewer

include("todict.jl")

struct ViewerData
    dict::OrderedDict

    function ViewerData(model::Model,
                        data::Union{Nothing, T}=nothing,
                        fitres::Union{Nothing, GFit.FitResult}=nothing;
                        kw...) where T <: GFit.AbstractData
        multi = MultiModel(model)
        isnothing(data)  ||  (data = [data])
        return ViewerData(multi, data, fitres; kw...)
    end

    function ViewerData(multi::MultiModel,
                        data::Union{Nothing, Vector{T}}=nothing,
                        fitres::Union{Nothing, GFit.FitResult}=nothing;
                        rebin::Int=1,
                        showcomps::Union{Bool, Vector{Symbol}}=false) where T <: GFit.AbstractData

        todict_opt[:rebin] = rebin
        todict_opt[:keepallcevals] = (isa(showcomps, Bool)  &&  showcomps)
        todict_opt[:keepcevals] = Vector{Symbol}()
        if !isa(showcomps, Bool)
            todict_opt[:keepcevals] = showcomps
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
                # Avoid displaying selected reducer (it will be shown
                # as model in the corresponding dataset)
                out[:models][id][:reducers][multi.models[id].rsel][:meta][:use_in_plot] = false
                push!(out[:data], todict(multi.models[id], data[id]))
            end
        end

        if !isnothing(fitres)
            out[:bestfit] = todict(fitres)

            # TODO: remove these
            function tbr_todict(param::GFit.Parameter)
                aa = MDict()
                aa[:val] = param.val
                aa[:unc] = param.unc
                aa[:fixed] = param.fixed
                aa[:patched] = param.patched
                return aa
            end

            function tbr_todict(comp::GFit.AbstractComponent)
                bb = MDict()
                for (pid, param) in GFit.getparams(comp)
                    bb[pid.name] = tbr_todict(param)
                end
                return bb
            end

            function tbr_todict(res)
                cc = [MDict(:components => MDict()) for id in 1:length(res.models)]
                for id in 1:length(res.models)
                    for cname in keys(res.models[id])
                        comp = res.models[id][cname]
                        cc[id][:components][cname] = tbr_todict(comp)
                    end
                end
                return cc
            end
            out[:bestfit][:models] = tbr_todict(multi)
        end

        out[:meta] = MDict()
        out[:extra] = Vector{MDict}()
        for id in 1:length(multi.models)
            push!(out[:extra], MDict())
        end
        return new(out)
    end
end


save_json(args...; filename=nothing, kw...) = save_json(ViewerData(args...; kw...), filename)
function save_json(vd::ViewerData, filename::Union{Nothing, AbstractString}=nothing)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.json"))
    io = open(filename, "w")
    JSON.print(io, vd.dict)
    close(io)
    return filename
end

#=
function tostring(vd::ViewerData)
    io = IOBuffer()
    JSON.print(io, vd.dict)
    return String(take!(io))
end
=#

save_html(args...; filename=nothing, offline=false, kw...) = save_html(ViewerData(args...; kw...), filename; offline=offline)
function save_html(vd::ViewerData, filename::Union{Nothing, AbstractString}=nothing; offline=false)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.html"))
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

viewer(args...; filename=nothing, offline=false, kw...) = viewer(ViewerData(args...; kw...), filename; offline=offline)
function viewer(vd::ViewerData; filename=nothing, offline=false)
    filename = save_html(vd, filename; offline=offline)
    DefaultApplication.open(filename)
end

include("gnuplot.jl")

end
