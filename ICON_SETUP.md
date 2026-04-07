# BabySnap AI - Icon Setup Guide

## Quick Start

### Step 1: Generate Icon Files

You have two options:

#### Option A: Using the Flutter Widget (Recommended for Quick Start)

The app includes a `BabySnapAIIcon` widget that renders the icon design algorithmically. You can use this to generate PNG files:

1. **Export Icon as PNG** (Flutter screenshot method):
   ```bash
   # Run the app
   flutter run
   
   # Use device's screenshot to capture the splash screen icon
   # Or modify lib/presentation/screens/splash_screen.dart temporarily to export
   ```

2. **Alternative: Use a Custom Script**
   
   Create a dedicated export utility and run:
   ```bash
   flutter run -t lib/utils/export_icon.dart
   ```

#### Option B: Using flutter_launcher_icons Package

1. **Install the package:**
   ```bash
   flutter pub add flutter_launcher_icons --dev
   ```

2. **Create master icon** (512x512 or 1024x1024 PNG):
   - Use Figma/Adobe XD to create following the design spec
   - Save as `assets/icon/app_icon.png`
   - Use the color palette and design notes from `ICON_DESIGN_GUIDE.md`

3. **Configure pubspec.yaml:**
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: "^0.13.1"

   flutter_icons:
     android: "ic_launcher"
     image_path: "assets/icon/app_icon.png"
     min_sdk_android: 21
     adaptive_icon_background: "#FFFFFF"
     # Optional: adaptive icon with separate foreground
     # adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
   ```

4. **Generate icons:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Verify placement:**
   ```
   android/app/src/main/res/
   ├── mipmap-ldpi/ic_launcher.png
   ├── mipmap-mdpi/ic_launcher.png
   ├── mipmap-hdpi/ic_launcher.png
   ├── mipmap-xhdpi/ic_launcher.png
   ├── mipmap-xxhdpi/ic_launcher.png
   └── mipmap-xxxhdpi/ic_launcher.png
   ```

#### Option C: Manual Icon Creation & Placement

1. **Create icon** using design tool:
   - Design guidelines: See `ICON_DESIGN_GUIDE.md`
   - Master size: 1024x1024 pixels
   - Export as PNG with transparency

2. **Scale to all resolutions:**
   
   Using ImageMagick:
   ```bash
   # Install ImageMagick if not present
   # macOS: brew install imagemagick
   # Windows: Download from imagemagick.org
   # Linux: sudo apt-get install imagemagick
   
   convert app_icon_1024.png -resize 192x192 icon_xxxhdpi.png
   convert app_icon_1024.png -resize 144x144 icon_xxhdpi.png
   convert app_icon_1024.png -resize 96x96 icon_xhdpi.png
   convert app_icon_1024.png -resize 72x72 icon_hdpi.png
   convert app_icon_1024.png -resize 48x48 icon_mdpi.png
   convert app_icon_1024.png -resize 36x36 icon_ldpi.png
   ```

3. **Place in Android folders:**
   ```bash
   # macOS/Linux
   mkdir -p android/app/src/main/res/mipmap-{ldpi,mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}
   
   cp icon_ldpi.png android/app/src/main/res/mipmap-ldpi/ic_launcher.png
   cp icon_mdpi.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
   cp icon_hdpi.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
   cp icon_xhdpi.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
   cp icon_xxhdpi.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
   cp icon_xxxhdpi.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
   ```

   ```powershell
   # Windows PowerShell
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-ldpi"
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-mdpi"
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-hdpi"
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-xhdpi"
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-xxhdpi"
   New-Item -ItemType Directory -Force -Path "android/app/src/main/res/mipmap-xxxhdpi"
   
   Copy-Item "icon_ldpi.png" "android/app/src/main/res/mipmap-ldpi/ic_launcher.png"
   Copy-Item "icon_mdpi.png" "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
   Copy-Item "icon_hdpi.png" "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
   Copy-Item "icon_xhdpi.png" "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
   Copy-Item "icon_xxhdpi.png" "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
   Copy-Item "icon_xxxhdpi.png" "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
   ```

### Step 2: Build and Test

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK (release)
flutter build apk --release

# Or run in debug mode
flutter run
```

### Step 3: Verify Icon

- [ ] Icon appears in app launcher
- [ ] Icon looks sharp on all screen sizes
- [ ] Icon displays in notification bar
- [ ] Consistent branding across Android system

## Icon Design Creation (for Reference)

The app includes a Flutter widget (`BabySnapAIIcon`) that demonstrates the icon design:

```dart
// Location: lib/presentation/widgets/babysnap_icon.dart

// Use in your app:
BabySnapAIIcon(size: 192) // renders 192x192 icon

// Or with custom size:
BabySnapAIIcon(size: 512) // for generation/export
```

This widget includes:
- Gradient background (Sky blue → Powder blue)
- Baby face (rounded, soft peach)
- Eyes (soft blue with shine)
- Smile (gentle curve)
- Cheeks (subtle pink)
- AI scan frame (mint corners)
- Sparkles (gold stars)

## Using Online Tools

### Appicon.co (Fastest)
1. Go to **https://appicon.co/**
2. Upload your 1024x icon
3. Select "Android" platform
4. Download all generated sizes
5. Extract and place in `mipmap-*` folders

### Figma Template
1. Create new Figma file
2. Reference design from `ICON_DESIGN_GUIDE.md`
3. Design at 1024x1024
4. Export → PNG → Download
5. Use tools above to resize

## File Structure After Icon Setup

```
android/app/src/main/res/
├── drawable/
├── layout/
├── mipmap-ldpi/
│   └── ic_launcher.png (36x36)
├── mipmap-mdpi/
│   └── ic_launcher.png (48x48)
├── mipmap-hdpi/
│   └── ic_launcher.png (72x72)
├── mipmap-xhdpi/
│   └── ic_launcher.png (96x96)
├── mipmap-xxhdpi/
│   └── ic_launcher.png (144x144)
├── mipmap-xxxhdpi/
│   └── ic_launcher.png (192x192)
├── values/
└── values-night/
```

## Android Adaptive Icon (Optional)

For modern Android (8.0+) with dynamic icon backgrounds:

1. **Create adaptive icon setup:**
   ```yaml
   # In pubspec.yaml with flutter_launcher_icons:
   flutter_icons:
     android: "ic_launcher"
     image_path: "assets/icon/app_icon.png"
     adaptive_icon_background: "#87CEEB"  # Sky blue
     adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
   ```

2. **Foreground design:**
   - Use only the baby icon (no background)
   - Keep within safe zone (80% of icon)
   - Save as `assets/icon/app_icon_foreground.png`

3. **Generate:**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

## Troubleshooting

### Icon doesn't appear
- [ ] Icons placed in correct `mipmap-*` folders
- [ ] File names are exactly `ic_launcher.png`
- [ ] Run `flutter clean` before building
- [ ] Icons have correct dimensions

### Icon looks blurry
- [ ] Check PNG dimensions match expected size
- [ ] Use PNG format (not JPG)
- [ ] Ensure no over-scaling in design tool
- [ ] Try using high-quality master file (1024x+)

### Icon placeholder still shows
- [ ] Device cache: Uninstall app, rebuild
- [ ] IDE cache: Run `flutter clean && flutter pub get`
- [ ] Gradle cache: `./gradlew clean` (Windows: `gradlew.bat clean`)
- [ ] Verify AndroidManifest.xml icon reference

## Play Store Integration

### Icon for Play Store Listing
- Size: 512x512 pixels
- Format: PNG (with alpha) or JPEG
- File size: < 1 MB
- Required for app store submission

**Steps:**
1. Create 512x512 version of your icon
2. Remove transparency (use white/gradient background)
3. Upload during Google Play Console submission
4. Verify appearance in store preview

## Next Steps

1. ✅ Choose icon creation method (see Step 1)
2. ✅ Create/generate icon files
3. ✅ Place in correct Android directories
4. ✅ Run `flutter clean`
5. ✅ Build with `flutter run` or `flutter build apk`
6. ✅ Verify icon appears correctly
7. ✅ Test across different device sizes

## Resources

- **Design Guide**: See `ICON_DESIGN_GUIDE.md`
- **Icon Widget**: `lib/presentation/widgets/babysnap_icon.dart`
- **Splash Screen**: `lib/presentation/screens/splash_screen.dart`
- **Flutter Docs**: https://flutter.dev/docs/development/ui/assets-and-images
- **Android App Icons**: https://developer.android.com/guide/practices/ui_guidelines/icon_design

## Support

For issues:
1. Check Android documentation: https://developer.android.com/guide/practices/ui_guidelines/icon_design
2. Verify image dimensions and formats
3. Test with different devices/resolutions
4. Check app logs for any errors: `flutter logs`
