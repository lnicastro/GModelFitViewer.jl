# GModelFitViewer

The **GModelFitViewer.jl** package provides tools to visualize 1D [**GModelFit.jl**](https://github.com/gcalderone/GModelFit.jl/blob/master/docs/src/misc.md) objects in a HTML page.  Specifically, it allows to display a plot of the best fit model (along with all its component) and of the empirical data.  Moreover, it shows all relevant model and best fit quantities.

- The `viewer()` and `serialize_html()` functions to generate an HTML files showing a plot of the model and empirical data, as well as the same text output you would see in a Julia REPL session.

## Example

Create a **GModelFit.jl** model, generate a mock dataset and fit:
```@example abc
using GModelFit, GModelFitViewer
dom = Domain(0:0.01:5)
model = Model(dom, :bkg => GModelFit.OffsetSlope(1, 1, 0.1),
                   :l1 => GModelFit.Gaussian(1, 2, 0.2),
                   :l2 => GModelFit.Gaussian(1, 3, 0.4),
                   :main => SumReducer(:bkg, :l1, :l2))
data = GModelFit.mock(Measures, model)
best, res = fit(model, data)
```



Also, you can generate an HTML file (which will be automatically opened using your default browser) with:

```@example abc
using GModelFitViewer
viewer(best, fitstats, data);
```

To save the HTML page in `myfile.html` (without opening it in the web browser):
```@example abc
GModelFitViewer.serialize_html("myfile.html", best, fitstats, data)
println(); #hide
```

Note that the argument sequence for `viewer()` and `GModelFitViewer.serialize_html` is similar to [`GModelFit.serialize`](https://gcalderone.github.io/GModelFit.jl/api.html#GModelFit.serialize).


## API

