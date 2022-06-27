import Gnuplot
import Gnuplot.recipe

Gnuplot.recipe(data::Measures{1}) =
    Gnuplot.PlotElement(cmds=["set bars 0"],
                        data=Gnuplot.DatasetBin(data.domain[:], data.val, data.unc),
                        plot="with yerr t 'Data' lc rgb 'gray'")

function Gnuplot.recipe(model::Model)
    @assert ndims(domain(model)) == 1
    out = Vector{Gnuplot.PlotElement}()
    for (k,v) in model.cevals
        (k == model.maincomp)  &&  continue
        isa(v.comp, GFit.λComp)  ||  isa(v.comp, GFit.SumReducer)  ||  continue
        push!(out, Gnuplot.PlotElement(
            data=Gnuplot.DatasetBin(domain(model)[:], model(k)),
            plot="with lines t '$(k)'"))
    end
    push!(out, Gnuplot.PlotElement(
        data=Gnuplot.DatasetBin(domain(model)[:], model()),
        plot="with lines t 'Model' lc rgb 'black' lw 2"))
    return out
end


Gnuplot.recipe(dd::Tuple{Measures{1}, Model}) =
    out = [Gnuplot.recipe((domain(dd[2]), dd[1])),
           Gnuplot.recipe(dd[2])...]
