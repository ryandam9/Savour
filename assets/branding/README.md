# Wooden spoon launcher art

Selected **Savour design #9** (wooden spoon and basil).

| Asset | Purpose |
| --- | --- |
| `savour_icon.png` | 1024 × 1024 opaque full-bleed iOS and legacy Android launcher icon. |
| `savour_icon_background.png` | 432 × 432 opaque green watercolor background for Android adaptive icons. |
| `savour_icon_foreground.png` | 432 × 432 transparent colored foreground (wooden spoon and herbs). |
| `savour_icon_monochrome.png` | 432 × 432 transparent white silhouette for Android 13+ themed icons. |

Android adaptive icons have separate background and foreground layers. The complete foreground artwork is within the central 66/108 dp safe zone, so circle, squircle and OEM icon shapes will not crop it. The artwork itself is not pre-rounded.

The `flutter_launcher_icons` configuration in `pubspec.yaml` regenerates the platform resources for **Android 8+ adaptive icons**, **Android 13+ wallpaper-themed monochrome icons**, and **iOS/legacy Android**. The setup script already invokes the generator; for an existing Flutter scaffold, run:

```bash
flutter pub get
dart run flutter_launcher_icons
python3 tool/verify_launcher_icons.py
```

These are original, app-specific illustrated assets. They do not include any fonts.
