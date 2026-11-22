# Poohw Design System — Precision Metal & Crimson Pulse

## 1. Vision & Identity

**Poohw** is an open-source, local-first wearable intelligence companion. Unlike conventional flat or pastel fitness apps, Poohw draws its aesthetic identity from high-end horology, precision machined titanium, and motorsport telemetry:
- **Primary Pigment**: **Liquid Silver & Machined Titanium** (Argento Metallico) — pure, cold, industrial precision.
- **Accent Energy**: **Laser Crimson & Ruby Pulse** (Rosso Rubino) — vitality, heartbeat, urgency, and live biodata.
- **Tactile Depth**: 3D beveled surfaces, chamfered rim highlights, and ambient metallic specular reflection animations.

---

## 2. Color System & Contrast Guarantees

All colors adhere strictly to WCAG 2.1 AA (4.5:1 text contrast floor against all legal surfaces) as enforced by `test/ui2_contrast_test.dart`.

### 2.1 Base Pigments (`C`)
| Token | Hex | Role | Contrast Note |
|---|---|---|---|
| `C.silverLight` | `#F8FAFC` | Polished specular platinum | Primary high-sheen ink & highlight |
| `C.silverMid` | `#E2E8F0` | Brushed aluminum plate | Card borders, secondary numerals |
| `C.silverDark` | `#94A3B8` | Gunmetal / titanium shadow | Muted telemetry, inactive state |
| `C.crimson` | `#FF1E38` | Primary brand accent & live pulse | High-visibility biological signal |
| `C.crimsonDeep`| `#B91C1C` | Deep ruby structural fill | Button fills, active badges |
| `C.obsidianDark`| `#0A0D13` | Deep space vacuum background | Main dark scaffold |
| `C.obsidianPlate`| `#121722` | Machined titanium card surface | Elevated card base |
| `C.obsidianCard`| `#1A2130` | Chamfered second-tier surface | Nested containers, search fields |

### 2.2 Semantic Domain Mapping
- **Today (Home)**: Liquid Silver (`#E2E8F0`) & Crimson Core (`#FF1E38`) — immediate biometric snapshot.
- **Sleep**: Platinum Moonlight (`#CBD5E1`) with Deep Starlight Indigo (`#6366F1`) — restorative rest.
- **Activity**: Forged Crimson & Molten Ember (`#FF2A3A` & `#F97316`) — cardiovascular strain.
- **Health**: Anodized Sterling (`#E2E8F0`) & Electric Vitality (`#38BDF8`) — clinical baseline metrics.

---

## 3. Surface & Lighting Model (The 3D Metallic Effect)

### 3.1 Chamfered Bevel
Every metallic card (`Surface`) features a dual-rim lighting illusion:
- **Top & Left Rim**: Subtle 1px specular highlight (`rgba(255, 255, 255, 0.14)`) simulating overhead studio lighting.
- **Bottom & Right Rim**: Ambient occlusion drop shadow (`rgba(0, 0, 0, 0.45)`) creating milled-metal slab depth.

### 3.2 Specular Light Reflection Sweep (`MetallicShimmer`)
To deliver the requested *"animazioni dei riflessi del metallo che sembra in 3D"*:
- A dynamic anisotropic specular reflection angle (sweep from -45° to +135°).
- A linear gradient with transparent tails and a luminous silver band (`#FFFFFF` at 12% opacity).
- Fully gated by `Motion.enabled(context)` and `test/ui2_tokens_test.dart` to respect reduced motion accessibility.

---

## 4. Typography Hierarchy (`F`)
- Font Family: `.SF Pro Text` with fallback to bundled `Manrope`.
- Numeric values: `FontFeature.tabularFigures()` on all metrics (`n48`, `n34`, `n24`, `n17`) to eliminate layout jitter during live telemetry updates.
- Display scale:
  - `display`: 34pt / -0.8 tracking (Heavy titanium)
  - `head`: 17pt / -0.2 tracking (Machined labels)
  - `body`: 15pt / -0.1 tracking (Legible body data)
  - `cap`: 13pt / normal (Secondary telemetry)
  - `over`: 11pt / +0.5 tracking (Uppercase technical caps)

---

## 5. App Icon & Emblem
- **Icon Motif**: An interlocking geometric monogram of "P" and "W" rendered in 3D brushed chrome, mounted inside a circular chamfered bezel with a glowing ruby red laser cardiogram core.
- **Formats**: Android Adaptive Icon (foreground vector/raster + dark titanium textured background) and standard mipmaps (`mdpi` through `xxxhdpi`).
