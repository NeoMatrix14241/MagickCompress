# Image Compression PowerShell Script

**⚡ Fast Image Compression Tool - Designed for Batch Processing**

### 🚀 Batch Folder Processing

This PowerShell script automates image compression for batches of files, optimizing storage while maintaining quality.

---
### Dependencies for MagickCompress

The PowerShell script requires the following software:

1. **[ImageMagick](https://imagemagick.org)**  
   - Version: ImageMagick-7.1.1-43-Q16-HDRI-x64-dll.exe  

2. **[PowerShell 7](https://github.com/PowerShell/PowerShell) [For Multithreading Support]**
   - Version: PowerShell-7.4.6-win-x64.msi

---
### 📂 Folder Structure
When executed, `start_process.bat` will create the following folders:

- **input** – Place folders containing image files here for batch compression
- **archive** – Processed folders from `input` are moved here after compression
- **output** – Compressed image files are saved here
- **logs** – All process logs are stored here

---
## 🛠️ Setup & Installation Instructions

1. Download and extract MagickCompress zip file contents

2. Navigate to the `setup` folder and run "setup.bat"

3. Run `start_process.bat` to set up the necessary folders

---
## ⚙️ Folder Structure & Naming

❌❌❌ **Avoid This Structure:**
```
input
   ├── folder1
   │    ├── image1.jpg ★
   │    ├── image2.png ★
   │    ├── subfolder1 <!>
   │    │    ├── image1.jpg
   │    │    └── image2.png
   │    ├── subfolder2
   │    │    ├── image1.jpg
   │    │    └── image2.png
```
- **Issue:** Files at the root of `folder1` (★) will interrupt processing of subfolders (<!>)
- **Solution:** Ensure image files are inside subfolders

✔️✔️✔️ **Proper Folder Structure:**
```
input
   ├── folder1
   │    ├── subfolder1 ★
   │    │    ├── image1.jpg
   │    │    └── image2.png
   │    ├── subfolder2 ★
   │    │    ├── image1.jpg
   │    │    └── image2.png
   └── folder2 ★
        ├── image1.jpg
        └── image2.png
```
- **Output Structure:** Compressed files maintain original names and folder structure
- **Example:** `subfolder1/image1.jpg` → `output/subfolder1/image1.jpg`

---
## ▶️ Usage Instructions

1. Place folders containing image files into the `input` directory
   ```
   Supported Image Extensions/Types:
   .bmp   .jpeg   .gif   .png
   .dib   .jpe    .tif   .heic
   .jpg   .jiff   .tiff
   ```
2. Run `start_process.bat` and wait for compression to complete
3. Compressed files will be saved in the `output` directory maintaining folder structure

---
## 📄 Output Structure

- **folder1/subfolder1/image1.jpg** → `output/subfolder1/image1.jpg`
- **folder1/subfolder2/image2.png** → `output/subfolder2/image2.png`
- **folder2/image1.jpg** → `output/folder2/image1.jpg`
