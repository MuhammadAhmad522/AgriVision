# 10. Interface Design (Figma Screen Wireframe Specifications)

The AgriVision frontend is designed with a mobile-first philosophy. The user interface prioritizes high legibility out in the field (high contrast) and quick access to core metrics. The following specifications act as the blueprint for the Figma wireframes and the final iOS implementations.

## 10.1 Global Design System
*   **Typography:** Modern, clean sans-serif (e.g., Apple San Francisco or Inter) to ensure readability of data-heavy metrics.
*   **Color Palette:**
    *   *Primary:* Forest Green (Agriculture motif, success states).
    *   *Secondary:* Deep Blue (Action buttons, links).
    *   *Alerts:* Amber/Red (Sensor anomalies, high-risk pest warnings).
    *   *Background:* Soft off-white/light gray (to reduce glare outdoors).
*   **Navigation:** Bottom Tab Bar for quick switching between `Dashboard`, `Chat`, `Fields`, and `Settings`.

---

## 10.2 Screen Blueprint: User Login & Onboarding
**Purpose:** Secure entry point via Firebase Auth.
**Layout Structure (Top to Bottom):**
1.  **Header:** Large AgriVision Logo and "Welcome Back" greeting.
2.  **Input Form:** 
    *   Email Address text field (with icon).
    *   Password secure text field (with toggle visibility eye icon).
3.  **Action Buttons:**
    *   Solid Primary Button: "Sign In".
    *   Outline Button: "Continue with Google".
4.  **Footer:** "Forgot Password?" link and "Create an Account" toggle.

---

## 10.3 Screen Blueprint: Field Setup (Polygon Drawing)
**Purpose:** Allow farmers to map their physical fields for satellite syncing.
**Layout Structure (Top to Bottom):**
1.  **Header Bar:** "Add New Field", Back Button, and "Save" button in the top right.
2.  **Map Canvas (Center/Full):** Interactive Apple Map / Google Map taking up 70% of the screen.
    *   *Floating Action:* A floating crosshair target button to snap to the user's current GPS location.
    *   *Overlay:* Polygon drawing nodes that the user drops on the map.
3.  **Bottom Sheet (Slide Up):**
    *   Text Field: "Field Name" (e.g., North Wheat Field).
    *   Dropdown Selection: "Crop Type" (Wheat, Rice, Sugarcane).
    *   Status Text: "AgroMonitoring Sync Ready".

---

## 10.4 Screen Blueprint: Main Dashboard
**Purpose:** The central hub displaying synthesized data from satellites and IoT sensors.
**Layout Structure (Top to Bottom):**
1.  **Top Navigation:** Field selector dropdown (if the user owns multiple fields) and Notification bell icon.
2.  **Hero Section (Satellite View):** A horizontal card displaying the latest Sentinel-2 true-color or NDVI image of the selected field, overlaying the weather summary (Temperature, Rain Icon).
3.  **Telemetry Grid (IoT Sensors):** A 2-column grid of data cards displaying live metrics from the ESP32 bridge:
    *   *Card 1:* Soil Moisture % (with an animated circular progress bar).
    *   *Card 2:* Ground Temperature °C.
    *   *Card 3:* NPK Nutrient Levels.
    *   *Card 4:* pH Level.
4.  **Action Banner:** A highlighted banner (Amber if urgent) showing the latest AI Recommendation (e.g., "Irrigation recommended in 2 hours").

---

## 10.5 Screen Blueprint: AI Chat Interface
**Purpose:** Conversational UI for the farmer to get diagnostic help and ask agronomic questions.
**Layout Structure (Top to Bottom):**
1.  **Header:** "AI Agronomy Advisor" title with an online status indicator (green dot).
2.  **Chat Scroll View (Main Body):**
    *   User Message Bubbles (Aligned right, grey background).
    *   AI Response Bubbles (Aligned left, green background). Contains Markdown support for bold text and bullet points.
    *   *Safety Disclaimers:* If an AI response mentions pesticides, a secondary red-tinted box appears below the bubble explicitly warning the user to verify with a local expert.
3.  **Input Area (Bottom Pinned):**
    *   Camera/Attachment Icon: To upload photos of diseased crops.
    *   Text Input Field: "Type your question here...".
    *   Send Button (Paper airplane icon).

---

## 10.6 Screen Blueprint: Settings & Profile
**Purpose:** Manage account preferences and hardware connections.
**Layout Structure (Top to Bottom):**
1.  **Profile Banner:** User avatar, Display Name, and Email Address.
2.  **List View Categories:**
    *   *Section 1: Account* (Edit Profile, Change Password).
    *   *Section 2: Hardware* (Manage IoT Devices, Check MQTT Connection Status).
    *   *Section 3: Preferences* (Notification settings for push alerts).
3.  **Danger Zone:** Red "Sign Out" button at the very bottom.
