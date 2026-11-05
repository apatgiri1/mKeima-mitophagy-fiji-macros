// mKeima_counter_v6_Auto.ijm
//
// Minimal-diff automation wrapper around mKeima_counter_AP.ijm (g.ball@dundee.ac.uk,
// Dundee Imaging Facility, October 2019, Creative Commons CC-BY-SA).
//
// WHAT THIS VERSION CHANGES, AND NOTHING ELSE:
//   1. "Batch Mode?" defaults to checked (true), since the intended use is
//      running unattended over a folder of .tif images that already have
//      cell ROIs saved as overlays.
//   2. The final results CSV is written DIRECTLY into the same folder as the
//      input .tif images (with a timestamp in the filename so repeat runs
//      never overwrite each other), instead of the nested
//      "Results_mQC_counter_<timestamp>" subfolder the original macro used.
//
// WHAT THIS VERSION DOES NOT CHANGE (confirmed identical to
// mKeima_counter_AP.ijm):
//   - Spot detection: still Find Maxima on the ratio (red/green) image,
//     followed by pixel-by-pixel filtering of the found points against the
//     red channel threshold. No mask-based Analyze Particles step.
//   - Thresholding: still the original's per-image ADAPTIVE thresholds --
//     redThresh = mean + (redThreshNstd * std) of that image's red channel,
//     and ratioThresh added to that image's own mean ratio. No fixed/
//     calibrated threshold constants of any kind.
//   - No nuclear (DAPI) masking or exclusion step of any kind -- this macro
//     is still 2-channel (green/red) only, exactly as the original.
//   - All Results columns, the mitophagyMask overlay/visualization image,
//     and the annotated QC image outputs (_ratio.tif, _mitophagyMask.tif,
//     _rois.tif) are saved exactly as in the original, to the same
//     "Results_mQC_counter_<timestamp>" subfolder as before.
//
// Usage:
//   1. Save cell ROIs as image overlays on each .tif (unchanged requirement).
//   2. Run this macro, confirm parameters in the dialog, choose the folder.
//   3. A timestamped CSV appears directly in that folder; annotated QC
//      images (unchanged from the original) appear in a
//      Results_mQC_counter_<timestamp> subfolder as before.

// parameters (identical to mKeima_counter_AP.ijm)
doBatch = true;   // <-- only change: defaults to true for unattended batch use
grnCh = 1;  // channel for mKeima green
redCh = 2;  // channel for mKeima red
smoothRad = 1.0;  // radius for input image filtering
ratioThresh = 0.5;  // threshold (tolerance) for ratio channel peak-finding
redThreshNstd = 0;  // red channel intensity threshold: number of stdDev above mean


// --- start Macro ---

// 1. dialog to select options & update parameters
Dialog.create("mKeima_counter_v6_Auto");
Dialog.addCheckbox("Batch Mode?", doBatch);
Dialog.addNumber("Green channel", grnCh);
Dialog.addNumber("Red channel", redCh);
Dialog.addNumber("Radius for smoothing images (0=none)", smoothRad);
Dialog.addNumber("Ratio threshold (tolerance)", ratioThresh);
Dialog.addNumber("Red channel thresh: stdDev above mean", redThreshNstd);
Dialog.show();
doBatch = Dialog.getCheckbox();
grnCh = Dialog.getNumber();
redCh = Dialog.getNumber();
smoothRad = Dialog.getNumber();
ratioThresh = Dialog.getNumber();
redThreshNstd = Dialog.getNumber();


// 2. for batch mode: get input folder, build list of files, and make output folder
// (output folder is still used for the annotated QC images, exactly as in the
// original; the results CSV itself is redirected to inputFolder in Section 4 below)
if (doBatch) {
	inputFolder = getDirectory("Choose a folder containing ImageJ .tif images with cell ROI overlay");
	files = getFileList(inputFolder);
	images = selectEnding(files, ".tif");
	outputFolder = inputFolder + "Results_mQC_counter_" + timeStamp();
	print("Saving annotated QC images in: " + outputFolder);
	File.makeDirectory(outputFolder);
	numberOfImages = images.length;
} else {
	numberOfImages = minOf(1, nImages);  // just analyze 1st active image in single-image mode
	if (numberOfImages < 1 || roiManager("count") < 1) {
		exit("Open image & cell ROIs in ROI manager required for single-image mode");
	}
}


// --- 3. Start Iteration over images (unchanged from mKeima_counter_AP.ijm) ---
showProgress(0);
run("Clear Results");
row = 0;  // row in Results table
for (imageNo = 0; imageNo < numberOfImages; imageNo++) {
	setBatchMode(true);

	// 3a. open next image and prep for analysis
	if (doBatch) {
		filepath = inputFolder + File.separator + images[imageNo];
		open(filepath);
		nRois = Overlay.size;
		if (nRois > 0) {
			run("To ROI Manager");
		} else {
			print("warning: " + images[imageNo] + " has no cell ROIs - skipping");
		}
		run("Select None");
		imageTitle = getTitle();

	} else {
		nRois = roiManager("count");
		run("Select None");
		imageTitle = getTitle();
		run("Duplicate...", "duplicate");  // do not modify original stack
	}
	stackID = getImageID();
	Stack.getDimensions(width, height, nc, nz, nt);
	if (nc > 3 || nc < 2) {
		exit("Macro only works for 2 or 3 channel input images!");
	}
	originalBitDepth = bitDepth();
	// pre-filter to reduce effect of noise on ratio values
	run("Median...", "radius=" + smoothRad + " stack");

	// 3b. calculate ratio image
	selectImage(stackID);
	Stack.setChannel(grnCh);
	run("Duplicate...", " ");
	getStatistics(area, mean, min, max, std);
	run("Subtract...", "value=" + (min - 1));  // i.e. new min = 1
	run("32-bit");
	run("Divide...", "value=" + (max - min + 1));
	rename("grnNormalized");
	selectImage(stackID);
	Stack.setChannel(redCh);
	run("Duplicate...", " ");
	getStatistics(area, mean, min, maxR, std);
	redThresh = mean + (redThreshNstd * std);  // red channel intens. threshold
	run("Subtract...", "value=" + min);  // i.e. new min = 0
	run("32-bit");
	run("Divide...", "value=" + (max - min));
	rename("redNormalized");
	imageCalculator("Divide create 32-bit", "redNormalized", "grnNormalized");
	rename(imageTitle + "_Ratio_Red/Green");
	ratioID = getImageID();
	selectWindow("grnNormalized");
	close();
	selectWindow("redNormalized");
	close();

	// 3c. generate mitophagy mask channel by combining thresholded ratio and red channels
	selectImage(ratioID);
	run("Duplicate...", "title=ratioMask");
	getRawStatistics(nPixels, meanRatio, min, maxRatio, std);
	setThreshold(meanRatio+ratioThresh, maxRatio);  // add background mean ratio to peak-finding threshold
	run("Convert to Mask");
	ratioMaskID = getImageID();
	selectImage(stackID);
	run("Duplicate...", "title=redMask duplicate channels="+redCh);
	setThreshold(redThresh, maxR);
	run("Convert to Mask");
	redMaskID = getImageID();
	imageCalculator("AND create", "ratioMask","redMask");
	run("" + originalBitDepth + "-bit");
	rename("mitophagyMask");
	selectImage(redMaskID);
	close();
	selectImage(ratioMaskID);
	close();
	selectImage(stackID);
	rename("mQC_count");
	run("Split Channels");
	if (nc == 2) {
		C1name = "C1-mQC_count";
		C2name = "C2-mQC_count";
		C3name = "mitophagyMask";
		run("Merge Channels...", "c1=[" + C1name + "] c2=[" + C2name + "] c3=[" + C3name + "] create");
	} else {
		C1name = "C1-mQC_count";
		C2name = "C2-mQC_count";
		C3name = "C3-mQC_count";
		C4name = "mitophagyMask";
		run("Merge Channels...", "c1=[" + C1name + "] c2=[" + C2name + "] c3=[" + C3name + "] c4=[" + C4name + "] create");
	}
	rename(imageTitle + "_mQC_count");
	stackID = getImageID();
	mitoChannel = nc+1;
	Stack.setChannel(mitoChannel);
	setMinAndMax(0,512);  // set display so overlaid mitophagy mask values 255 not too bright

	// 3d. find & count spots, measure selection areas
	areas = newArray(nRois);
	nSpots = newArray(nRois);
	grnMeans = newArray(nRois);
	redMeans = newArray(nRois);
	mitoAreas = newArray(nRois);
	nPts = 0;  // number of multi-point ROIs we find (some cells may have no points!)
	for (r = 0; r < nRois; r++) {
		selectImage(stackID);
		roiManager("select", r);

		Stack.setChannel(grnCh);
		getRawStatistics(nPixels, meanG, min, max, std);
		grnMeans[r] = meanG;

		Stack.setChannel(redCh);
		getRawStatistics(nPixels, meanR, min, max, std);
		redMeans[r] = meanR;

		Stack.setChannel(mitoChannel);
		getStatistics(areaCell, meanMito, min, max, std);
		areas[r] = areaCell;
		mitoAreas[r] = areaCell * meanMito / 255;

		addRoiToImage(r, stackID);  // add cell outline to overlay
		selectImage(ratioID);
		roiManager("select", r);
		run("Find Maxima...", "noise=" + ratioThresh + " output=[Point Selection]");
		if (selectionType == 10) {
			getSelectionCoordinates(xc, yc);
			if (xc.length > 0) {
				selectImage(stackID);
				Stack.setChannel(redCh);
				nAboveThresh = 0;
				// iterate over points checking whether above redThresh
				for (p = 0; p < xc.length; p++) {
					if (getPixel(xc[p], yc[p]) >= redThresh) {
						xc[nAboveThresh] = xc[p];
						yc[nAboveThresh] = yc[p];
						nAboveThresh++;
					}
				}
				xc = Array.trim(xc, nAboveThresh);
				yc = Array.trim(yc, nAboveThresh);
				if (xc.length > 0) {
					makeSelection("point", xc, yc);
					ptRoiNum = roiManager("count") - 1;
					run("Add Selection...");
					nSpots[r] = xc.length;
				}
			}
		} else {
			// did not find any spots!
			nSpots[r] = 0;
		}
	}

	// 3e. update results
	Stack.getUnits(xu, yu, zu, tu, vu);
	for (r = 0; r < nRois; r++) {
		roiManager("select", r);
		Roi.getBounds(x, y, w, h);
		if (doBatch) {
			setResult("Image", row, images[imageNo]);
		} else {
			setResult("Image", row, imageTitle);
		}
		setResult("CellROI", row, Roi.getName());
		setResult("CellArea_" + xu + "2", row, areas[r]);
		setResult("greenMean", row, grnMeans[r]);
		setResult("redMean", row, redMeans[r]);
		setResult("RGratio", row, redMeans[r] / grnMeans[r]);
		setResult("nMitoLysosomes", row, nSpots[r]);
		setResult("nML_per_um2", row, nSpots[r] / areas[r]);
		setResult("nML_over_green", row, nSpots[r] / grnMeans[r]);
		setResult("MLtotalArea_" + xu + "2", row, mitoAreas[r]);
		setResult("MLpctArea", row, 100.0*mitoAreas[r]/areas[r]);
		setResult("MLmeanArea_" + xu + "2", row, mitoAreas[r]/nSpots[r]);
		setResult("MLarea_"+ xu + "2" + "_over_green", row, mitoAreas[r] / grnMeans[r]);
		setResult("X_tl", row, "" + x);
		setResult("Y_tl", row, "" + y);
		setResult("ratioThresh", row, ratioThresh);
		setResult("redThresh", row, redThresh);
		setResult("smoothRad", row, smoothRad);
		row++;
	}
	updateResults();

	// 3f. prepare/save annotated images (unchanged: still saved to the
	// Results_mQC_counter_<timestamp> subfolder, not the input folder root)
	selectImage(ratioID);
	run("Select None");
	run("Enhance Contrast", "saturated=0.35");
	run("Grays");
	if (doBatch) {
		baseOutputPath = outputFolder + File.separator + baseName(images[imageNo]);
		saveAs("Tiff", baseOutputPath + "_ratio.tif");
		close();  // ratio image
		selectImage(stackID);
		run("Select None");
		Stack.setChannel(mitoChannel);
		run("Duplicate...", " ");
		setMinAndMax(0,255);
		run("Remove Overlay");
		saveAs("Tiff",  baseOutputPath + "_mitophagyMask.tif");
		close();  // mitophagy mask
		selectImage(stackID);
		Stack.setChannel(mitoChannel);
		run("Delete Slice", "delete=channel");  // remove mitophagy mask from RGB snapshot
		run("Stack to RGB");
		saveAs("Tiff",  baseOutputPath + "_rois.tif");
		close();  // RGB
		close();  // stack
	}
}


// 4. Prepare/save Results -- ONLY CHANGE FROM THE ORIGINAL: saved directly
//    into inputFolder (the same folder as the input images), with a
//    timestamp so repeat runs don't overwrite each other, instead of the
//    original's Results_mQC_counter_<timestamp> subfolder.
paramString = "_grnCh" + grnCh + "_redCh" + redCh;
resultName = "Results_mKeima_v6_Auto_" + timeStamp() + paramString + ".csv";
IJ.renameResults(resultName);
if (doBatch) {
	run("Input/Output...", "jpeg=85 gif=-1 file=.csv copy_column save_column");  // configure output
	saveAs("Results", inputFolder + File.separator + resultName);
	print("Saved results CSV: " + inputFolder + File.separator + resultName);
}

setBatchMode("exit and display");


// --- function definitions (unchanged) ---

function selectEnding(files, ending) {
	// for an array of file names, return a new array of those with specified ending
	withEnding = newArray(0);
	for (i=0; i < files.length; i++) {
		file = files[i];
		if (endsWith(file, ending)) {
			f = newArray(1);
			f[0] = file;
			withEnding = Array.concat(withEnding, f);
		}
	}
	return withEnding;
}

function timeStamp() {
	// generate a time stamp string
	// requires: twoDigit()
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	timeString = toString(year) + "-" + twoDigit(month) + "-" + twoDigit(dayOfMonth);
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	timeString = timeString + "_" + DayNames[dayOfWeek];
	timeString = timeString + twoDigit(hour) + "-" + twoDigit(minute) + "-" + twoDigit(second);
	return timeString;
}

function twoDigit(n) {
	// return two-digit version of number (0-padded)
	return IJ.pad(n, 2);
}

function addRoiToImage(roiNum, imageID) {
	// add ROI to the specified image's overlay
	startingID = getImageID();
	selectImage(imageID);
	roiManager("select", roiNum);
	Overlay.addSelection();
	selectImage(startingID);
}

function baseName(filename) {
	// return filename string without extension
	return substring(filename, 0, lastIndexOf(filename, "."));
}
