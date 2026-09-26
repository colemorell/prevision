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

Bundled USDZ models live in `Prevision/Resources/Models/` (trimmed apartment ~46MB). Raw source assets live in `/Models` at the repo root and are git-ignored.

## Brand Guide

All text uses `Brand.Typography` tokens:
- `title`, `body`, `label`, `caption` — mapped to Dynamic Type

The single CTA color is `AccentColor` in `Prevision/Resources/Assets.xcassets`. Change it there to rebrand.

Spacing/radius/motion tokens are defined in `Brand.swift`. Animations use ease-in-out per the HIG.

## Furniture Catalog

Furniture catalog is in `Prevision/Data/furniture.json`. Dimensions are in inches. The `zUp` flag indicates Z-up models (e.g., `sectional_sofa.usdz` requires a −90° X rotation).

## Features

**Furniture Placement:** Long-press a furniture tile and drag it to place—a glass card follows your finger. Over the room, it becomes a translucent 3D ghost on the floor. Release to drop it in. Alternatively, tap a tile, then tap the floor to place it.

**Edit Mode:** Press and hold a placed piece to enter edit mode. Drag to move (respects room walls), twist or use the Rotate buttons to rotate, pinch to resize (0.3x to 3x). Tap Set to confirm changes.

**Toolbar:** Back to Designs; Light (sun) opens a vertical glass slider controlling scene brightness (saved per design); More (ellipsis) provides Add Note, Notes, and Recenter.

**Client Notes:** The client taps the client or outer screen to prompt the designer to add a note there.

**Device Support:** Runs on regular iPhones with a single-screen layout and on iPhone Duo with client view on the top half, designer controls on the bottom half, and outer screen via CameraCaptureAccessory on iOS 27.1. Deployment target is iOS 27.0.

## Usage

Open a saved design and long-press furniture tiles to add them to the room. Use gestures to position and orient pieces—drag to move, rotate to turn, pinch to resize. Tap Set to confirm. The designer adjusts scene brightness with the Light control and adds notes for the client. On iPhone Duo, the client watches the outer screen while the designer controls the inner screen.
