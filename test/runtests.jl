using GModelFit, GModelFitViewer
model = Model(:bkg => GModelFit.OffsetSlope(1, 1, 0.1),
              :l1 => GModelFit.Gaussian(1, 2, 0.2),
              :l2 => GModelFit.Gaussian(1, 3, 0.4),
              :main => SumReducer(:bkg, :l1, :l2))
model[:bkg].offset.val = 1
model[:bkg].offset.fixed = true

model[:bkg].slope.low  = 0
model[:bkg].slope.high = 0.2
model[:l2].norm.patch = :l1
model[:l2].sigma.patch = @fd m -> 2 * m[:l1].sigma
model[:l2].center.patch = @fd (m, v) -> v + m[:l1].center
model[:l2].center.val = 1   # guess value for the distance between the centers
model[:l2].center.low = 0   # ensure [l2].center > [l1].center
dom = Domain(0:0.1:5)
data = GModelFit.mock(Measures, model, dom)
bestfit, fsumm = fit(model, data)


export_html("test01.html", bestfit, fsumm, data,
            title="Test", xlab="Abscissa", ylab="Ordinate", xr=[0.5, 4.5], yr=[0, 3],
            xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1")

tab1 = AuxTable("Tab1")
add_col!(tab1, "Field1", ["a", "b"])
add_col!(tab1, "Field2", ["1", "2"])
tab2 = AuxTable("Tab2")
add_col!(tab2, "FieldA", ["A", "B"])
add_col!(tab2, "FieldB", ["3", "4"])
export_html("test02.html", bestfit, fsumm, data,
            title="Test", xlab="Abscissa", ylab="Ordinate", xr=[0.5, 4.5], yr=[0, 3],
            xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1",
            [tab1, tab2])


model1 = Model(GModelFit.Gaussian(1, 0., 1.))
model2 = Model(GModelFit.Gaussian(1, 0., 1.))
multi = [model1, model2]

# Patch parameters
multi[2][:main].norm.mpatch   = @fd m -> m[1][:main].norm
multi[2][:main].center.mpatch = @fd m -> m[1][:main].center

# Create datasets and fit
dom = Domain(-5.:0.1:5)
data = GModelFit.mock(Measures, multi, [dom, dom])
bestfit, fsumm = fit(multi, data)

meta = [ViewerOpts(title="First" , xlab="Abscissa", ylab="Ordinate", xr=[-4, 4], xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1"),
        ViewerOpts(title="Second", xlab="Abscissa", ylab="Ordinate", xr=[-4, 4], xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1")]
export_html("test03.html", bestfit, fsumm, data, meta)
export_html("test04.html", bestfit, fsumm, data, meta, [[tab1], [tab2]])
