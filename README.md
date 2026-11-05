# mito-mKeima FIJI analysis macros

Fiji (ImageJ) macros for quantifying mitolysosomes in live-cell mito-mKeima confocal images. These macros accompany the STAR Protocols article *Protocol to quantify mitophagy in mammalian cells using mito-mKeima and live-cell confocal microscopy* (Yadav et al., [citation and DOI to be added upon publication]).

## Contents

| File | Purpose |
|---|---|
| `mKeima_nd2_to_tif_batch.ijm` | Macro 1. Batch converts Nikon ND2 files to composite TIFF files and removes the brightfield channel. |
| `mKeima_counter_Batch_Auto.ijm` | Macro 2. Counts mitolysosomes within user-defined single-cell ROIs and writes a results table. |

## Requirements

- Fiji (Schindelin et al., 2012; https://fiji.sc), ImageJ2 version 2.16.0/1.54p or later. Bio-Formats (Linkert et al., 2010), which Macro 1 uses to read the ND2 files, is included with Fiji.
- Nikon ND2 images with the following channel order: channel 1, mKeima green; channel 2, mKeima red; channel 3 (optional), Hoechst; channel 4 (optional), brightfield.

## Workflow

1. **Convert (Macro 1).** In Fiji, select Plugins > Macros > Run, choose `mKeima_nd2_to_tif_batch.ijm`, and select the folder containing the ND2 files. Each file is saved as a composite TIFF with the same name in the same folder. Channel 4 and any higher channels are removed, and channels 1, 2, and 3 are assigned green, red, and blue lookup tables.
2. **Adjust display and outline cells (manual).** Open the TIFF files in Fiji, set brightness and contrast with Image > Adjust > Brightness/Contrast, and use Set > Propagate to all other open images. **Never use Apply**, because it alters the raw pixel values used for quantification. Outline each cell, add it to the ROI Manager (press `t`), and save the image so that the ROIs are stored as an overlay. Outline only cells that lie entirely within the frame and show green fluorescence, and do not outline any region twice.
3. **Count (Macro 2).** Select Plugins > Macros > Run, choose `mKeima_counter_Batch_Auto.ijm`, confirm that Batch Mode is selected, keep the default parameters, and select the folder containing the ROI-annotated TIFF files.
4. **Analyze.** Use the `nMitoLysosomes` column of the results table. Average the cells within each biological replicate and use the replicate means for statistics. Individual cells are technical replicates. Present the data as SuperPlots (Lord et al., 2020).

## Macro 2 parameters (defaults)

| Parameter | Default | Description |
|---|---|---|
| Batch Mode | on | Process all `.tif` files in the selected folder |
| Green channel | 1 | mKeima green channel |
| Red channel | 2 | mKeima red channel |
| Radius for smoothing | 1.0 | Median filter radius (0 for none) |
| Ratio threshold (tolerance) | 0.5 | Noise tolerance for peak finding on the red/green ratio image |
| Red channel threshold | 0 | Standard deviations above the image red mean |

## Method summary

For each image, Macro 2 (adapted from the mito-QC Counter; Montava-Garriga et al., 2020) applies a median filter, generates a normalized red/green ratio image, and detects ratio maxima (Find Maxima) within each cell ROI. A maximum is counted as a mitolysosome only if its red intensity is at or above the red threshold of that image. Thresholds are calculated for each image, and no fixed intensity cutoffs are used. Images without ROIs are skipped, and a warning is printed in the Log window. Macro 2 accepts 2 or 3 channel images.

## Outputs

- `Results_mKeima_Batch_Auto_[timestamp]_grnCh1_redCh2.csv`, written to the image folder, with one row per cell. Columns include `Image`, `CellROI`, `CellArea`, `greenMean`, `redMean`, `RGratio`, `nMitoLysosomes`, `nML_per_um2`, `nML_over_green`, `MLtotalArea`, `MLpctArea`, `MLmeanArea`, and the thresholds and smoothing radius used.
- `Results_mQC_counter_[timestamp]/`, a subfolder with annotated QC images for each input image (`_ratio.tif`, `_mitophagyMask.tif`, `_rois.tif`). Inspect these to confirm correct detection.

## Attribution and license

`mKeima_counter_Batch_Auto.ijm` is a derivative of the mito-QC Counter macro written by Graeme Ball (g.ball@dundee.ac.uk, Dundee Imaging Facility, University of Dundee, October 2019), released under Creative Commons Attribution-ShareAlike (CC BY-SA). In accordance with that license, this repository is distributed under **CC BY-SA 4.0** (https://creativecommons.org/licenses/by-sa/4.0/).

## References

- Montava-Garriga, L., Singh, F., Ball, G., and Ganley, I.G. (2020). Semi-automated quantitation of mitophagy in cells and tissues. Mech. Ageing Dev. 185, 111196. [PMID 31843465](https://pubmed.ncbi.nlm.nih.gov/31843465/)
- Schindelin, J., et al. (2012). Fiji: an open-source platform for biological-image analysis. Nat. Methods 9, 676-682. [PMID 22743772](https://pubmed.ncbi.nlm.nih.gov/22743772/)
- Linkert, M., et al. (2010). Metadata matters: access to image data in the real world. J. Cell Biol. 189, 777-782. [PMID 20513764](https://pubmed.ncbi.nlm.nih.gov/20513764/)
- Lord, S.J., et al. (2020). SuperPlots: Communicating reproducibility and variability in cell biology. J. Cell Biol. 219, e202001064. [PMID 32346721](https://pubmed.ncbi.nlm.nih.gov/32346721/)

## Contact

Anupam Patgiri, Department of Pharmacology and Chemical Biology, Emory University School of Medicine (anupam.patgiri@emory.edu).
