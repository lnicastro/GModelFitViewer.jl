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
bestfit, stats = fit(model, data)


GModelFitViewer.serialize_html(filename="gmodelfitviewer_test04.html", bestfit, stats, data,
                               title="Test", xlab="Abscissa", ylab="Ordinate", xr=[0.5, 4.5], yr=[0, 3],
                               xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1")


model1 = Model(GModelFit.Gaussian(1, 0., 1.))
model2 = Model(GModelFit.Gaussian(1, 0., 1.))
multi = [model1, model2]

# Patch parameters
multi[2][:main].norm.mpatch   = @fd m -> m[1][:main].norm
multi[2][:main].center.mpatch = @fd m -> m[1][:main].center

# Create datasets and fit
dom = Domain(-5.:0.1:5)
data = GModelFit.mock(Measures, multi, [dom, dom])
bestfit, stats = fit(multi, data)


meta1 = GModelFitViewer.Meta(title="First" , xlab="Abscissa", ylab="Ordinate", xr=[-4, 4], xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1")
meta2 = GModelFitViewer.Meta(title="Second", xlab="Abscissa", ylab="Ordinate", xr=[-4, 4], xscale=1000, yscale=1e-17, xunit="Angstrom", yunit="erg s^-1 cm^-2 A^-1")
GModelFitViewer.serialize_html(filename="gmodelfitviewer_test05.html", bestfit, xlab="Abscissa", ylab="Ordinate", xr=[-4, 4])
GModelFitViewer.serialize_html(filename="gmodelfitviewer_test06.html", bestfit, stats, meta=[meta1, meta2])
GModelFitViewer.serialize_html(filename="gmodelfitviewer_test07.html", bestfit, stats, data, meta=[meta1, meta2])
