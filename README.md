# GModelFitViewer

The **GModelFitViewer.jl** package allows to visualize 1D [**GModelFit**](https://gcalderone.github.io/GModelFit.jl) objects in a HTML page.  Specifically, it allows to display a plot of the best fit model (along with all its component) and of the empirical data, as well as the logs reported in the Julia REPL when `show`ing the objects.

The most relevant functions are:
- `GModelFitViewer.serialize_html()`: writes an HTML page containing the above mentioned contents;
- `viewer()`: writes an HTML page and displays it using the default browser;

Both functions accepts the same arguments:
- a `ModelSnapshot` or a `Vector{ModelSnapshot}` object;
- a `FitSummary` object;
- a `Measures` or a `Vector{Measures}` object;

The file name for the output file can be provided as first argument to `GModelFitViewer.serialize_html()` or via the `filename=` keyword to the `viewer()` function.  If the latter keyword is not used the file will stored in the `tempdir()` directory.

Besides the above arguments, a number of optional keywords may be provided to customize the plot:
- `title`: plot title;
- `xlabel`: label for X axis;
- `ylabel`: label for Y axis;
- `xrange`: 2-element vector specifying the range for the X axis;
- `yrange`: 2-element vector specifying the range for the Y axis;
- `xscale`: numerical global scale factor for the X axis;
- `yscale`: numerical global scale factor for the Y axis;
- `xunit`: units for the X axis (as a string);
- `yunit`: units for the Y axis (as a string);

**IMPORTANT NOTE**: the keywords name may be abbreviated as long as the name in unambiguous. E.g., you may use `xr` in place of `xrange`.



## Example

Create a **GModelFit.jl** model, generate a mock dataset and fit:
```julia
using GModelFit, GModelFitViewer
model = Model(:bkg => GModelFit.OffsetSlope(1, 1, 0.1),
              :l1 => GModelFit.Gaussian(1, 2, 0.2),
              :l2 => GModelFit.Gaussian(1, 3, 0.4),
              :main => SumReducer(:bkg, :l1, :l2))
dom = Domain(0:0.01:5)
data = GModelFit.mock(Measures, model, dom)
bestfit, fsumm = fit(model, data)
```

Generate and display an HTML page vith:
```julia
viewer(bestfit, fsumm, data);
```

You may customize the plot using the above mentioned keywords, e.g.
```julia
viewer(bestfit, fsumm, data,
       title="My title", xr=[0.5, 4.5])
```

To save the HTML page in `myfile.html` (without opening it in the web browser):
```julia
GModelFitViewer.serialize_html("myfile.html", bestfit, fsumm, data)
```
