# BabySnap AI - Icon Design Specification

## Overview
Modern, friendly app icon combining baby face + AI detection concepts with soft pastel colors.

## Design Concept
- **Primary Element**: Soft, rounded baby face with gentle smile
- **Secondary Element**: Subtle AI detection frame or sparkle/scan lines
- **Style**: Minimal, modern, cute, approachable
- **Color Palette**: Soft pastel tones (light blue, mint, soft purple)
- **Background**: Gradient (light blue → mint green or purple → blue)

## Visual Style Guidelines

### Color Palette
```
Primary Gradient:
  - Start: #87CEEB (Sky Blue)
  - End: #B0E0E6 (Powder Blue)

Accent Colors:
  - Mint Green: #98FFD2
  - Soft Purple: #D8B0E8
  - White/Highlights: #FFFFFF

Baby Face:
  - Skin Tone: #FDBFC8 (Soft Peach)
  - Eyes: #4A90E2 (Soft Blue)
  - Smile/Accent: #87CEEB (Sky Blue)
```

### Icon Elements
1. **Baby Face** (center, 60% of icon)
   - Rounded head shape with slight smile
   - Two simple dot eyes (soft blue)
   - Curved smile line
   - Minimal cheek circles

2. **AI Detection Frame** (20% of icon)
   - Subtle scan lines or corner brackets
   - Position: Around baby face
   - Color: Gradient highlight (light mint to light blue)
   - Opacity: 40-60% to not overwhelm

3. **Sparkle/Shine Effect** (optional)
   - 2-3 small stars or sparkles
   - Position: Top right corner
   - Color: Soft gold or bright mint
   - Represents "AI detection" concept

4. **Background Gradient**
   - Smooth radial or linear gradient
   - Colors: Sky blue → Powder blue → Mint green
   - Rounded corners for modern feel

## Android Asset Sizes & Resolutions

### Icon Dimensions (Required)
```
ldpi (low-density):     36x36 dp
mdpi (medium-density):  48x48 dp
hdpi (high-density):    72x72 dp
xhdpi (extra-density):  96x96 dp
xxhdpi (extra²-density): 144x144 dp
xxxhdpi (extra³-density): 192x192 dp
```

### Pixel Dimensions (for 160 DPI baseline)
```
ldpi:   (120 dpi) →  27x27 px
mdpi:   (160 dpi) →  48x48 px
hdpi:   (240 dpi) →  72x72 px
xhdpi:  (320 dpi) → 96x96 px
xxhdpi: (480 dpi) → 144x144 px
xxxhdpi:(640 dpi) → 192x192 px
```

## File Placement for Android

Place icon assets in the following Android directory structure:

```
android/app/src/main/res/
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
└── mipmap-xxxhdpi/
    └── ic_launcher.png (192x192)
```

## How to Create the Icon

### Option 1: Using Figma (Recommended)
1. Create new 1024x1024 px design (for export)
2. Add gradient background (Sky blue to Powder blue)
3. Insert rounded rectangle (baby head shape)
4. Add eyes (2 small circles, soft blue color)
5. Add smile (curved path)
6. Add scan frame lines around face
7. Export as PNG at required resolution sizes
8. Place in respective mipmap folders

**Figma Template Steps:**
- Board: 1024x1024
- Frame: Rounded corner rectangle
- Fill: Gradient (87CEEB to B0E0E6)
- Layer: Baby face (FDBFC8)
- Layer: Eyes (4A90E2)
- Layer: Smile (curve path)
- Export menu: PNG, 1024x1024
- Then scale down to other resolutions

### Option 2: Using Online Tool (flutter_launcher_icons)
1. Install package: `flutter pub add flutter_launcher_icons`
2. Create master icon (512x512 px PNG)
3. Configure `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: "^0.13.1"

   flutter_icons:
     android: "ic_launcher"
     image_path: "assets/icons/babysnap_icon.png"
     adaptive_icon_background: "#FFFFFF"
     adaptive_icon_foreground: "assets/icons/babysnap_icon_foreground.png"
   ```
4. Run: `flutter pub run flutter_launcher_icons`
5. Icons are auto-generated in mipmap folders

### Option 3: Adobe XD or Sketch
1. Create 1024px x 1024px artboard
2. Design following guidelines above
3. Export as PNG
4. Use ImageMagick or online tool to scale:
   ```bash
   convert icon_1024.png -resize 192x192 iconxxxhdpi.png
   convert icon_1024.png -resize 144x144 iconxxhdpi.png
   # ... etc for other sizes
   ```
5. Move to correct mipmap folders

### Option 4: Online Icon Generators
- **Appicon.co** - Upload 1024x design, auto-generates all sizes
- **Icons8** - Design or search icon, customize colors
- **Figma Community** - Search "app icon template"

## Design Output Requirements

### Master File
- Format: PNG or SVG
- Size: 1024x1024 pixels
- Transparency: Yes (RGBA)
- Color Mode: RGB

### Export Sizes & Names
```
Icon Size     Resolution  Filename
ldpi          27x27       ic_launcher.png
mdpi          48x48       ic_launcher.png
hdpi          72x72       ic_launcher.png
xhdpi         96x96       ic_launcher.png
xxhdpi        144x144     ic_launcher.png
xxxhdpi       192x192     ic_launcher.png
```

## Play Store Requirements

### Icon Specifications for Play Store
- Dimensions: 512x512 pixels
- Format: PNG or JPEG
- Colors: RGB (no alpha channel for store listing)
- File size: < 1 MB

### Store Icon Design Checklist
- [ ] Icon is recognizable at small sizes
- [ ] Clear contrast with background
- [ ] No text or complicated details
- [ ] Safe area respected (20% padding)
- [ ] Consistent with brand colors
- [ ] Works on both light and dark store backgrounds

## Safe Area / Keyline System

For proper scaling, maintain safe area:
- **Total Icon Size**: 192x192 px (xxxhdpi)
- **Safe Area**: 20% padding (≈ 154x154 px center area)
- **Outermost Extent**: Can use full 192x192 but risky with cutoff

## Next Steps

1. **Design the Icon**: Use preferred tool from options above
2. **Export All Sizes**: Generate or manually scale to 6 resolutions
3. **Verify Sizes**: Check each PNG is correct dimensions
4. **Place in Project**: Copy to `android/app/src/main/res/mipmap-*/`
5. **Build & Test**: Run `flutter run` to see icon on device
6. **Polish**: Adjust if needed based on device preview

## Quick Start - Using Flutter Launcher Icons

```bash
# Add to pubspec.yaml under dev_dependencies
flutter pub add flutter_launcher_icons --dev

# Create icon at: assets/app_icon.png (must be 512x512 or larger)

# Run generation
flutter pub run flutter_launcher_icons:main

# Build app
flutter run
```

## Verification

After placing icons, verify by:
1. Running `flutter run` on device
2. Checking app appears with new icon
3. Testing across different screen densities
4. Verifying in notification bar and app drawer

## SVG Template (for Figma/XD)

If creating from scratch, use this structure:
- Background: 1024x1024 rounded rectangle with gradient fill
- Baby head: 400x400 circle with peach fill
- Eyes: Two 40x40 circles, soft blue, positioned at (250, 320) and (400, 320)
- Mouth: Bezier curve from (270, 450) to (380, 450) with blue stroke
- Scan frame: 4 corner brackets, 100x100 px each, mint color 40% opacity
- Sparkles: 2-3 small stars at (800, 100) for brightness

## Resources & Tools

- **Color Palette**: https://coolors.co/87ceeb-b0e0e6-98ffd2-d8b0e8
- **Icon Grid**: https://www.figma.com/icons/
- **Appicon.co**: https://appicon.co/ (auto-generates all sizes)
- **Flutter Icons**: https://pub.dev/packages/flutter_launcher_icons
- **Material Design Icons**: https://fonts.google.com/icons

## Support

For questions or design feedback:
- Reference Google Play Store app icon guidelines
- Test on multiple devices before release
- Consider A/B testing different color schemes
