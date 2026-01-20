using Test, GModelFit, GModelFitViewer, Dates

#
using Interpolations
import GModelFit: unfolded_domain, apply_ir!

struct MyInstrument <: GModelFit.AbstractInstrumentResponse
end

# Return the evenly-spaced domain to be used for evalation of the unfolded model
unfolded_domain(IR::MyInstrument, folded_domain::GModelFit.AbstractDomain) =
    Domain(logrange(minimum(coords(folded_domain)),
                    maximum(coords(folded_domain)),
                    length(folded_domain)))

# Apply instrument response
function apply_ir!(IR::MyInstrument,
                   folded_domain::GModelFit.AbstractDomain, folded::Vector,
                   unfolded_domain::GModelFit.AbstractDomain, unfolded::Vector)
    folded .= linear_interpolation(coords(unfolded_domain), unfolded)(coords(folded_domain))
end




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
set_IR!(model, MyInstrument())

x = collect(logrange(0.1, 5, 100))
deleteat!(x, 5:20)
dom = Domain(x) # Domain(0.1:0.1:5)

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


# Compare a generated HTML with a reference one
x    = 1.:5
meas = 1.:5
unc  = meas .* 0.
dom  = Domain(x)
data = Measures(dom, meas, unc)
model = Model(@fd (x, a2=3, a1=2, a0=1) -> (a2 .* x.^2  .+  a1 .* x  .+  a0))
bestfit, fsumm = fit(model, data, GModelFit.Solvers.dry())
# Drop values which depends on the execution timestamp
fsumm = GModelFit.Solvers.FitSummary(DateTime("0000-01-01T00:00:00"), 0., fsumm.ndata, fsumm.nfree, fsumm.fitstat, fsumm.status, fsumm.solver_retval)
export_html("test05.html", bestfit, fsumm, data)
@test read("test05.html", String) == read("ref05.html", String)
