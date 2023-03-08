# GModelFitViewer

The **GModelFitViewer.jl** package allows to visualize 1D [**GModelFit.jl**](https://github.com/gcalderone/GModelFit.jl/blob/master/docs/src/misc.md) objects in a HTML page.  Specifically, it allows to display a plot of the best fit model (along with all its component) and of the empirical data, as well as the logs reported in the Julia REPL when `show`ing the objects.

The most relevant functions are:
- `GModelFitViewer.serialize_html()`: writes an HTML page containing the above mentioned contents;
- `viewer()`: writes an HTML page and displays it using the default browser;

Both functions share a syntax which is similar to the [`GModelFit.serialize()`](https://gcalderone.github.io/GModelFit.jl/api.html#GModelFit.serialize) function.  The accepted arguments are:
- a path and name for the HTML file (as a `String`);
- a `ModelSnapshot` or a `Vector{ModelSnapshot}` object;
- a `FitStats` object;
- a `Measures` or a `Vector{Measures}` object;

If the filename is not provided a standard one will be used and stored in the `tempdir()` directory.

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
- `rebin`: an integer specifying the rebin factor along the X axis (X values are averaged, Y values are averaged using uncertainties as weights);
- `keep`: a `String`, a `Regex`, or a `Vector{String}`, indicating which components should be kept in the final file;
- `skip`: a `String`, a `Regex`, or a `Vector{String}`, indicating which components should be ignored when writing the final file;

The usage of `rebin`, `keep` and `skip` allows to produce files which are significantly smaller in size.

**IMPORTANT NOTE**: the keywords name may be abbreviated as long as the name in unambiguous. E.g., you may use `xr` in place of `xrange`, `re` in place of `rebin`, etc.



## Example

Create a **GModelFit.jl** model, generate a mock dataset and fit:
```julia
using GModelFit, GModelFitViewer
dom = Domain(0:0.01:5)
model = Model(dom, :bkg => GModelFit.OffsetSlope(1, 1, 0.1),
                   :l1 => GModelFit.Gaussian(1, 2, 0.2),
                   :l2 => GModelFit.Gaussian(1, 3, 0.4),
                   :main => SumReducer(:bkg, :l1, :l2))
data = GModelFit.mock(Measures, model)
best, fitstats = fit(model, data)
```

Generate and display an HTML page vith:
```julia
viewer(best, fitstats, data);
```

You may customize the plot using the above mentioned keywords, e.g.
```julia
viewer(best, fitstats, data, 
       title="My title", xr=[0.5, 4.5], rebin=2, keep=r"l.")
```

To save the HTML page in `myfile.html` (without opening it in the web browser):
```julia
GModelFitViewer.serialize_html("myfile.html", best, fitstats, data)
```
