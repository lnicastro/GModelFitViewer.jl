var _version = '0.4.5';
var _date = '2026-01-21';
document.querySelector('meta[name="version"]').setAttribute("content", _version);
document.querySelector('meta[name="date"]').setAttribute("content", _date);
document.getElementById('version-div').innerHTML = 'v'+ _version;

// Initialize metadata and local variables
var   n_sigma = 3,		// Highlight residuals region within this +/- sigma
	y_errplot = false,	// Y errors plot
	y_err_shade = false,	// Y errors shaded area
	cur_track = true,	// Track cursor and display X, Y values. Always true.
	resid_plot = false,	// True if plotting residuals
	am_anim = false,	// Animation theme ?
	x_range = {min: null, max: null, logscale: false},  // X axis range
	y_range = {min: null, max: null, logscale: false},  // Y axis range
	my_chartdata,	// JSON reformatted data for amchart
	root,		// The amchart drawing root
	chart,		// The amchart object
	sdata,		// The data series to plot (with errors)
	resid,		// The residuals chart series
	csr2,		// The sum of squared residuals chart series
	aux = {},	// The metadata information read from the JSON file and more
	i_chmodel = -1, // Index of the Model data in the chart.series
	vxAxis,		// The X axis object
	valueAxis,	// The Y axis object
	resyAxis,	// The residuals right axis object
	csr2yAxis,	// The cumulative sum of squared residuals axis object
	sbseries,	// The X axis scrollbar series
	legend,		// The main legend
	range0,		// Used to draw the residuals 0 level
	resrange,	// Used to highlight +/- N sigma residuals
	range0DataItem,
	resrangeDataItem,

	p_title = document.getElementById('p_title'),
	inxy_ranges = document.getElementById('range-selector-div').getElementsByTagName('input');


// A set of 19 colors + white + black
// grey, blue and darkblue removed and used by def. for the data, main reducer and residuals array
var mycolors = [
    {'name':'Red', 'hex':'#e6194b', 'rgb':'(230, 25, 75)', 'rgba':'(230, 25, 75, 0.5)'},
    {'name':'Green', 'hex':'#3cb44b', 'rgb':'(60, 180, 75)', 'rgba':'(60, 180, 75, 0.5)'},
    {'name':'Purple', 'hex':'#911eb4', 'rgb':'(145, 30, 180)', 'rgba':'(145, 30, 180, 0.5)'},
    {'name':'Orange', 'hex':'#f0ad4e', 'rgb':'(240, 173, 78)', 'rgba':'(240, 143, 78, 0.5)'},
    {'name':'Magenta', 'hex':'#f032e6', 'rgb':'(240, 50, 230)', 'rgba':'(240, 50, 230, 0.5)'},
    {'name':'Teal', 'hex':'#008080', 'rgb':'(0, 128, 128)', 'rgba':'(0, 128, 128, 0.5)'},
    {'name':'Orange2', 'hex':'#ff7518', 'rgb':'(255, 117, 24)', 'rgba':'(255, 117, 24, 0.5)'},
    {'name':'Lavender', 'hex':'#e6beff', 'rgb':'(230, 190, 255)', 'rgba':'(230, 190, 255, 0.5)'},
    {'name':'Brown', 'hex':'#aa6e28', 'rgb':'(170, 110, 40)', 'rgba':'(170, 110, 40, 0.5)'},
    {'name':'Maroon', 'hex':'#800000', 'rgb':'(128, 0, 0)', 'rgba':'(128, 0, 0, 0.5)'},
    {'name':'Olive', 'hex':'#808000', 'rgb':'(128, 128, 0)', 'rgba':'(128, 128, 0, 0.5)'},
    {'name':'Coral', 'hex':'#ffd8b1', 'rgb':'(255, 215, 180)', 'rgba':'(255, 215, 180, 0.5)'},
    {'name':'Navy', 'hex':'#000080', 'rgb':'(0, 0, 128)', 'rgba':'(0, 0, 128, 0.5)'},

    {'name':'Pink2', 'hex':'#F0AAAA', 'rgb':'(240, 170, 170)', 'rgba':'(240, 170, 170, 0.5)'},
    {'name':'Mint2', 'hex':'#96E6B4', 'rgb':'(150, 230, 180)', 'rgba':'(150, 230, 180, 0.5)'},
    {'name':'Yellow', 'hex':'#FFD700', 'rgb':'(255, 215, 0)', 'rgba':'(255, 215, 0, 0.5)'},
    {'name':'Cyan2', 'hex':'#60C8E8', 'rgb':'(96, 200, 232)', 'rgba':'(96, 200, 232, 0.5)'},
    {'name':'Beige2', 'hex':'#E6D7B4', 'rgb':'(230, 215, 180)', 'rgba':'(230, 215, 180, 0.5)'},
    {'name':'Lime2', 'hex':'#C3E61E', 'rgb':'(195, 230, 30)', 'rgba':'(195, 230, 30, 0.5)'},

    {'name':'White', 'hex':'#FFFFFF', 'rgb':'(255, 255, 255)', 'rgba':'(255, 255, 255, 0.5)'},
    {'name':'Black', 'hex':'#000000', 'rgb':'(0, 0, 0)', 'rgba':'(0, 0, 0, 0.5)'}
], n_myc = 19,

	// Data color
	dcolor = {'name':'Grey', 'hex':'#808080', 'rgb':'(128,128,128)', 'rgba':'(128,128,128, 0.5)'},

	// Main reducer color
	mcolor = {'name':'Blue', 'hex':'#0082c8', 'rgb':'(0, 130, 200)', 'rgba':'(0, 130, 200, 0.5)'},

	// Residuals color
	rcolor = {'name':'Darkblue', 'hex':'#386cb0', 'rgb':'(56,108,176)', 'rgba':'(56,108,176, 0.5)'};


// Manage URL passed parameters
var c_imod = 0;		 // Currently plotted model index

if ( window.location.search !== '' ) {
    const urlParams = new URLSearchParams(window.location.search);

	// Check if using amCharts animation theme (default false)
	if ( urlParams.has('animation') )
		am_anim = true;

	// Check for the initial model to show (default 0)
	if ( urlParams.has('model') )
		c_imod = urlParams.get('model') - 1;

}


// -- Detect exit fullscreen mode and show header

if ( document.addEventListener ) {
	document.addEventListener('fullscreenchange', exitFSHandler, false);
	document.addEventListener('mozfullscreenchange', exitFSHandler, false);
	document.addEventListener('MSFullscreenChange', exitFSHandler, false);
	document.addEventListener('webkitfullscreenchange', exitFSHandler, false);
}

function exitFSHandler() {
	if ( !document.webkitIsFullScreen && !document.mozFullScreen && !document.msFullscreenElement )
		document.getElementById('hdrdiv').classList.remove('div-hide');
	document.getElementById('fullscreen-i').setAttribute('href', '#expand');
}


// -- Perform a cumulative sum/sum^2 of an array

const cumulativeSum = (a) => {
	return a.map((sum => value => sum += value)(0));
}

const cumulativeSum2 = (a) => {
	return a.map((sum => value => sum += value*value)(0));
}


// -- Format numbers > 1000 adding the "," separator

const numberWithCommas = (x) => {
	return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}


// -- Remove any ANSI code from string

const stripansi = (s) => {
	return s.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g,'');
}


// -- Compute the number of fractional "significant" digits in sequential values from the given (~constant) step

const nfSignificant = (x) => {
	return Math.max((Math.abs(x) % 1).toPrecision(1).length - 2, 0);
}


// -- Format the parameters range at a given digits precision

const pRange = (low, high, np) => {
	if ( low === null && high === null )
		return '';

	if ( np === undefined )
		np = 4;

	if ( low === undefined || typeof low !== 'number' )
		v = '-Inf';
	else {
		v = low;
		if ( ! Number.isInteger(v) )
			v = +v.toPrecision(np);  // To number to remove trailing 0s
	}
	if ( high === undefined || typeof high !== 'number' )
		v += ':Inf';
	else {
		var v2 = high;
		if ( ! Number.isInteger(v2) )
			v2 = +v2.toPrecision(np);
		v += ':'+ v2;
	}
	return v;
}


// -- Hidden object?

function isHidden(e) {
	return (e.offsetParent === null)
}



//
// -- Toggle full-screen mode. Also toggle visibility of a user given div.

function toggleFullScreen(id_div) {
	var element = document.documentElement,
	    fs_i = document.getElementById('fullscreen-i'),
	    isFullscreen = document.webkitIsFullScreen || document.mozFullScreen || false;

	element.requestFullScreen = element.requestFullScreen || element.webkitRequestFullScreen || element.mozRequestFullScreen || function () { return false; };
	document.cancelFullScreen = document.cancelFullScreen || document.webkitCancelFullScreen || document.mozCancelFullScreen || function () { return false; };

	if ( isFullscreen ) {
		fs_i.setAttribute('href', '#expand');
		document.cancelFullScreen();
	} else {
		fs_i.setAttribute('href', '#shrink');
		element.requestFullScreen();
	}

	if ( id_div !== undefined )  // Toggle the given div
		document.getElementById(id_div).classList.toggle('div-hide');
}

//
// Functions to read from chart_data

function getMainComp(chart_data, epoch) {
	return chart_data['+'].models[epoch]['+'].maincomp[''];
}

function getModels(chart_data, epoch) {
	return chart_data['+'].models[epoch]['+'];
}

function getUnfoldedDomainAxis(chart_data, epoch) {
	return chart_data['+']['models'][epoch]['+']['domain']['+'].axis[''][0];
}

function getFoldedDomainAxis(chart_data, epoch) {
	return chart_data['+']['models'][epoch]['+']['folded_domain']['+'].axis[''][0];
}

function getDataDomainAxis(chart_data, epoch) {
	return chart_data['+'].data[epoch]['+']['domain']['+'].axis[''][0];
}

function getComps(chart_data, epoch) {
	out = chart_data['+'].models[epoch]['+'].comps['+'];
	for (const [key, value] of Object.entries(out)) {
		out[key] = value["+"].buffer;
	}
//	console.log(out);
return out;
}

function getData(chart_data, epoch) {
	return chart_data['+'].data[epoch]['+'];
}

function getNEpochs(chart_data) {
	return chart_data['+'].nepochs;
}

function getMeta(chart_data, epoch) {
	return chart_data['+']['models'][epoch]['+'].meta['+'];
}

function getNData(chart_data) {
	return chart_data['+'].fitsummary['+'].ndata;
}

function getNFree(chart_data) {
	return chart_data['+'].fitsummary['+'].nfree;
}


//
// -- Extract and manage the metadata info

function getauxinfo() {  // TODO

	document.getElementById('app_info').innerHTML = '';

	// Multiple models for the same "object" are allowed

	aux.NEpochs = getNEpochs(chart_data);
	aux.is_multimodel = (aux.NEpochs > 1);
	aux.maincomp = [];  // The name of the main component buffer

	var cnames = [], desc, cdata, mea, x_lab, y_lab, n_xmea, x_step;

	if (chart_data.length == 0) {
		alert('No data found.')
		return;
	}
	aux.meta = getMeta(chart_data, 0);  // TODO: why epoch 0?
	aux.ndata_fit = getNData(chart_data);
	aux.nfree_fit = getNFree(chart_data);

	aux.modinfo = [];
	aux.modinfo.length = 0;
	aux.datinfo = [];
	aux.datinfo.length = 0;

	// Add loop also for the measures (TODO)
	for (var i = 0; i < aux.NEpochs; i++) {
		var n_reb = 1,
			y_min = 1e32,
			y_max = -1e32,
			x_scale = 1,
			y_scale = 1,
			x_rng = null,
			y_rng = null,
			x_lg = false,
			y_lg = false,
			x_lab = 'X label',
			y_lab = 'Y label',
			title = 'GModelFitViewer',
			desc = '<span style="color: #69c; font-weight: bold;">',
			v_labs = ['values', 'uncerts'];

			cdata = getModels(chart_data, i);
			if ( chart_data['+'].data[i] !== undefined )
				mea = getData(chart_data, i);

		cnames = Object.keys(cdata.comps['+']);
		aux.maincomp.push(cdata.maincomp[''].substring(4));  // maincomp ~= _TS_main

		// Labels in Measures
		if ( mea.labels[''] !== undefined ) {
			v_labs = mea.labels[''];
		}

		if ( cdata.meta !== undefined ) {
			var meta = getMeta(chart_data, i);
			if ( meta.rebin )
				n_reb = meta.rebin;
			if ( meta.xrange )
				x_rng = meta.xrange;
			if ( meta.yrange )
				y_rng = meta.yrange;
			if ( meta.xlog )
				x_lg = meta.xlog;
			if ( meta.ylog )
				y_lg = meta.ylog;
			if ( meta.xlabel ) {
				x_lab = meta.xlabel;
				if ( x_lab ) {
					if ( meta.xscale !== null && meta.xscale !== 1 ) {
						var un = meta.xscale.toString().replace(/\+/,'');
						x_lab += ' [[x '+ un +']]';
					}
					if ( meta.xunit )
						x_lab += ' ('+ meta.xunit +')';
				}
			}

			if ( meta.ylabel ) {
				y_lab = meta.ylabel;
				if (  y_lab ) {
					if ( meta.yscale !== null && meta.yscale !== 1 ) {
						var un = meta.yscale.toString().replace(/\+/,'');
						y_lab += ' [[x '+ un +']]';
					}
					if ( meta.yunit )
						y_lab += ' ('+ meta.yunit +')';
				}
			}

			if ( meta !== undefined && meta.title ) {
				title = meta.title;
				desc += meta.title;
			} else
				desc += 'Model '+ i;

		}

		desc += '</span>';


		// Range check on data and model components?
		if ( y_rng ) {
			y_min = y_rng[0];
			y_max = y_rng[1];
		} else {  // Y range is model dependent ...
			y_min = Math.min(y_min, Math.min(...mea.values[''][0]));
			y_max = Math.max(y_max, Math.max(...mea.values[''][0]));
			for (var j = 0; j < cnames.length; j++) {
				y_min = Math.min(y_min, Math.min(...(cdata.comps['+'][cnames[j]]['+'].buffer)));
				y_max = Math.max(y_max, Math.max(...(cdata.comps['+'][cnames[j]]['+'].buffer)));
				console.log('Model #, comp. #, y_min, y_max:', i, j, y_min, y_max);
			}
			var e_max = 3*Math.min(...mea.values[''][1]);  // TODO
			console.log('Error max:', e_max);
			y_min -= e_max;
			y_max += e_max;
		}

		// Scale Y axis for values < 0.01 or > 100
		var log10scale2 = Math.floor(Math.log10(y_max));

		if ( log10scale2 < -2 || log10scale2 > 2 )
			y_scale = Math.pow(10, log10scale2);
		else
			log10scale2 = 0;

		//console.log('log10scale2, y_scale', log10scale2, y_scale);

		var datadomain = getDataDomainAxis(chart_data, i);
		n_xmea = datadomain.length;
		var moddomain = getFoldedDomainAxis(chart_data, i);
		var n_xcomp = moddomain.length;
		console.log('n_xmea, n_xcomp', n_xmea, n_xcomp);

		//x_step = Math.abs(cdata.domain['+'].axis[''][0][1] - cdata.domain['+'].axis[''][0][0]);
		x_step = Math.abs(moddomain[1] - moddomain[0]);
		console.log('n_xmea, x_min, x_max:', n_xmea, datadomain[0], datadomain[n_xmea - 1]);
		aux.modinfo.push({
			title: title,
			p_title: desc,
			x_label: x_lab,
			y_label: y_lab,
			v_labels: v_labs,
			nx_mea: n_xmea,
			nx_comp: n_xcomp,
			x_min: +(datadomain[0]).toPrecision(4),
			x_max: +(datadomain[n_xmea - 1]).toPrecision(4),
			x_step: x_step,
			x_scale: x_scale,
			y_scale: y_scale,
			x_range: x_rng,
			y_range: y_rng,
			x_log: x_lg,
			y_log: y_lg,
			//y_min: (y_min - y_rng*0.05) / y_scale,
			//y_max: (y_max + y_rng*0.05) / y_scale,
			y_min: +(y_min / y_scale).toPrecision(4),
			y_max: +(y_max / y_scale).toPrecision(4),
			nf_sig: nfSignificant(x_step),
			components: cnames,
			n_comps: cnames.length
		});
		// Equidistance check (TODO)
		aux.modinfo[i].x_equi = Math.abs((aux.modinfo[i].x_max - aux.modinfo[i].x_min)/(n_xmea-1) - x_step) < 0.001;
	}  // end for i


	// The model selector
	var  ss = document.getElementById('p_selector'),
		d = document.getElementById('mod_sel-div');
	ss.innerHTML = '';

	// Create only if more than one model
	if ( aux.NEpochs < 2 )
		d.setAttribute('class', 'div-hide');
	else {
		d.setAttribute('class', 'div-show-inline');

		// Append model select list
		for (var i = 0; i < aux.NEpochs; i++) {
			var lab, option = document.createElement('option');
			option.value = i;

			cdata = getModels(chart_data, i);
			if ( cdata.meta !== undefined && cdata.meta['+'].title !== undefined )
				lab = cdata.meta['+'].title
			else
				lab = "Model "+ i;
			option.text = (i+1).toString() +': '+ lab;
			ss.appendChild(option);
		}

		if ( c_imod == 0 )
			document.getElementById('prev_model').classList.add('div-hide');
		else if ( c_imod == aux.NEpochs - 1 )
			document.getElementById('next_model').classList.add('div-hide');
	}

	for (var i = 0; i < aux.NEpochs; i++) {
		aux.datinfo.push({
			resid_visible: false,
			resid_color: rcolor.hex
		});
	}

}  // end getauxinfo


//
// -- From custom "model/measure" structures to default amchart data structure

var mydata2chart = function(isel) {
	if ( isel === undefined )
		isel = c_imod;

	//console.log('mydata2chart isel:', isel);
	var cdata, mea;
	cdata = getModels(chart_data, isel);
	if ( chart_data['+'].data[isel] !== undefined )
		//mea = chart_data['+'].data[isel]['+'];
		mea = getData(chart_data, isel);

	// Change web page and plot labels
	document.title = cdata.meta['+'].title;
	p_title.innerHTML = aux.modinfo[isel].p_title;

	var x = getDataDomainAxis(chart_data, isel),
		cnames = aux.modinfo[isel].components,
		fscale = Math.pow(10, aux.modinfo[isel].nf_sig),
		mydata = {dat: [], res: [], comp: []}, data, res, comps;


	// X values rounded to the N sig. factional digits
	var cs2 = 0;
	if ( aux.NEpochs > 0 ) {
		for (var i = 0; i < aux.modinfo[isel].nx_mea; i++) {  // folded domain
			data = {};
			data['xc'] = x[i];
			data['y'] = mea.values[''][0][i] / aux.modinfo[isel].y_scale;
			data['error'] = mea.values[''][1][i] / aux.modinfo[isel].y_scale;
			data['model'] = cdata.folded[i] / aux.modinfo[isel].y_scale;
			mydata.dat.push(data);

			res = {};
			res['x'] = data['xc'];
			res['resid'] = (mea.values[''][0][i] - cdata.folded[i]) / mea.values[''][1][i];
			// Normalised cumulative sum of squared residuals
			cs2 += res['resid']*res['resid'];
			res['csr2'] = cs2 / (aux.ndata_fit  - aux.nfree_fit);
			mydata.res.push(res);

			//vals['err_lo'] = (mea.values[''][0][i] - mea.values[''][1][i]) / aux.modinfo[isel].y_scale;
			//vals['err_up'] = (mea.values[''][0][i] + mea.values[''][1][i]) / aux.modinfo[isel].y_scale;
		}
	}

	x = getUnfoldedDomainAxis(chart_data, isel);
	for (var i = 0; i < x.length; i++) {
		comps = {};
		comps['comp_x'] = x[i];

		for (var j = 0; j < aux.modinfo[isel].n_comps; j++)  // Components
			comps[cnames[j]] = cdata.comps['+'][cnames[j]]['+'].buffer[i] / aux.modinfo[isel].y_scale;

		mydata.comp.push(comps);
	}

	return mydata;

}  // end mydata2chart


//
// -- Create series for the the main reducer of a model.

function createMainReducer(isel) {
	if ( isel === undefined )
		isel = c_imod;

	var p = getModels(chart_data, isel);

	var series = chart.series.push(
		am5xy.LineSeries.new(root, {
			name: 'Model',
			xAxis: vxAxis,
			yAxis: valueAxis,
			valueXField: "xc",
			valueYField: "model",
			stroke: mcolor.hex,
			fill: mcolor.hex
		})
	);
	series.strokes.template.setAll({
		strokeWidth: 2
	});

	i_chmodel = chart.series.length - 1;
	console.log('i_chmodel', i_chmodel);

	//series.legendLabelText = 'Model [#fff]______[/]';
	series.legendLabelText = 'Model';
	series.data.setAll(my_chartdata.dat);

	// No data, just the model: use series also for the X axis scrolling
	if ( aux.NEpochs == 0 ) {
		document.getElementById('box-resid-in').style.visibility = 'hidden';
		chart.scrollbarX.series.push(series);
		  }
}


//
// -- Create axis range for the residuals

// The +/- N sigma shaded region with the (dashed) 0 level

function createResidRange(resid) {

	// 0 level dashed line
	range0DataItem = resyAxis.makeDataItem({
		value: 0,
		endValue: undefined
	});
	range0 = resyAxis.createAxisRange(range0DataItem);
	range0.get("grid").setAll({
		stroke: am5.color("#396478"),
		strokeOpacity: 0.5,
		strokeWidth: 2
	});


	// +/- N sigma shaded area with invisible strokes
	resrangeDataItem = resyAxis.makeDataItem({
		value: -n_sigma,
		endValue: n_sigma
	});
	/* Could also highlight the residuals data line within the range
	   resrange = resid.createAxisRange(resrangeDataItem);
	   resrange.strokes.template.setAll({
	   stroke: am5.color("#ff6478"),
	   strokeWidth: 3
	   });
	   resrangeDataItem.get("axisFill").setAll({
	*/
	resrange = resyAxis.createAxisRange(resrangeDataItem);
	resrange.get("axisFill").setAll({
		fill: am5.color("#666"),
		fillOpacity: 0.1,
		visible: true
	});

}  // end createResidRange


//
// -- Create the residuals series

function createResiduals(isel) {
	if ( isel === undefined )
		isel = c_imod;

	if ( resid ) resid.dispose();

	resid = chart.series.push(
		am5xy.LineSeries.new(root, {
			valueXField: 'x',
			valueYField: 'resid',
			name: 'Residuals',
			legendLabelText: 'Resid.',
			xAxis: vxAxis,
			yAxis: resyAxis,
			fill: aux.datinfo[isel].resid_color,
			stroke: aux.datinfo[isel].resid_color,
			hiddenInLegend : true  // Not in the main legend
		})
	);
	resid.data.setAll(my_chartdata.res);

	// -- Ceate the sum of squared residuals series

	if ( csr2 ) csr2.dispose();

	csr2 = chart.series.push(
		am5xy.LineSeries.new(root, {
			valueXField: 'x',
			valueYField: 'csr2',
			name: 'CumulativeChi2',
			xAxis : vxAxis,
			yAxis: csr2yAxis,
			hiddenInLegend: true,  // Not in the main legend
			stroke: am5.color("#990000")
		})
	);
	csr2.strokes.template.setAll({
		strokeWidth: 2
	});
	csr2.data.setAll(my_chartdata.res);

}  // end createResiduals


//
// -- Update residuals Nsigma shaded range and axis zoom

function n_sigma_update(e) {
	if ( ! resyAxis.isVisible() )
		return;

	n_sigma = +e.value;
	resrangeDataItem.set('value', -n_sigma);
	resrangeDataItem.set('endValue', n_sigma);
	resyAxis.minDefined = -n_sigma - 1;
	resyAxis.maxDefined = n_sigma + 1;

	// Also zoom the axis range
	setTimeout(function() {
		resyAxis.zoomToValues(-n_sigma - 1, n_sigma + 1);
	}, 100);

}  // end n_sigma_update


//
// -- Create the data series

function createDataSeries(isel) {
	if ( isel === undefined )
		isel = c_imod;

	// No data, just the model
	if ( aux.NEpochs == 0 ) {
		resplot_dispose();
		createMainReducer(isel);
		return;
	}

	if ( sdata ) sdata.dispose();

	sdata = chart.series.push(
		am5xy.LineSeries.new(root, {
			name: 'data',
			legendLabelText: 'Data',
			xAxis: vxAxis,
			yAxis: valueAxis,
			valueXField: "xc",
			valueYField: "y",
			stroke: dcolor.hex,
			fill: dcolor.hex,
			//tooltip: am5.Tooltip.new(root, {  // Data value tooltip?
			//labelText: "{valueY}"
			//})
		})
	);
	sdata.strokes.template.setAll({
		strokeWidth: 2
	});

	/*
	  sdata.bullets.push(function() {
      return am5.Bullet.new(root, {
	  sprite: am5.Circle.new(root, {
	  radius: 3,
	  //fill: sdata.get("fill"),
	  fill: null,
	  stroke: dcolor.hex,
	  strokeWidth: 1,
	  opacity: 1
	  })
      });
	  });
	*/
	sdata.data.setAll(my_chartdata.dat);


	// -- The uncertainties error bars

	var series = chart.series.push(
		am5xy.LineSeries.new(root, {
			valueXField: 'xc',
			valueYField: 'y',
			name: 'uncert',
			legendLabelText: 'Uncert.',
			xAxis: vxAxis,
			yAxis: valueAxis,
			stroke: null,
			fill: dcolor.hex,
			visible: false  // Hidden by default
		})
	);

	series.data.setAll(my_chartdata.dat);


	// Add error bars as bullet with custom graphics
	series.bullets.push(function() {
		var graphics = am5.Graphics.new(root, {
			stroke: dcolor.hex,
			strokeWidth: 1,
			fill: null,
			draw: function(display, target) {
				var dataItem = target.dataItem;

				var  err = dataItem.dataContext.error,
					y0 = valueAxis.valueToPosition(0),
					y1 = valueAxis.valueToPosition(err);
				var height =
					valueAxis.get("renderer").positionToCoordinate(y1) - valueAxis.get("renderer").positionToCoordinate(y0);
				display.moveTo(0, -height);
				display.lineTo(0, height);
			}
		});

		return am5.Bullet.new(root, {
			dynamic: true,
			sprite: graphics
		});
	});


	// Fill the scrollbar values
	sbseries.data.setAll(my_chartdata.dat);


	// Main Reducer always first (and before residuals and components)
	createMainReducer(isel);


	// Residuals
	document.getElementById('box-resid-in').style.visibility = 'visible';
	createResiduals(isel);

	// Residuals visible?
	resid_plot = aux.datinfo[isel].resid_visible;

	// Reset plot for residuals?
	if ( resid_plot )
		plot_reset();

}  // end createDataSeries


//
// -- Create series for each component of a model

function createCompSeries(isel) {
	if ( isel === undefined )
		isel = c_imod;

	var p = getModels(chart_data, isel);

	var series, cname, hs, icol = 0;

	// -- Components
	for (var i = 0; i < aux.modinfo[isel].n_comps; i++) {  // Components in a model
		cname = aux.modinfo[isel].components[i];
		console.log('Create component:', cname);

		series = chart.series.push(
			am5xy.LineSeries.new(root, {
				valueXField: 'comp_x',
				valueYField: cname,
				xAxis : vxAxis,
				yAxis: valueAxis,
				name: cname,
				strokeWidth: 2,
				showOnInit: false,
				stroke: mycolors[icol % n_myc].hex,
				fill: mycolors[icol % n_myc].hex,
				visible: false
			})
		);
		series.strokes.template.setAll({
			strokeWidth: 2,
			stroke: mycolors[icol % n_myc].hex,
			visible: true
		});
		series.data.setAll(my_chartdata.comp);
		console.log('  color:', mycolors[icol % n_myc].name, mycolors[icol % n_myc].hex);
		icol++;
	}  // end for i

}  // end createCompSeries



//
// -- Cursor creation and events management

function createCursor() {
	var cursor = chart.set("cursor",
						   am5xy.XYCursor.new(root, {
							   behavior: "zoomXY",
							   xAxis: vxAxis,
							   yAxis: valueAxis
						   })
						  );
	cursor.lineX.set("forceHidden", false);
	cursor.lineY.set("forceHidden", false);

	//vxAxis.set("tooltip", am5.Tooltip.new(root, {}));
	//valueAxis.set("tooltip", am5.Tooltip.new(root, {}));


	// Container to hold cursor X, Y values
	var curXY_container = am5.Container.new(root, {
		visible: true,
		layout: root.horizontalLayout,
		minWidth: 200,
		height: 36,
		x: am5.p50,
		y: 0,
		centerX: 0,
		centerY: 36,
		background: am5.RoundedRectangle.new(root, {
			fill: am5.color('#aaa'),
			fillOpacity: 0.2
		})
	});

	chart.plotContainer.children.push(curXY_container);

	// Text Label in the cursor Container
	var curXY_text = curXY_container.children.push(am5.Label.new(root, {
		id: 'cursor_pos',
		text: '',
		marginRight: 0,
		fontWeight: 'bolder',
		fill: dcolor.hex
	}));

	// Monitor actual values of cursor position
	var cursorPosition = {
		x: null,
		y: null
	};

	cursor.events.on("cursormoved", function(ev) {
		if ( cur_track ) {
			var x = ev.target.getPrivate("positionX");
			var y = ev.target.getPrivate("positionY");
			if ( curXY_container.isHidden() )
				curXY_container.show();
			cursorPosition.x = vxAxis.positionToValue(vxAxis.toAxisPosition(x));
			if ( resyAxis.isVisible() )
				cursorPosition.y = resyAxis.positionToValue(resyAxis.toAxisPosition(y));
			else
				cursorPosition.y = valueAxis.positionToValue(valueAxis.toAxisPosition(y));
			var cur_pos = '[black]X:[/] '+ cursorPosition.x.toPrecision(6) +'\xa0\xa0\ [black]Y:[/] '+ cursorPosition.y.toPrecision(6);
			curXY_container.setAll({x: am5.percent(x*100), y: am5.percent(y*100)});
			curXY_text.setAll({text: cur_pos});
		}

	});

	// Hide container when cursor out of the plot
	cursor.events.on("cursorhidden", function() {
		curXY_container.hide();
	});


	// -- Plot zoom management

	// See https://www.amcharts.com/docs/v5/tutorials/axis-zoom-end-event/
	var xstartEndChangeTimeout, ystartEndChangeTimeout;

	vxAxis.on("start", handleXStartEndChange);
	vxAxis.on("end", handleXStartEndChange);
	valueAxis.on("start", handleYStartEndChange);
	valueAxis.on("end", handleYStartEndChange);

	resyAxis.on("start", handleYStartEndChange);
	resyAxis.on("end", handleYStartEndChange);

	// csr2 range kept static
	csr2yAxis.on("start", function() {csr2yAxis.zoomToValues(0, csr2yAxis.getPrivate('max'))});
	csr2yAxis.on("end", function() {csr2yAxis.zoomToValues(0, csr2yAxis.getPrivate('max'))});

	function handleXStartEndChange() {
		if (xstartEndChangeTimeout) {
			clearTimeout(xstartEndChangeTimeout);
		}
		xstartEndChangeTimeout = setTimeout(function() {
			zoomXEnded();
		}, 50);
	}

	function handleYStartEndChange() {
		if (ystartEndChangeTimeout) {
			clearTimeout(ystartEndChangeTimeout);
		}
		ystartEndChangeTimeout = setTimeout(function() {
			zoomYEnded();
		}, 50);
	}

	// -- X zoom management

	function zoomXEnded() {
		console.log("Zoom X ended!");
		console.log('vxAxis ranges:', vxAxis.get('min'), vxAxis.get('max'), vxAxis.get('start'), vxAxis.get('end'));

		var x_min = vxAxis.get('min') + vxAxis.get('start') * (vxAxis.get('max') - vxAxis.get('min')),
			x_max = vxAxis.get('min') + vxAxis.get('end') * (vxAxis.get('max') - vxAxis.get('min'));

		x_range.min = +x_min.toPrecision(4);
		x_range.max = +x_max.toPrecision(4);

		console.log("zoomXEnded: X cursor selected from "+ x_min +" to "+ x_max);
		inxy_ranges.xmin.value = x_min.toPrecision(4);
		inxy_ranges.xmax.value = x_max.toPrecision(4);
		log_label_ckeck('x');

	}  // end zoomXEnded


	// -- Y zoom management

	function zoomYEnded() {
		console.log("Zoom Y ended!");
		//console.log("Start, End:", valueAxis.getPrivate("selectionMin"), valueAxis.getPrivate("selectionMax"));

		var y_min, y_max;

		if ( resyAxis.isVisible() ) {
			console.log('zoomYEnded: resyAxis ranges:', resyAxis.get('min'), resyAxis.get('max'), resyAxis.get('start'), resyAxis.get('end'));
			y_min = resyAxis.get('min') + resyAxis.get('start') * (resyAxis.get('max') - resyAxis.get('min')),
			y_max = resyAxis.get('min') + resyAxis.get('end') * (resyAxis.get('max') - resyAxis.get('min'));
		} else {
			console.log('zoomYEnded: valueAxis ranges:', valueAxis.get('min'), valueAxis.get('max'), valueAxis.get('start'), valueAxis.get('end'));
			y_min = valueAxis.get('min') + valueAxis.get('start') * (valueAxis.get('max') - valueAxis.get('min')),
			y_max = valueAxis.get('min') + valueAxis.get('end') * (valueAxis.get('max') - valueAxis.get('min'));
		}
		console.log("zoomYEnded: Y cursor selected from "+ y_min +" to "+ y_max);

		y_range.min = +y_min.toPrecision(4);
		y_range.max = +y_max.toPrecision(4);

		inxy_ranges.ymin.value = y_min.toPrecision(4);
		inxy_ranges.ymax.value = y_max.toPrecision(4);
		log_label_ckeck('y');

	}  // end zoomYEnded

}  // end createCursor


//
// -- Use aux data to set the main plot X and Y axis labels, X range and Y tick values format

function set_xy_from_aux() {

	// X axis label
	chart.xAxes.getIndex(0).children.unshift(
		am5xy.AxisLabel.new(root, {
			text: aux.modinfo[c_imod].x_label,
			fontSize: 18,
			x: am5.p50,
			centerX:am5.p50
		})
	);

	// Y axis label
	chart.yAxes.getIndex(0).children.unshift(
		am5xy.AxisLabel.new(root, {
			text: aux.modinfo[c_imod].y_label,
			fontSize: 18,
			y: am5.p50,
			rotation: -90
		})
	);
	//To modify: chart.yAxes.getIndex(0).children.getIndex(0).set('text', 'New label')

	// X axis range
	chart.xAxes.getIndex(0).set('min', aux.modinfo[c_imod].x_min);
	chart.xAxes.getIndex(0).set('max', aux.modinfo[c_imod].x_max);

	// Use exponential notation for Y axis labels when small values are involved
	valueAxis.numberFormatter = am5.NumberFormatter.new(root, {});

	if ( aux.modinfo[c_imod].y_max < 0.1 )
		valueAxis.numberFormatter.set("numberFormat", '#.00e');
	else
		valueAxis.numberFormatter.set("numberFormat", "#,###.#####");

}  // end set_xy_from_aux


//
// -- Select current model from multi-models list

function p_select(isel, new_file) {
	var ip = document.getElementById('p_selector').value;

	if ( isel === undefined )
		isel = +ip;
	else {
		if ( isel === 'prev' )
			isel = +ip - 1;
		else if ( isel === 'next' )
			isel = +ip + 1;

		document.getElementById('p_selector').value = isel;
	}

	if ( isel == 0 ) {
		document.getElementById('prev_model').classList.add('div-hide');
		document.getElementById('next_model').classList.remove('div-hide');
	} else if ( isel == aux.NEpochs - 1 ) {
		document.getElementById('prev_model').classList.remove('div-hide');
		document.getElementById('next_model').classList.add('div-hide');
	} else {
		document.getElementById('prev_model').classList.remove('div-hide');
		document.getElementById('next_model').classList.remove('div-hide');
	}

	if ( new_file === undefined )
		new_file = false;

	c_imod = isel;  // Set index of selected model

	// Create the chart
	create_chart();


	// The residuals highlighted range
	createResidRange(resid);

	// The cursor
	createCursor();

	// The JSON reformatted data
	my_chartdata = mydata2chart(isel);

	// The series
	createDataSeries();
	createCompSeries();

	// Reset X / Y ranges
	xy_range_reset();
	set_xy_from_aux();  // Some X and Y settings from aux data

	// First reset plot area to data, set to linear scale and clear all series
	plot_reset();

	// The main legend set legend data after all the events are set on template
	createMainLegend();

	createFitLogTabs();  // The fit log tables

	// Appearance settings
	sdata.appear(1000,100);
	chart.series.getIndex(2).appear(1500,100);  // The model
}  // end p_select


//
// -- Legends

// -- Main plot legend

function createMainLegend() {
	if ( legend ) legend.dispose();

	legend = chart.children.push(
		am5.Legend.new(root, {
			centerX: am5.p50,
			x: am5.p50,
			marginTop: 20,
			useDefaultMarker: true,
			layout: am5.GridLayout.new(root, {
				//maxColumns: 5,
				fixedWidthGrid: true
			}),
			//tooltip: am5.Tooltip.new(root, {labelText: ttAdapter})
		})
	);


	//legend.labels.template.text = "[bold]{name}[/]";
	legend.labels.template.set("fontWeight", 600);
	legend.valueLabels.template.set("forceHidden", true);  // Hide the value part of the label

	legend.markerRectangles.template.setAll({
		cornerRadiusTL: 8,
		cornerRadiusTR: 8,
		cornerRadiusBL: 8,
		cornerRadiusBR: 8,
		width: 16,
		height: 16,
		strokeWidth: 2,
		stroke: am5.color("#ccc")
	});


	// When legend item container is hovered highlight the series
	legend.itemContainers.template.events.on("pointerover", function(e) {
		var series = e.target.dataItem.dataContext;
		series.strokes.template.setAll({
			strokeWidth: 4
		});
	});

	// When legend item container is unhovered reset the series stroke width
	legend.itemContainers.template.events.on("pointerout", function(e) {
		var series = e.target.dataItem.dataContext;
		series.strokes.template.setAll({
			strokeWidth: 2
		});
	});
	legend.data.setAll(chart.series.values);

	// Highlight the data/uncertainties/model series in the legend
	for ( var i = 0; i < 3; i++ ) {
		//console.log('legend item:', i, legend.itemContainers.getIndex(i));
		if ( legend.itemContainers.getIndex(i) !== undefined )
			legend.itemContainers.getIndex(i).set('background', am5.RoundedRectangle.new(root, { fill: am5.color(0x186680), fillOpacity: 0.2 }));
	}

	//See https://github.com/amcharts/amcharts4/issues/939
	if ( resid && !resid.isDisposed() )
		resid.get("legendDataItem").get("itemContainer").hide();
	if ( csr2 && !csr2.isDisposed() )
		csr2.get("legendDataItem").get("itemContainer").hide();

}  // end createMainLegend


// -- Reset the plot (def. to show data)

function plot_reset(lin_reset=false) {
	if ( resid_plot ) {
		if ( lin_reset )
			x_linlog_toggle(true);
		// Hide all series but resid and csr2
		valueAxis.hide();
		var sname;
		for (var i = 0; i < chart.series.length; i++ ) {
			sname = chart.series.getIndex(i).get('name');
			if ( sname !== resid.get('name') && sname !== csr2.get('name') && chart.series.getIndex(i).get('visible') )
				chart.series.getIndex(i).hide();
		}

		n_sigma = +document.getElementById('n_sigma').value;
		resrangeDataItem.set('value', -n_sigma);
		resrangeDataItem.set('endValue', n_sigma);
		resrangeDataItem.get("axisFill").set('fillOpacity', 0.1);
		valueAxis.gridContainer.set('opacity', 0);
		resyAxis.gridContainer.set('opacity', 1);
		resyAxis.show();
		csr2yAxis.show();

		y_linlog_toggle(true);

		resyAxis.zoomToValues(-n_sigma - 1, n_sigma + 1);

		// Show residuals and sum of squared residuals series
		if ( resid && !resid.isDisposed() )
			resid.show();
		if ( csr2 && !csr2.isDisposed() )
			csr2.show();
		document.getElementById('resid-cb').checked = true;
	} else {
		if ( lin_reset ) {
			console.log("Reset X/Y to linear");
			x_linlog_toggle(true);
			y_linlog_toggle(true);
		}
		resrangeDataItem.get("axisFill").set('fillOpacity', 0);
		valueAxis.gridContainer.set('opacity', 1);
		resyAxis.gridContainer.set('opacity', 0);
		resyAxis.hide();
		csr2yAxis.hide();

		if ( resid && !resid.isDisposed() )
			resid.hide();
		if ( csr2 && !csr2.isDisposed() )
			csr2.hide();

		// Show data and model series
		valueAxis.show();
		sdata.show();
		chart.series.values[i_chmodel].show();
		document.getElementById('resid-cb').checked = false;
	}
}  // end plot_reset


// -- Dispose residuals plot series (e.g. when only Model available) - TODO

function resplot_dispose() {
	if ( resid && !resid.isDisposed() )
		resid.dispose();
	if ( csr2 && !csr2.isDisposed() )
		csr2.dispose();

}  // end resplot_dispose


// -- Residuals legend

function createResidLegend() {

	// Toggle residuals visibility
	// Note that in v5 hide() and show() do not causes a full range replot!

	document.getElementById('resid-cb').addEventListener('click', function(ev) {
		if ( resyAxis.isVisible() )
			resid_plot = false;
		else
			resid_plot = true;

		plot_reset();
		set_init_y_range();
	});

}  // end createResidLegend


// -- Clear range input fields

function inxy_range_reset() {
	inxy_ranges.xmin.value = '';
	inxy_ranges.xmax.value = '';
	inxy_ranges.ymin.value = '';
	inxy_ranges.ymax.value = '';

}  // end inxy_range_reset


// -- Reset X and Y plot range to initial values

function xy_range_reset() {
	inxy_range_reset();  // Clear manual range input fields
	set_init_x_range();
	set_init_y_range();

}  // end xy_range_reset


//
// -- amChart init code

function create_chart() {

	// -- Create the amCharts root element

	if ( root ) root.dispose();
	if ( root && !root.isDisposed() ) console.log('root still exists...');

	root = am5.Root.new("chartdiv");

	// Theme animated
	if ( am_anim )
		root.setThemes([
			am5themes_Animated.new(root)
		]);


	// -- Create the chart container

	if ( chart ) chart.dispose();

	chart = root.container.children.push(
		am5xy.XYChart.new(root, {
			panX: false,  // Managed by cursor
			panY: false,
			wheelY: "zoomX",
			pinchZoomX: true,
			paddingLeft: 0,
			layout: root.verticalLayout
		})
	);


	// Create the X axis

	var vxRenderer = am5xy.AxisRendererX.new(root, {});
	if ( vxAxis ) vxAxis.dispose();

	vxAxis = chart.xAxes.push(
		am5xy.ValueAxis.new(root, {
			strictMinMax: true,
			numberFormat: '#',
			renderer: vxRenderer
		})
	);

	vxAxis.valueXField = 'x';

	vxRenderer.grid.template.setAll({
		stroke: am5.color("#ddd"),
		strokeOpacity: 1
	});

	//--vxAxis.set('min', aux.modinfo[c_imod].x_min);
	//--vxAxis.set('max', aux.modinfo[c_imod].x_max);


	// -- Create the main Y-values axis

	var vAR = am5xy.AxisRendererY.new(root, {});
	if ( valueAxis ) valueAxis.dispose();

	valueAxis = chart.yAxes.push(
		am5xy.ValueAxis.new(root, {
			//maxDeviation: 1,
			strictMinMax: true,
 			renderer: vAR
		})
	);

	vAR.grid.template.setAll({
		stroke: am5.color("#ddd"),
		strokeOpacity: 1
	});


	// -- Eventually the second Y-value axis (for residuals). Note that it is only checked here!

	// The cumulative square sum of residuals

	var vAR3 = am5xy.AxisRendererY.new(root, {
		opposite: true,
		strokeOpacity: 1,
		strokeWidth: 4,
		stroke: am5.color("#900")
	});
	csr2yAxis = chart.yAxes.push(
		am5xy.ValueAxis.new(root, {
			renderer: vAR3
		})
	);

	csr2yAxis.strictMinMax = true;
	vAR3.grid.template.set("forceHidden", true);
	//csr2yAxis.gridContainer.set('opacity', 0);

	csr2yAxis.children.unshift(
		am5.Label.new(root, {
			rotation: -90,
			text: "Cumulative sum of squared residuals",
			fontSize: 18,
			fill: am5.color("#900"),
			y: am5.p50,
			centerX: am5.p50
		})
	);


	var vAR2 = am5xy.AxisRendererY.new(root, {
		strokeOpacity: 1,
		strokeWidth: 4,
		stroke: am5.color("#495C43")
	});
	resyAxis = chart.yAxes.push(
		am5xy.ValueAxis.new(root, {
			strictMinMax: true,
 			renderer: vAR2
		})
	);
	resyAxis.gridContainer.set('opacity', 0);

	resyAxis.children.unshift(
		am5.Label.new(root, {
			rotation: -90,
			text: "Normalized residuals (\u03C3)",
			fontSize: 18,
			y: am5.p50,
			centerX: am5.p50
		})
	);


	// -- Create the X axis scrollbar (not disabling labels and grid)

	chart.scrollbarX = am5xy.XYChartScrollbar.new(root, {
		orientation: "horizontal",
		height: 50
	});
	chart.set("scrollbarX", chart.scrollbarX);

	var sbxAxis = chart.scrollbarX.chart.xAxes.push(
		am5xy.ValueAxis.new(root, {
			strictMinMax: true,
			renderer: am5xy.AxisRendererX.new(root, {
				opposite: false,
				strokeOpacity: 0
			})
		})
	);

	var sbyAxis = chart.scrollbarX.chart.yAxes.push(
		am5xy.ValueAxis.new(root, {
			renderer: am5xy.AxisRendererY.new(root, {})
		})
	);

	if ( sbseries ) sbseries.dispose();

	sbseries = chart.scrollbarX.chart.series.push(
		am5xy.LineSeries.new(root, {
			xAxis: sbxAxis,
			yAxis: sbyAxis,
			valueXField: "x",
			valueYField: "y"
		})
	);

	sbseries.fills.template.setAll({
		visible: true,
		fillOpacity: 0.3
	});


	// -- Manage the click on the legend labels, in particular "residuals"

	// The export menu
	var exporting = am5plugins_exporting.Exporting.new(root, {
		menu: am5plugins_exporting.ExportingMenu.new(root, {})
	});

	// The annotations tool
	var annotator = am5plugins_exporting.Annotator.new(root, {});
	var menuitems = exporting.get("menu").get("items");

	menuitems.push({
		type: "separator"
	});

	menuitems.push({
		type: "custom",
		label: "Annotate",
		callback: function() {
			this.close();
			annotator.toggle();
		}
	});


	chart.zoomOutButton.disabled = true;  // Disable zoom out button
}


//
// -- Proceed with the chart creation once the DOM is fully loaded

am5.ready(function() {

	if ( chart_data !== undefined ) {

		// Read metadata info
		getauxinfo();

		// Let p_select do all the jobs
		p_select();


		// Highlight button for current model
		if ( aux.NEpochs > 1 )
			document.getElementById('p_selector').value = c_imod;

	} else {
		for (var j = 0; j < 2 * Math.PI; j += 0.1)
			my_chartdata.push({"lambda": parseInt(1000 + j*1500), "y": Math.sin(j)});

	}


	// The residuals legend is created only once
	createResidLegend();

	// Appearance settings
	chart.appear(1000,200);

});  // end am5.ready()



//
// -- Set initial X range

function set_init_x_range() {
	var x_min, x_max;

	if ( aux.modinfo[c_imod].x_range ) {  // User defined X range
		console.log('set_init_x_range: Set x_range:', aux.modinfo[c_imod].x_range);
		x_min = aux.modinfo[c_imod].x_range[0];
		x_max = aux.modinfo[c_imod].x_range[1];
	} else {
		x_min = aux.modinfo[c_imod].x_min;
		x_max = aux.modinfo[c_imod].x_max;
		console.log('set_init_x_range: X range set to:', x_min, x_max);
	}

	x_range.min = x_min;
	x_range.max = x_max;
	log_label_ckeck('x');

	inxy_ranges.xmin.value = x_min;
	inxy_ranges.xmax.value = x_max;

	if ( aux.modinfo[c_imod].x_log ) {  // User requested X log scale
		console.log('Set x_log:', aux.modinfo[c_imod].x_log);
		document.getElementById('x_log-cb').checked = true;
		x_linlog_toggle();
	} else
		x_linlog_toggle(true);

	vxAxis.setAll({'start': 0, 'end': 1, 'min': x_min, 'max': x_max})

}  // end set_init_x_range


//
// -- Set initial Y data range

function set_init_y_range() {
	var y_min, y_max;

	// Main Y axis range
	if ( aux.modinfo[c_imod].y_range ) {  // User defined Y range
		console.log('set_init_y_range: set y_range from aux:', aux.modinfo[c_imod].y_range);
		y_min = aux.modinfo[c_imod].y_range[0];
		y_max = aux.modinfo[c_imod].y_range[1];
	} else {
		y_min = aux.modinfo[c_imod].y_min;
		y_max = aux.modinfo[c_imod].y_max;
		console.log('set_init_y_range: Y range set to:', y_min, y_max);
	}
	y_range.min = y_min;
	y_range.max = y_max;
	log_label_ckeck('y');

	if ( aux.modinfo[c_imod].y_log ) {  // User requested Y log scale
		console.log('Set y_log:', aux.modinfo[c_imod].y_log);
		document.getElementById('y_log-cb').checked = true;
		y_linlog_toggle();
	} else
		y_linlog_toggle(true);

	valueAxis.setAll({'start': 0, 'end': 1, 'min': y_min, 'max': y_max});

	// Residuals axis range
	resyAxis.setAll({'start': 0, 'end': 1, 'min': -n_sigma - 1, 'max': n_sigma + 1});

	if ( resid_plot ) {
		inxy_ranges.ymin.value = (-n_sigma - 1).toPrecision(4);
		inxy_ranges.ymax.value = (n_sigma + 1).toPrecision(4);
	} else {
		inxy_ranges.ymin.value = y_min.toPrecision(4);
		inxy_ranges.ymax.value = y_max.toPrecision(4);
	}

}  // end set_init_y_range


//
// -- Toggle logarithmic X / Y label color

function log_label_ckeck(axis='x') {
	var xl = document.getElementById('x_log-lab'),
		yl = document.getElementById('y_log-lab');

	if ( axis.indexOf('x') >= 0 ) {
		if ( x_range.min <= 0 )
			xl.style.color = 'var(--secondary)';
		else
			xl.style.color = '';
	} else if ( axis.indexOf('y') >= 0 ) {
		if ( y_range.min <= 0 )
			yl.style.color = 'var(--secondary)';
		else
			yl.style.color = '';
	}

}  // end log_label_ckeck


//
// -- Toggle linear / logarithmic X / Y scale

function x_linlog_toggle(lin_reset=false) {
	x_range.logscale = document.getElementById('x_log-cb').checked;

	if ( x_range.logscale  && lin_reset ) {
		document.getElementById('x_log-cb').checked = false;
		vxAxis.set('logarithmic', false);
		x_range.logscale = false;
		return;
	}

	// From lin to log
	if ( x_range.logscale ) {
		if ( x_range.min <= 0 ) {  // TODO
			x_linlog_toggle(true);
			return;
        }
		vxAxis.set('logarithmic', true);
	} else {  // From log to lin
		vxAxis.set('logarithmic', false);
	}

	vxAxis.setAll({'min': x_range.min, 'max': x_range.max, 'start': 0, 'end': 1});
	console.log('x_linlog_toggle: X range reset to:', x_range.min, x_range.max);

}  // end x_linlog_toggle


// -- Toggle Y axis logarithmic scale; disabled for residuals plot

function y_linlog_toggle(lin_reset=false) {
	y_range.logscale = document.getElementById('y_log-cb').checked;

	if ( y_range.logscale && (resyAxis.isVisible() || lin_reset) ) {
		document.getElementById('y_log-cb').checked = false;
		valueAxis.set('logarithmic', false);
		y_range.logscale = false;
		if ( lin_reset )
			return;
	}
	if ( resyAxis.isVisible() )
		return;

	// From lin to log
	if ( y_range.logscale ) {
		if ( y_range.min <= 0 ) {  // TODO
			y_linlog_toggle(true);
			return;
		}
		valueAxis.set('logarithmic', true);
	} else {  // From log to lin
		valueAxis.set('logarithmic', false);
	}

	valueAxis.setAll({'min': y_range.min, 'max': y_range.max, 'start': 0, 'end': 1});
	console.log('y_linlog_toggle: Y range reset to:', y_range.min, y_range.max);

}  // end y_linlog_toggle


//
// -- Set X plot range to fixed range

function inx_range_set() {
	// Note: need to parse to Float. It also requires "0.nnn" and not ".nnn"
	var x_size = vxAxis.get('max') - vxAxis.get('min');
	if ( x_size <= 0 )
		x_size = aux.modinfo[c_imod].x_step;

	var x_min = inxy_ranges.xmin.value !== '' ? parseFloat(inxy_ranges.xmin.value) : vxAxis.get('min');
	var x_max = inxy_ranges.xmax.value !== '' ? parseFloat(inxy_ranges.xmax.value) : vxAxis.get('max');

	// Order check
	if ( x_min > x_max ) {
		var tmp = x_max;
		x_max = x_min;
		x_min = tmp;
	} else if ( x_min == x_max )
		x_max = x_min + aux.modinfo[c_imod].x_step;

	x_range.min = +x_min.toPrecision(4);
	x_range.max = +x_max.toPrecision(4);
	log_label_ckeck('x');

	if ( x_range.logscale && x_range.min <= 0 )
		return;

	vxAxis.setAll({'min': x_min, 'max': x_max, 'start': 0, 'end': 1});
	console.log('inx_range_set: requested X range:', x_min, x_max);

}  // end inx_range_set


//
// -- Set the Y plot range to fixed range

function iny_range_set() {
	// Note: need to parse to Float. It also requires "0.nnn" and not ".nnn"

	var y_min, y_max;
	if ( resyAxis.isVisible() ) {
		y_min = inxy_ranges.ymin.value !== '' ? parseFloat(inxy_ranges.ymin.value) : resyAxis.get('min');
		y_max = inxy_ranges.ymax.value !== '' ? parseFloat(inxy_ranges.ymax.value) : resyAxis.get('max');
	} else {
		y_min = inxy_ranges.ymin.value !== '' ? parseFloat(inxy_ranges.ymin.value) : valueAxis.get('min');
		y_max = inxy_ranges.ymax.value !== '' ? parseFloat(inxy_ranges.ymax.value) : valueAxis.get('max');
	}

	// Order check
	if ( y_min > y_max ) {
        var tmp = y_max;
        y_max = y_min;
        y_min = tmp;
	} else if ( y_min == y_max )
        return false;

	y_range.min = +y_min.toPrecision(4);
	y_range.max = +y_max.toPrecision(4);
	log_label_ckeck('y');

	if ( y_range.logscale && y_range.min <= 0 )
		return;

	if ( resyAxis.isVisible() ) {
		resyAxis.setAll({'min': y_min, 'max': y_max, 'start': 0, 'end': 1});
	} else {
		valueAxis.setAll({'min': y_min, 'max': y_max, 'start': 0, 'end': 1});
	}
	console.log('iny_range_set: requested Y range:', y_min, y_max);

}  // end iny_range_set


//
// -- Show/hide the components / models / extra log tables

function gfit_table_toggle(id) {
	var   divid = id +'-div',
		e = document.getElementById(divid),
		sdiv = document.getElementById('fitlog_selector'),  // Selector divs
		tdiv = document.getElementById('fitlog_tables'),    // Table divs
		i = 0;

	while (tdiv.childNodes[i]) {
		if ( tdiv.childNodes[i].id !== divid || ! isHidden(e) ) {
			tdiv.childNodes[i].className = 'div-hide';
			sdiv.childNodes[i].className = 'toggle_table-hdr';
			sdiv.childNodes[i].childNodes[0].className = 'div-show-inline';
			sdiv.childNodes[i].childNodes[1].className = 'div-hide';
		} else {
			tdiv.childNodes[i].className = 'out_table rep_div-show';
			//sdiv.scrollIntoView();
			sdiv.childNodes[i].className = 'toggle_table-hdr div-selected';
			sdiv.childNodes[i].childNodes[0].className = 'div-hide';
			sdiv.childNodes[i].childNodes[1].className = 'div-show-inline';
		}
		i++;
	}

}  // end gfit_table_toggle


//
// -- Display input JSON formatted fit results in table format
// -- Params:
//    obj:    the json object
//    type:   0=Model components + parameters, 1=fit_results, 2=extra
//    tab_id: the (html div) id to give to the created table.
//	      For extra tables this is just an integer ith table id.

var tableFromJson = function(obj, type, tab_id) {
	if ( type !== 2 && (obj == undefined || obj.show == undefined) )
		return;

	var tlab = document.createElement('div'),
		contentdiv, comp, cname, title;

	// Define component/evaluations reference object and header from type

	if ( type !== 2 )
		comp = stripansi(obj.show);

	//console.log(comp);

	contentdiv = document.createElement('div');

	switch (type) {  // Model
    case 0:
		title = '<div id="'+ tab_id +'_angle_down" class="div-hide"><svg class="icon-angle" width="12" height="18"><use href="#angle-down"></use></svg></div>'+
			'<div id="'+ tab_id +'_angle_up" class="div-show-inline"><svg class="icon-angle" width="12" height="18"><use href="#angle-up"></use></svg></div>'+
			'<span class="ud-angle-l">Model</span>';
		tlab.setAttribute('id', tab_id +'_sect');
		tlab.setAttribute('class', 'toggle_table-hdr div-selected');
		tlab.setAttribute('onclick', "gfit_table_toggle('"+ tab_id +"')");

		var div = document.createElement('div');
		var pre = document.createElement('pre');
		pre.setAttribute('class', 'pre_res');

		var cs = comp.split('\n');
		cs[0] = '<span style="color: var(--green)">'+ cs[0] +'</span>';
		cp = cs[2].split('│');

		for (var i = 0; i < cp.length; i++)
			cp[i] = '<span style="color: var(--light); background-color: var(--dark);">'+ cp[i] +'</span>';
		cs[2] = cp.join('│');
		var ips = cs.indexOf('Parameters:');
		cs[ips] = '<span style="color: var(--green)">'+ cs[ips] +'</span>';
		cp = cs[ips+2].split('│');
		for (var i = 0; i < cp.length; i++)
			cp[i] = '<span style="color: var(--light); background-color: var(--dark);">'+ cp[i] +'</span>';
		cs[ips+2] = cp.join('│');

		comp = cs.join('\n');
		pre.innerHTML = comp;
		div.appendChild(pre);
		contentdiv.appendChild(div);

		tlab.innerHTML = title;

		// Create a table with its id
		tabdiv = document.createElement('div');
		tabdiv.appendChild(tlab);
		tabdiv.appendChild(contentdiv);

		break;

    case 1:
		// The summary table
		var div = document.createElement('div');
		div.setAttribute('class', 'summ-div');
		div.setAttribute('id', 'summ-div');

		var cs = comp.split('\n');
		cs[0] = '<span style="color: var(--green)">'+ cs[0] +'</span>';
		comp = cs.join('\n');
		comp = comp.replace(/OK/i, '<span style="color: var(--green)">OK</span>');

		var pre = document.createElement('pre');
		pre.setAttribute('class', 'pre_res_bf');
		pre.innerHTML = comp;
		div.appendChild(pre);
		contentdiv.appendChild(div);

		break;

    case 2:  // Extra tables
		//comp = obj.show;
		comp = obj["+"];
		tab_id = 'extra_table'+ tab_id;  // Must be unique

		title = '<div id="'+ tab_id +'_angle_down" class="div-show-inline"><svg class="icon-angle" width="12" height="18"><use href="#angle-down"></use></svg></div>'+
			'<div id="'+ tab_id +'_angle_up" class="div-hide"><svg class="icon-angle" width="12" height="18"><use href="#angle-up"></use></svg></div>'+
			'<span class="ud-angle-l">'+ comp.label +'</span>';

		tlab.setAttribute('id', tab_id +'_sect');
		tlab.setAttribute('class', 'toggle_table-hdr');
		tlab.setAttribute('onclick', "gfit_table_toggle('"+ tab_id +"')");

		tlab.innerHTML = title;

		var div = document.createElement('div');
		tab = document.createElement('table');
		div.appendChild(tab);

		// Create table header row using the field names
		hdr = tab.createTHead();
		tr = hdr.insertRow(0);

		for (var i = 0; i < comp.fields.length; i++) {
			var th = document.createElement('th');
			th.innerHTML = comp.fields[i]["+"].label
			tr.appendChild(th);
		}

		// Table body
		tb = tab.appendChild(document.createElement('tbody'));
		var nc = comp.fields[0]["+"].data.length;  // Number of rows

		for (var i = 0; i < nc; i++) {
			tr = tb.insertRow(-1);

			for (var j = 0; j < comp.fields.length; j++) {
				tabCell = tr.insertCell(-1);
				tabCell.innerHTML = comp.fields[j]["+"].data[i];
			}
		}
		contentdiv.appendChild(div);

		break;

    default:
		console.log(`Sorry, option not recognised: ${type}.`);
	}


	if ( tab_id !== undefined )
		contentdiv.setAttribute('id', tab_id +'-div');

	if ( type == 2 )  // Extra tables hidden by default
		contentdiv.setAttribute('class', 'div-hide');
	else
		contentdiv.setAttribute('class', 'out_table rep_div-show');

	// Selector label and table returned separately
	return {"selector": tlab, "table": contentdiv};

}  // end tableFromJson


//
// -- The fit log tables section

function createFitLogTabs() {
	var tab_extra = [];	// Additional GModelFit provided summary tables
	var n_extratab = 0;
	var divSelectData = document.getElementById('fitlog_selector');
	var divShowData = document.getElementById('fitlog_tables');
	var divFitRes = document.getElementById('fitres-div');
	var tabdiv;

	divSelectData.innerHTML = '';
	divShowData.innerHTML = '';
	divFitRes.innerHTML = '';

	var p = getModels(chart_data, c_imod);
	if ( chart_data['+'].extra !== undefined )
		tab_extra.push(chart_data['+'].extra[c_imod]);
	else
		tab_extra.push({});

	tabdiv = tableFromJson(p, 0, 'comp_table');

	divSelectData.appendChild(tabdiv.selector);  // Add the components + evaluations table to the container
	divShowData.appendChild(tabdiv.table);


	// Extra tables in a separate div, if they exist for the current evaluations.
	if ( tab_extra[0] !== undefined ) {
		n_extratab = Object.keys(tab_extra[0]).length;  // TODO: replace [0] with epoch
		console.log('There are '+ n_extratab +' extra tables.');

		var extratabs = Object.keys(tab_extra[0]);
		for (var i = 0; i < n_extratab; i++) {
			tabdiv = tableFromJson(tab_extra[0][extratabs[i]], 2, i);
			if ( i == 0 )
				tabdiv.selector.style.borderLeft = '3px solid #ccc';
			divSelectData.appendChild(tabdiv.selector);  // Add the extra table to the container
			divShowData.appendChild(tabdiv.table);
		}
		//divShowData.appendChild(divShowExtra);
	} //else
	//divShowExtra.classList.add('div-hide');

	if ( chart_data['+'].fitsummary !== undefined ) {
		tabdiv = tableFromJson(chart_data['+'].fitsummary['+'], 1, 'fitres_table');

		if ( tabdiv !== undefined )
			divFitRes.appendChild(tabdiv.table);
	}

}  // end createFitLogTabs
