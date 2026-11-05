// ============================================================
//  mKeima_nd2_to_tif_batch.ijm
//  Batch convert .nd2 mKeima images to composite .tif
//
//  For each .nd2 file in the selected folder:
//    Ch1 -> Green  (440 nm excitation)
//    Ch2 -> Red    (561 nm excitation)
//    Ch3 -> Blue   (additional channel, if present)
//    Ch4 -> REMOVED before saving
//    Composite projection: Sum
//    Active channels: 1, 2, 3
//
//  Output: same filename with .tif extension, saved in same folder
//  All .nd2 files are processed, including X.1.nd2 (e.g. ZOOM 1.1.nd2).
//
//  Usage: Plugins > Macros > Run, then select the Processed folder
// ============================================================


// Select input folder
inputFolder = getDirectory("Select the folder containing .nd2 files");
files = getFileList(inputFolder);
Array.sort(files);

// Build list of valid .nd2 files.
// All .nd2 files are included -- X.1.nd2 files (e.g. ZOOM 1.1.nd2) are
// legitimate acquisitions and are processed normally.
nd2Files = newArray(0);
for (i = 0; i < files.length; i++) {
    f = files[i];
    if (!endsWith(f, ".nd2")) continue;
    if (startsWith(f, "."))   continue;  // skip hidden/system files only
    nd2Files = Array.concat(nd2Files, f);
}

n = nd2Files.length;
if (n < 1) exit("No .nd2 files found in the selected folder.");

print("\\Clear");
print("=== mKeima nd2-to-tif Batch Converter ===");
print("Found " + n + " files in: " + inputFolder);

setBatchMode(true);

for (i = 0; i < n; i++) {
    fname    = nd2Files[i];
    baseName = replace(fname, ".nd2", "");
    outPath  = inputFolder + baseName + ".tif";

    print("(" + (i+1) + "/" + n + ") " + fname + "  -->  " + baseName + ".tif");

    // Open via Bio-Formats to preserve channel metadata
    run("Bio-Formats Importer",
        "open=[" + inputFolder + fname + "] " +
        "autoscale color_mode=Composite " +
        "view=Hyperstack stack_order=XYCZT");

    Stack.getDimensions(w, h, nc, nz, nt);

    // Remove Ch4 and any higher channels before doing anything else.
    // Delete from the top downward so indices do not shift mid-loop.
    if (nc >= 4) {
        for (ch = nc; ch >= 4; ch--) {
            Stack.setChannel(ch);
            run("Delete Slice", "delete=channel");
        }
        Stack.getDimensions(w, h, nc, nz, nt);  // refresh nc after deletion
        print("  Ch4+ removed. Channels remaining: " + nc);
    }

    // Apply channel colours
    Property.set("CompositeProjection", "null");
    Stack.setDisplayMode("color");
    Stack.setChannel(1); run("Green");
    Stack.setChannel(2); run("Red");
    if (nc >= 3) {
        Stack.setChannel(3); run("Blue");
    }

    // Switch to composite mode with Sum projection, all remaining channels active
    Property.set("CompositeProjection", "Sum");
    Stack.setDisplayMode("composite");
    if (nc == 3) {
        Stack.setActiveChannels("111");
    } else {
        Stack.setActiveChannels("11");
    }

    // Save as composite TIFF
    saveAs("Tiff", outPath);
    close();
}

setBatchMode("exit and display");
print("=== Done. " + n + " files converted. ===");
