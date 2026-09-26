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
