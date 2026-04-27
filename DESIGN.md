---
name: Cyber-Minimalist AI
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1b1b1b'
  surface-container: '#1f1f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353535'
  on-surface: '#e2e2e2'
  on-surface-variant: '#bbc9cf'
  inverse-surface: '#e2e2e2'
  inverse-on-surface: '#303030'
  outline: '#859399'
  outline-variant: '#3c494e'
  surface-tint: '#4cd6ff'
  primary: '#a4e6ff'
  on-primary: '#003543'
  primary-container: '#00d1ff'
  on-primary-container: '#00566a'
  inverse-primary: '#00677f'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#474746'
  on-secondary-container: '#b7b5b4'
  tertiary: '#dedcdb'
  on-tertiary: '#303030'
  tertiary-container: '#c2c0c0'
  on-tertiary-container: '#4f4e4e'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#b7eaff'
  primary-fixed-dim: '#4cd6ff'
  on-primary-fixed: '#001f28'
  on-primary-fixed-variant: '#004e60'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474747'
  background: '#131313'
  on-background: '#e2e2e2'
  surface-variant: '#353535'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  island-margin: 12px
---

## Brand & Style

This design system is defined by a "Cyber-Minimalist" aesthetic, blending the starkness of pure black interfaces with the ethereal quality of glassmorphism. It is designed specifically for power users who value speed, precision, and a sophisticated workspace. The brand personality is clinical yet visionary—acting as a silent, high-performance partner rather than a decorative assistant.

The visual language draws heavily from modern macOS architecture, utilizing translucent layers and sharp, thin strokes to create a sense of weightlessness. By focusing on high contrast and a singular, vibrant accent, the UI eliminates cognitive load and directs the user's focus entirely toward the AI interaction.

## Colors

The color palette is rooted in a "True Dark" philosophy. The background is a pure #000000, which on modern OLED and Pro Display XDR screens allows the hardware to disappear, leaving the UI floating in space.

*   **Primary (#00D1FF):** A high-energy neon cyan used exclusively for action states, focus indicators, and the AI's "active" presence.
*   **Surface Hierarchy:** Deep charcoal grays (#1A1A1A and #2C2C2C) define the structural layers and cards, providing enough contrast against the pure black background to establish depth without breaking the dark aesthetic.
*   **Text:** Pure white is reserved for primary headers, while secondary information is rendered in a muted gray to maintain visual hierarchy.

## Typography

This design system utilizes **Inter** for its utilitarian precision and exceptional readability at small sizes common in macOS utilities. The type system is compact to accommodate the dense information flow of a chat app.

High-contrast weights are used to distinguish between user prompts (Medium) and AI responses (Regular). Labels and metadata use uppercase tracking to create a technical, "instrument-panel" feel. All typography is optimized for sub-pixel rendering on Retina displays.

## Layout & Spacing

The layout is centered around the "Island" concept—a floating, contextual container that expands and contracts based on the state of the conversation. 

We use a tight 4px base grid to ensure the UI feels "engineered." Margins are generous around the main chat container to maintain the minimalist vibe, while internal padding within cards and the Dynamic Island is kept compact to maximize information density. The layout does not follow a traditional column grid but instead uses a centered, fluid container with a maximum width of 800px for optimal reading comfort.

## Elevation & Depth

Depth is achieved through **Tonal Layering** and **Glassmorphism** rather than traditional drop shadows.

1.  **Level 0 (Background):** Pure #000000.
2.  **Level 1 (Cards/Panels):** #1A1A1A with a 1px border (#FFFFFF at 10% opacity).
3.  **Level 2 (The Island):** Backdrop blur (20px to 40px) with a semi-transparent dark fill (#000000 at 70% opacity). 

Borders are essential in this design system; they must be thin (0.5pt to 1pt) and slightly brightened to define the edges of elements against the black void.

## Shapes

The shape language is "Subtly Rounded." The base radius is 8px (0.5rem), which provides a modern, friendly touch without sacrificing the "high-tech" professional look. 

Elements that are interactive or "contained," such as the chat input bar or the Dynamic Island itself, should use the `rounded-xl` (24px) or full pill-shape to distinguish them from structural cards. Iconography should follow a linear style with a 1.5px or 2px stroke width, matching the thin-border aesthetic of the containers.

## Components

*   **The Island:** A central, top-aligned component that houses status indicators. It should transition smoothly from a pill shape to a large card using spring physics.
*   **Chat Bubbles:** These are not traditional bubbles. User messages are right-aligned, plain text. AI responses are housed in a subtle #1A1A1A card with a 1px border to denote the "machine" output.
*   **Input Field:** A floating, glassmorphic bar at the bottom. It features the neon blue accent for the "send" button and the text insertion point.
*   **Primary Button:** Solid neon blue (#00D1FF) with black text for maximum contrast.
*   **Secondary/Ghost Button:** Transparent background with a 1px white (15% opacity) border. 
*   **Progress Bars:** Ultra-thin (2px) lines using the primary accent color to show compute progress or context window usage.
*   **System Controls:** Small, circular #1A1A1A buttons for settings, history, and audio, using crisp white iconography.
