# Prevision — Build Plan

Live 3D showroom for interior designers. iPhone Duo (foldable): designer controls inner screen, client watches outer screen live. Native iOS, Swift + SwiftUI + RealityKit. No backend. 4-hour solo hackathon demo.

## Structure

```
Prevision/
  App/PrevisionApp.swift          entry, shared stores and scene controller
  Brand/Brand.swift               type, spacing, radius, motion tokens; overlayLabel
  Models/                         Design (placements, notes, light level), FurnitureItem, Note
  Data/
    DesignStore.swift             saved designs (JSON in Application Support)
    FurnitureLibrary.swift        bundled + imported USDZ, thumbnails
    furniture.json                size and orientation overrides
  Scene/
    SceneController.swift         placement, editing, camera, lighting, persistence
    SceneRig.swift                per-view root + camera, attach and redraw heartbeat
    RoomScene.swift               loads the living room, hides ceiling, lights
    RaycastPlacement.swift        screen ray, floor hit, model loading
    Lighting.swift                image-based lighting
    StickyNote.swift              3D note pins
    ThumbnailRenderer.swift       offscreen thumbnails
  Display/
    CaptureSessionController.swift  AVCaptureSession for the outer screen
    CameraPreviewView.swift       hidden preview layer
    GeometryProxy+Hinge.swift     hinge division from reserved regions
  Views/
    RootView, HomeView, SettingsView
    InnerDisplayView              Duo split: client top, designer bottom
    DesignerView, AssetPoolView, LightSlider, RoomLoadingView, TwoFingerPan
    ClientView, OuterDisplayView  mirrors; outer via CameraCaptureAccessory
    NotesListView
  Resources/                      models, IBL, assets, app icon
```
## Completed

1. **Assets**: living room and furniture models bundled; deployment target iOS 27.0.
2. **Xcode project**: XcodeGen project.yml with team configured.
3. **Core scene**: `RoomScene` loads living room, orbits, zooms, double-tap zoom toward spot (double-tap again to zoom out).
4. **Placement**: long-press furniture tiles to drag into room with glass card feedback and translucent ghost preview; releasing drops into edit mode with drag/rotate/resize/Set workflow; long-press placed piece for Edit or Delete.
5. **Dual screen**: `DesignerView` on inner bottom, `ClientView` on inner top and outer screen via `CameraCaptureAccessory` (iOS 27.1), outer screen rotated 90° for laptop posture (configurable in Settings).
6. **Toolbar**: Back, Light (vertical glass slider, saved per design), More menu (Add Note, Notes, Recenter).
7. **Gestures**: one-finger drag orbits, two-finger drag pans, pinch zooms, double-tap zooms toward a spot.
8. **UI Test**: `PrevisionUITests/PrevisionFlowTests.swift`.

## Open items

- Verify outer screen on physical iPhone Duo hardware.
- Add more furniture models.

## Units
- Living room: centimeters, Y-up → scale 0.01.
- Furniture: `furniture.json` in inches → scale model to (target_inches * 0.0254) / model_native_extent.
- `sectional_sofa.usdz`: meters, Z-up → rotate -90° on X.
