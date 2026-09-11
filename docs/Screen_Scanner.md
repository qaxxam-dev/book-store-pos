# Screen: Scanner

## Purpose
The **Scanner Screen** provides a camera interface for scanning barcodes. It supports both single-scan and continuous-scan modes.

## Widgets

- **Camera Preview**: Full-screen camera view using `mobile_scanner`.
- **Overlay Guide**: A box frame indicating the scan area.
- **Instruction Text**: Displays mode specific instructions ("Scan a barcode" or "Continuous Mode").
- **AppBar Actions**: "Done" button (only in Continuous mode) to return to the previous screen.

## Logic & Debounce
- **Debounce**: Prevents duplicate scans of the same barcode within a 2-second window.
- **Continuous Mode**: Keeps the camera open to scan multiple items sequentially.
- **Single Mode**: Returns the result immediately after the first successful scan.

## Interactions

- **Scan**: Auto-detects barcode when in frame.
- **Done**: Manually close the scanner (Continuous mode).

## Screenshots
![SCREENSHOT: Barcode scanner camera view]()
