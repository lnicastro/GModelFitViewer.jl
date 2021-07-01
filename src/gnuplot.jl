import Gnuplot
import Gnuplot.recipe

Gnuplot.recipe(data::Measures{1}) =
    Gnuplot.PlotElement(cmds=["set bars 0"],
                        data=Gnuplot.DatasetBin(collect(1:length(data)), data.val, data.unc),
                        plot="with yerr t 'Data' lc rgb 'gray'")


Gnuplot.recipe(data::Tuple{Domain{1}, Measures{1}}) =
    Gnuplot.PlotElement(cmds=["set grid", "set bars 0"],
                        data=Gnuplot.DatasetBin(data[1][:], data[2].val, data[2].unc),
                        plot="with yerr t 'Data' lc rgb 'gray'")


function Gnuplot.recipe(model::Model)
    @assert ndims(domain(model)) == 1
    out = Vector{Gnuplot.PlotElement}()
    for (k,v) in model.revals
        (k == model.rsel)  &&  continue
        push!(out, Gnuplot.PlotElement(
            data=Gnuplot.DatasetBin(domain(model)[:], model(k)),
            plot="with lines t '$(k)'"))
    end
    push!(out, Gnuplot.PlotElement(
        data=Gnuplot.DatasetBin(domain(model)[:], model()),
        plot="with lines t 'Model' lc rgb 'black' lw 2"))
    return reverse(out)
end


Gnuplot.recipe(dd::Tuple{Measures{1}, Model}) =
    out = [Gnuplot.recipe(dd[2])...,
           Gnuplot.recipe((domain(dd[2]), dd[1]))]
