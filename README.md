# Prevision

Live 3D showroom for interior designers on iPhone Duo: designer controls the inner screen, client watches the outer screen.

## Requirements

- Xcode 27.1
- iOS 27 SDK
- XcodeGen (`brew install xcodegen`)

## Setup

```bash
xcodegen generate
open Prevision.xcodeproj
```

Signing team Layout Media LLC (857MZR9QLJ) is configured in `project.yml`. Run on the "iPhone Duo" simulator with iOS 27.1.

## Project Structure

```
Prevision/
  App/                    Entry point, scene phase, external display hook
  Brand/                  Design tokens: typography, spacing, radius, motion
  Data/                   Furniture catalog loader
  Display/                External display manager for outer screen mirroring
  Scene/                  RealityKit scene: room, lighting, camera, placement, gestures
  Views/                  Designer controls, client view, furniture list, notes
  Resources/              Bundled assets and USDZ models
```

## Assets

Bundled USDZ models live in `Prevision/Resources/Models/` (living room ~7MB, furniture under 1MB each). Raw source assets live in `/Models` at the repo root and are git-ignored.

## Brand Guide

All text uses `Brand.Typography` tokens:
- `title`, `body`, `label`, `caption` — mapped to Dynamic Type

The single CTA color is `AccentColor` in `Prevision/Resources/Assets.xcassets`. Change it there to rebrand.

Spacing/radius/motion tokens are defined in `Brand.swift`. Animations use ease-in-out per the HIG.

## Furniture Catalog

Furniture catalog is in `Prevision/Data/furniture.json`. Dimensions are in inches. The `zUp` flag indicates Z-up models (e.g., `sectional_sofa.usdz` requires a −90° X rotation).

## Features

**Home:** Designs listed in inset-grouped List. Swipe left to delete; press and hold for Rename or Delete. Settings (gear) at top left; tinted glass "+" at top right creates design (prompts for name).

**Designer:** Living-room model (Simple_Modern_Living_Room.usdz) shown dollhouse-style with ceiling hidden. Long-press furniture tile, drag into room; glass card follows finger, translucent 3D ghost appears on floor, releasing drops into edit mode. Edit mode: drag to move, twist or Rotate buttons to rotate, pinch to resize, Set to confirm. Long-press placed piece for Edit or Delete.

**Gestures:** One-finger drag orbits, two-finger drag pans, pinch zooms, double-tap zooms toward a spot (double-tap again when close to zoom out).

**Toolbar:** Back to Designs; Light (vertical glass brightness slider, saved per design); More menu (Add Note, Notes, Recenter).

**Client View:** On iPhone Duo, client view is on outer screen, mirrored via CameraCaptureAccessory (iOS 27.1), rotated 90 degrees for laptop posture (configurable in Settings under Client Screen Rotation). Client can tap outer screen to prompt designer to add a note.

**Deployment:** Regular iPhone uses single-screen layout. iPhone Duo splits at hinge (top inner = client, bottom inner = designer). Deployment target iOS 27.0.

## Usage

Open a saved design and long-press furniture tiles to add them to the room. Use gestures to position and orient pieces—drag to move, rotate to turn, pinch to resize. Tap Set to confirm. The designer adjusts scene brightness with the Light control and adds notes for the client. On iPhone Duo, the client watches the outer screen while the designer controls the inner screen.
