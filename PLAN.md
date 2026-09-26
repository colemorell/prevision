# Prevision — Build Plan

Live 3D showroom for interior designers. iPhone Duo (foldable): designer controls inner screen, client watches outer screen live. Native iOS, Swift + SwiftUI + RealityKit. No backend. 4-hour solo hackathon demo.

## Structure

```
Prevision/
  App/PrevisionApp.swift          entry, scene phase, external display hook
  Models/
    FurnitureItem.swift           id, name, usdz filename, real dims (inches), z-up flag
    Note.swift                    id, text, world position, room tag
  Data/
    furniture.json                catalog: dims + model filenames
    FurnitureCatalog.swift        loads + decodes furniture.json
  Scene/
    RoomScene.swift               RealityKit scene: load apartment, lighting, camera
    SceneController.swift         ObservableObject: gestures, place, orbit/zoom, notes
    RaycastPlacement.swift        tap floor -> world point -> drop scaled model
  Views/
    DesignerView.swift            inner bottom: RealityView + control overlay
    ClientView.swift              inner top / mirror of client outer view
    FurnitureListView.swift       tap item to arm placement
    NotesListView.swift           notes grouped by room (stretch)
    NoteBubbleView.swift          "Add a note here?" bubble (stretch)
  Display/
    ExternalDisplayManager.swift  CameraCaptureAccessory / outer screen mirroring
  Resources/Models/               *.usdz (bundled)
```

## Order of work (4h)

1. **Assets first** (blocks everything). Trim `Modern_Apartment.usdz` (~102MB → target <30MB): remove Door_001, Plants, KDecor, CouchSet, Shoes, MacBook, OficeDecors, BedDecors. Drop trimmed apartment + 3 furniture USDZ into `Resources/Models/`.
2. **Xcode project**: create iOS App target "Prevision", SwiftUI lifecycle, min iOS 18. Add all Swift files + Resources folder (folder reference).
3. **Core scene**: `RoomScene` loads apartment, converts cm→m, Y-up. Basic orbit/zoom gestures in `SceneController`.
4. **Placement**: `FurnitureListView` arms an item → `RaycastPlacement` on floor tap → drop model auto-scaled from `furniture.json` inches. Handle `sectional_sofa` Z-up: rotate -90° X.
5. **Dual screen**: `DesignerView` (controls) + `ClientView` (clean view). `ExternalDisplayManager` mirrors client view to outer screen via CameraCaptureAccessory.
6. **Stretch**: sticky notes (tap to pin), notes list grouped by room, client-tap bubble.

## Risks / fallbacks
- Simulator has no camera → outer accessory may not appear. **Test #5 early.** Fallback: show `ClientView` as side panel, narrate "this is the outer screen on hardware."
- Apartment perf: trim aggressively; if still slow, bake lighting / reduce further.

## Units
- Apartment: centimeters, Y-up → scale 0.01.
- Furniture: `furniture.json` in inches → scale model to (target_inches * 0.0254) / model_native_extent.
- `sectional_sofa.usdz`: meters, Z-up → rotate -90° on X.
