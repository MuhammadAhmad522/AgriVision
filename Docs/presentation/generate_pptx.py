import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def create_presentation(output_path):
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_slide_layout = prs.slide_layouts[6]

    # Color Palette (Deep Executive Tech Dark / Emerald Precision)
    BG_DARK = RGBColor(10, 22, 18)        # #0A1612
    CARD_BG = RGBColor(16, 36, 28)        # #10241C
    CARD_BORDER = RGBColor(30, 65, 52)    # #1E4134
    ACCENT_EMERALD = RGBColor(16, 185, 129) # #10B981
    ACCENT_MINT = RGBColor(52, 211, 153)    # #34D399
    ACCENT_CYAN = RGBColor(6, 182, 212)     # #06B6D4
    ACCENT_AMBER = RGBColor(245, 158, 11)   # #F59E0B
    ACCENT_ROSE = RGBColor(244, 63, 94)     # #F43F5E
    TEXT_WHITE = RGBColor(255, 255, 255)
    TEXT_MUTED = RGBColor(148, 163, 184)    # #94A3B8
    TEXT_DIM = RGBColor(100, 116, 139)      # #64748B

    diagrams_dir = "/Users/ahmad/AgriVision/Docs/srs/diagrams"

    def set_slide_background(slide):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = BG_DARK
        bg.line.fill.background()
        return bg

    def add_header(slide, tag_text, title_text, subtitle_text=""):
        # Tag pill
        tag_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.5), Inches(11.7), Inches(0.35))
        tf_tag = tag_box.text_frame
        tf_tag.word_wrap = True
        tf_tag.margin_left = tf_tag.margin_right = tf_tag.margin_top = tf_tag.margin_bottom = 0
        p_tag = tf_tag.paragraphs[0]
        p_tag.text = tag_text.upper()
        p_tag.font.size = Pt(10)
        p_tag.font.bold = True
        p_tag.font.color.rgb = ACCENT_MINT

        # Title
        title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.85), Inches(11.7), Inches(0.7))
        tf_title = title_box.text_frame
        tf_title.word_wrap = True
        tf_title.margin_left = tf_title.margin_right = tf_title.margin_top = tf_title.margin_bottom = 0
        p_title = tf_title.paragraphs[0]
        p_title.text = title_text
        p_title.font.size = Pt(22)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_WHITE

        if subtitle_text:
            p_sub = tf_title.add_paragraph()
            p_sub.text = subtitle_text
            p_sub.font.size = Pt(12)
            p_sub.font.color.rgb = TEXT_MUTED
            p_sub.space_before = Pt(4)

    def add_footer(slide, slide_num, total_slides=11):
        # Footer line
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(6.9), Inches(11.733), Inches(0.02))
        line.fill.solid()
        line.fill.fore_color.rgb = CARD_BORDER
        line.line.fill.background()

        # Footer text
        foot_box = slide.shapes.add_textbox(Inches(0.8), Inches(6.95), Inches(8.0), Inches(0.35))
        tf = foot_box.text_frame
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = "AgriVision Platform • Technical Architecture & SRS Specification"
        p.font.size = Pt(9)
        p.font.color.rgb = TEXT_DIM

        num_box = slide.shapes.add_textbox(Inches(10.533), Inches(6.95), Inches(2.0), Inches(0.35))
        tf_num = num_box.text_frame
        tf_num.margin_left = tf_num.margin_right = tf_num.margin_top = tf_num.margin_bottom = 0
        p_num = tf_num.paragraphs[0]
        p_num.alignment = PP_ALIGN.RIGHT
        p_num.text = f"{slide_num:02d} / {total_slides:02d}"
        p_num.font.size = Pt(9)
        p_num.font.color.rgb = TEXT_DIM

    def create_card(slide, left, top, width, height, title="", badge="", accent_color=ACCENT_EMERALD):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        card.fill.solid()
        card.fill.fore_color.rgb = CARD_BG
        card.line.color.rgb = CARD_BORDER
        card.line.width = Pt(1)

        # Accent top highlight stripe
        stripe = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.15), top + Inches(0.12), width - Inches(0.3), Inches(0.04))
        stripe.fill.solid()
        stripe.fill.fore_color.rgb = accent_color
        stripe.line.fill.background()

        content_top = top + Inches(0.25)
        content_height = height - Inches(0.35)

        # Card Title
        if title:
            tbox = slide.shapes.add_textbox(left + Inches(0.2), content_top, width - Inches(0.4), Inches(0.4))
            tf = tbox.text_frame
            tf.word_wrap = True
            tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
            p = tf.paragraphs[0]
            p.text = title
            p.font.size = Pt(14)
            p.font.bold = True
            p.font.color.rgb = TEXT_WHITE

            if badge:
                p_badge = p.add_run()
                p_badge.text = f"  [{badge}]"
                p_badge.font.size = Pt(10)
                p_badge.font.bold = True
                p_badge.font.color.rgb = accent_color

            content_top += Inches(0.4)
            content_height -= Inches(0.4)

        tb = slide.shapes.add_textbox(left + Inches(0.2), content_top, width - Inches(0.4), content_height)
        tf_body = tb.text_frame
        tf_body.word_wrap = True
        tf_body.margin_left = tf_body.margin_right = tf_body.margin_top = tf_body.margin_bottom = 0
        return tf_body

    # ==========================================
    # SLIDE 1: Title Slide
    # ==========================================
    slide1 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide1)

    # Ambient decorative glow cards
    glow = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.2), Inches(11.733), Inches(5.0))
    glow.fill.solid()
    glow.fill.fore_color.rgb = CARD_BG
    glow.line.color.rgb = CARD_BORDER
    glow.line.width = Pt(1.5)

    # Brand badge
    b_pill = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(1.3), Inches(1.7), Inches(3.2), Inches(0.4))
    b_pill.fill.solid()
    b_pill.fill.fore_color.rgb = RGBColor(16, 50, 36)
    b_pill.line.color.rgb = ACCENT_EMERALD
    b_pill.line.width = Pt(1)
    tf_pill = b_pill.text_frame
    p_pill = tf_pill.paragraphs[0]
    p_pill.alignment = PP_ALIGN.CENTER
    p_pill.text = "AGRONOMIC INTELLIGENCE PLATFORM"
    p_pill.font.size = Pt(10)
    p_pill.font.bold = True
    p_pill.font.color.rgb = ACCENT_MINT

    # Title
    t_box = slide1.shapes.add_textbox(Inches(1.3), Inches(2.3), Inches(10.7), Inches(1.8))
    tf_t = t_box.text_frame
    tf_t.word_wrap = True
    p1 = tf_t.paragraphs[0]
    p1.text = "AgriVision"
    p1.font.size = Pt(44)
    p1.font.bold = True
    p1.font.color.rgb = TEXT_WHITE

    p2 = tf_t.add_paragraph()
    p2.text = "Software Architecture, Multi-Spectral Remote Sensing & HITL Guardrails"
    p2.font.size = Pt(20)
    p2.font.bold = True
    p2.font.color.rgb = ACCENT_MINT
    p2.space_before = Pt(8)

    p3 = tf_t.add_paragraph()
    p3.text = "Enterprise precision agriculture platform unifying satellite remote sensing, edge IoT telemetry, and autonomous Gemini AI reasoning with Human-in-the-Loop clinical safety guardrails."
    p3.font.size = Pt(13)
    p3.font.color.rgb = TEXT_MUTED
    p3.space_before = Pt(12)

    # Author Card
    auth_card = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(1.3), Inches(4.5), Inches(5.2), Inches(1.2))
    auth_card.fill.solid()
    auth_card.fill.fore_color.rgb = RGBColor(12, 28, 22)
    auth_card.line.color.rgb = CARD_BORDER
    tf_auth = auth_card.text_frame
    p_a1 = tf_auth.paragraphs[0]
    p_a1.text = "SYSTEMS ARCHITECT & SOLE DEVELOPER"
    p_a1.font.size = Pt(9)
    p_a1.font.bold = True
    p_a1.font.color.rgb = ACCENT_CYAN
    p_a2 = tf_auth.add_paragraph()
    p_a2.text = "Muhammad Ahmad"
    p_a2.font.size = Pt(16)
    p_a2.font.bold = True
    p_a2.font.color.rgb = TEXT_WHITE
    p_a2.space_before = Pt(3)
    p_a3 = tf_auth.add_paragraph()
    p_a3.text = "Full-Stack • Firmware • Distributed Backend • Spatial GIS • Mobile"
    p_a3.font.size = Pt(10)
    p_a3.font.color.rgb = TEXT_MUTED

    # Scope Summary Pills
    scope_card = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(4.5), Inches(5.2), Inches(1.2))
    scope_card.fill.solid()
    scope_card.fill.fore_color.rgb = RGBColor(12, 28, 22)
    scope_card.line.color.rgb = CARD_BORDER
    tf_sc = scope_card.text_frame
    p_s1 = tf_sc.paragraphs[0]
    p_s1.text = "COMPREHENSIVE TECHNOLOGY ECOSYSTEM"
    p_s1.font.size = Pt(9)
    p_s1.font.bold = True
    p_s1.font.color.rgb = ACCENT_AMBER
    p_s2 = tf_sc.add_paragraph()
    p_s2.text = "iOS (SwiftUI/MVVM-C) • Cloud Backend (FastAPI/PostGIS/TimescaleDB)"
    p_s2.font.size = Pt(11)
    p_s2.font.bold = True
    p_s2.font.color.rgb = TEXT_WHITE
    p_s2.space_before = Pt(4)
    p_s3 = tf_sc.add_paragraph()
    p_s3.text = "Web GIS Portal (React 19) • Edge Hardware (ESP32-S3 PlatformIO/C++)"
    p_s3.font.size = Pt(11)
    p_s3.font.color.rgb = ACCENT_MINT

    add_footer(slide1, 1)

    # ==========================================
    # SLIDE 2: Platform Mission & Architectural Scope
    # ==========================================
    slide2 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide2)
    add_header(slide2, "STRATEGIC FOUNDATION", "Platform Mission & Architectural Scope",
               "Synthesizing macro satellite earth observation, micro IoT edge telemetry, and multimodal visual diagnostics.")

    # 3 Cards Row: Mission, Stakeholders, Multi-tier Scope
    col_w = Inches(3.7)
    gap = Inches(0.3)
    top_pos = Inches(1.8)
    h_pos = Inches(4.8)

    # Card 1: Core Mission
    tf_m = create_card(slide2, Inches(0.8), top_pos, col_w, h_pos, "Tri-Source Telemetry Synthesis", "CORE MISSION", ACCENT_EMERALD)
    bullets_m = [
        ("Macro Telemetry (Satellite):", " Automated synchronization with Sentinel-2 and AgroMonitoring for 8 spectral indices (NDVI, NDWI, EVI, DSWI, etc.)."),
        ("Micro Telemetry (IoT Sensors):", " Sub-surface telemetry capture via ESP32-S3 nodes measuring volumetric moisture & root-zone soil temperature."),
        ("Visual Telemetry (Multimodal):", " In-field high-resolution visual capture submitted by farmers via mobile for generative AI disease pathology."),
        ("Unified Agronomic Core:", " Cross-correlates multi-tier data points to eradicate diagnostic blind spots and optimize crop yields."),
    ]
    for b_title, b_desc in bullets_m:
        p = tf_m.add_paragraph() if tf_m.paragraphs[0].text else tf_m.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    # Card 2: Stakeholders
    tf_s = create_card(slide2, Inches(0.8) + col_w + gap, top_pos, col_w, h_pos, "Target Stakeholders", "USER ROLES", ACCENT_CYAN)
    bullets_s = [
        ("Field Farmers (iOS Native):", " High-performance offline-first native mobile app for boundary drafting, sensor alerts, and camera diagnostic consultations."),
        ("Certified Agronomists (Web Portal):", " High-density GIS workstation for spatial raster inspection, index time-series analysis, and clinical HITL steering."),
        ("System Administrators:", " Fleet device provisioning, MQTT broker health monitoring, worker queue management, and role-based access audit logs."),
        ("Collaborative Field Tenancy:", " Granular role assignments per field enabling supervised agricultural management."),
    ]
    for b_title, b_desc in bullets_s:
        p = tf_s.add_paragraph() if tf_s.paragraphs[0].text else tf_s.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    # Card 3: Multi-Tier Scope
    tf_t = create_card(slide2, Inches(0.8) + (col_w + gap)*2, top_pos, col_w, h_pos, "Multi-Tier Scope", "SYSTEM STACK", ACCENT_AMBER)
    bullets_t = [
        ("iOS Client:", " SwiftUI / MVVM-Coordinator architecture with Combine state bindings, SwiftData offline cache, and MapKit vector rendering."),
        ("Cloud Backend:", " Asynchronous Python FastAPI gateway, TimescaleDB hypertable telemetry storage, PostGIS spatial computation, Celery workers."),
        ("Web GIS Portal:", " Modern React 19 + TypeScript dashboard leveraging TanStack Query, Leaflet / MapLibre raster rendering, and Tailwind CSS."),
        ("Edge Firmware:", " ESP32-S3 firmware in PlatformIO/C++ implementing MQTT QoS 1 telemetry and hardware fault isolation."),
    ]
    for b_title, b_desc in bullets_t:
        p = tf_t.add_paragraph() if tf_t.paragraphs[0].text else tf_t.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_AMBER
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    add_footer(slide2, 2)

    # ==========================================
    # SLIDE 3: Edge Sensing & IoT Hardware Telemetry Pipeline
    # ==========================================
    slide3 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide3)
    add_header(slide3, "EDGE & EMBEDDED TELEMETRY", "Edge Sensing & IoT Hardware Telemetry Pipeline",
               "Industrial-grade ESP32-S3 sensor nodes with fault protection, MQTT broker ingestion, and TimescaleDB hypertable rollups.")

    left_w = Inches(5.8)
    right_w = Inches(5.6)
    gap_x = Inches(0.33)

    # Left Column: Hardware + Ingestion Topology
    tf_hw = create_card(slide3, Inches(0.8), Inches(1.8), left_w, Inches(2.3), "Embedded Node Hardware Specs", "ESP32-S3 / C++", ACCENT_EMERALD)
    hw_bullets = [
        ("Microcontroller Unit:", " ESP32-S3 dual-core Xtensa LX7 @ 240MHz with 512KB SRAM and integrated 2.4GHz Wi-Fi/BLE."),
        ("Soil Moisture Sensing (GPIO 5):", " Capacitive analog probe with ADC calibration and open/short-circuit detection circuit (ADC < 50mV or > 3250mV flags wire cuts)."),
        ("Soil Temperature (GPIO 6):", " Dallas DS18B20 1-Wire digital probe (-55°C to +125°C, ±0.5°C accuracy) with parasitic/external pull-up verification."),
    ]
    for b_title, b_desc in hw_bullets:
        p = tf_hw.add_paragraph() if tf_hw.paragraphs[0].text else tf_hw.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(3)

    tf_ingest = create_card(slide3, Inches(0.8), Inches(4.3), left_w, Inches(2.3), "Ingestion & Rollup Safeguards", "INGESTION PIPELINE", ACCENT_CYAN)
    ingest_bullets = [
        ("MQTT Ingestion Topology:", " Eclipse Mosquitto broker (QoS 1) -> Async FastAPI background consumers -> TimescaleDB hypertables."),
        ("Batch Writes & Conflict Handling:", " Ingestion batches up to 50 rows via `COPY`/bulk `INSERT ... ON CONFLICT DO NOTHING` on `(sensor_id, time)`."),
        ("Per-Device Flood Limit:", " Token-bucket rate limiter enforces maximum 120 messages per 60 seconds per device ID to prevent DDoS/loops."),
        ("Clock Skew & Rollup Pruning:", " 5-minute skew rejection guard. Automated continuous aggregates compute hourly min/max/mean rollups; 14-day raw data pruning."),
    ]
    for b_title, b_desc in ingest_bullets:
        p = tf_ingest.add_paragraph() if tf_ingest.paragraphs[0].text else tf_ingest.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(3)

    # Right Column: Sequence Diagram Embed or Architecture Card
    seq_img = os.path.join(diagrams_dir, "07_seq_iot_telemetry.png")
    if os.path.exists(seq_img):
        card_r = slide3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8) + left_w + gap_x, Inches(1.8), right_w, Inches(4.8))
        card_r.fill.solid()
        card_r.fill.fore_color.rgb = CARD_BG
        card_r.line.color.rgb = CARD_BORDER
        card_r.line.width = Pt(1)

        t_r = slide3.shapes.add_textbox(Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(1.95), right_w - Inches(0.4), Inches(0.35))
        tf_r = t_r.text_frame
        p_r = tf_r.paragraphs[0]
        p_r.text = "TELEMETRY INGESTION SEQUENCE FLOW"
        p_r.font.size = Pt(11)
        p_r.font.bold = True
        p_r.font.color.rgb = ACCENT_AMBER

        # Insert Image
        slide3.shapes.add_picture(seq_img, Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(2.4), width=right_w - Inches(0.4), height=Inches(4.0))

    add_footer(slide3, 3)

    # ==========================================
    # SLIDE 4: Multi-Spectral Satellite Remote Sensing & GIS Engine
    # ==========================================
    slide4 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide4)
    add_header(slide4, "EARTH OBSERVATION & SPATIAL GIS", "Multi-Spectral Satellite Remote Sensing & GIS Engine",
               "Automated Sentinel-2 / AgroMonitoring synchronization, topological boundary validation, and 8 spectral index rasters.")

    # 3 Column Cards
    col_w4 = Inches(3.7)
    gap4 = Inches(0.3)
    top4 = Inches(1.8)
    h4 = Inches(4.8)

    # Card 1: Vector Boundary Validation
    tf_v = create_card(slide4, Inches(0.8), top4, col_w4, h4, "Vector Boundary Validation", "POSTGIS ENGINE", ACCENT_EMERALD)
    bullets_v = [
        ("PostGIS Georeferencing:", " Fields stored as `ST_Polygon` in SRID 4326 (WGS 84), with automatic planar projection to EPSG:3857 for precise cartography."),
        ("Topological Integrity Checks:", " Rigorous geometry validation via `ST_IsValid()` rejects self-intersecting loops, spikes, and duplicate vertices."),
        ("Area Threshold Enforcement:", " Calculated surface area enforced between 1.0 hectare and 3,000.0 hectares using `ST_Area(geography)`."),
        ("Dynamic Centroid Computation:", " Real-time calculation of visual centroids for weather forecast station anchoring and satellite bounding box queries."),
    ]
    for b_title, b_desc in bullets_v:
        p = tf_v.add_paragraph() if tf_v.paragraphs[0].text else tf_v.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    # Card 2: Constellation Synchronization & Indices
    tf_c = create_card(slide4, Inches(0.8) + col_w4 + gap4, top4, col_w4, h4, "Constellation Synchronization", "SENTINEL-2 / AGRO", ACCENT_CYAN)
    bullets_c = [
        ("Automated Acquisition Pipeline:", " Celery beat workers query European Space Agency (ESA) Sentinel-2 passes via AgroMonitoring APIs every 5 days."),
        ("Cloud Coverage Filtering:", " Ingests only scenes with < 20% cloud cover to guarantee spectral purity and eliminate false cloud anomalies."),
        ("8 Multi-Spectral Indices:", " Full support for NDVI (Canopy Vigour), NDWI (Canopy Water Content), EVI/EVI2 (Atmospheric Corrected Vigour), Truecolor (RGB), Falsecolor (NIR/Red/Green), NRI (Nitrogen Reflectance Index), and DSWI (Drought Stress Water Index)."),
        ("Historic Baseline Profiling:", " Computes 12-month trailing index trajectories for anomalies."),
    ]
    for b_title, b_desc in bullets_c:
        p = tf_c.add_paragraph() if tf_c.paragraphs[0].text else tf_c.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    # Card 3: Dynamic Tile Delivery
    tf_d = create_card(slide4, Inches(0.8) + (col_w4 + gap4)*2, top4, col_w4, h4, "Dynamic Tile Delivery & Proxy", "CLIENT RENDER", ACCENT_AMBER)
    bullets_d = [
        ("Authenticated Tile Proxy:", " FastAPI endpoints `/api/v1/satellite/tiles/{field_id}/{layer}/{z}/{x}/{y}` securely proxy raster data."),
        ("API Key Protection:", " Third-party upstream API keys remain entirely concealed within the private cloud infrastructure."),
        ("Low-Latency In-Memory Caching:", " High-speed caching stores fetched 256x256 Web Mercator raster tiles, reducing upstream latency from 850ms to < 25ms."),
        ("Dual-Client Harmonization:", " Seamless tile consumption across React 19 Leaflet overlays and iOS MapKit `MKTileOverlay` renderers."),
    ]
    for b_title, b_desc in bullets_d:
        p = tf_d.add_paragraph() if tf_d.paragraphs[0].text else tf_d.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_AMBER
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    add_footer(slide4, 4)

    # ==========================================
    # SLIDE 5: Autonomous Generative AI Advisory & RAG Pipeline
    # ==========================================
    slide5 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide5)
    add_header(slide5, "GENERATIVE AI & AGRONOMIC REASONING", "Autonomous Generative AI Advisory & RAG Pipeline",
               "Multimodal plant pathology, localized Punjabi agricultural grounding via Vertex AI Search, and rolling seasonal memory.")

    top5 = Inches(1.8)
    h5 = Inches(4.8)

    # 3 Cards
    tf_ai1 = create_card(slide5, Inches(0.8), top5, col_w4, h5, "Multimodal Camera Diagnostics", "GEMINI VISION", ACCENT_EMERALD)
    bullets_ai1 = [
        ("Native iOS Capture Pipeline:", " Farmers capture diseased foliage or insect infestations directly using the native hardware camera interface."),
        ("Privacy & Optimization Filter:", " Server-side stripping of sensitive EXIF metadata (GPS, serials, timestamps) prior to model ingestion."),
        ("Image Preprocessing:", " Automated bilinear downscaling to max 2048px dimension with progressive JPEG re-encoding (reducing payload by 85%)."),
        ("Dual-Model Vision Inference:", " Gemini 1.5 Pro / Flash vision models identify pathogen symptoms, lesion geometry, and leaf necrosis patterns."),
    ]
    for b_title, b_desc in bullets_ai1:
        p = tf_ai1.add_paragraph() if tf_ai1.paragraphs[0].text else tf_ai1.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    tf_ai2 = create_card(slide5, Inches(0.8) + col_w4 + gap4, top5, col_w4, h5, "Grounded RAG Retrieval", "VERTEX AI SEARCH", ACCENT_CYAN)
    bullets_ai2 = [
        ("Official Local Grounding:", " Real-time semantic vector retrieval indexed against official Punjab Agricultural Extension guides and manuals."),
        ("Pathology & Dosage Knowledge:", " Validates pesticide chemistry, bio-fungicides, fertilizer compatibility, and region-specific sowing calendars."),
        ("Hallucination Suppression:", " Strict system prompt instructions enforce zero hallucination; ungrounded synthetic chemical formulas are strictly rejected."),
        ("Contextual Field Injection:", " Queries are augmented with real-time field state: current soil moisture, 5-day weather forecast, and NDVI score."),
    ]
    for b_title, b_desc in bullets_ai2:
        p = tf_ai2.add_paragraph() if tf_ai2.paragraphs[0].text else tf_ai2.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    tf_ai3 = create_card(slide5, Inches(0.8) + (col_w4 + gap4)*2, top5, col_w4, h5, "Long-Term Season Memory", "ROLLING MEMORY", ACCENT_AMBER)
    bullets_ai3 = [
        ("Field Memory Store:", " `field_season_memory` table maintains an autonomous 1,200-character rolling digest of field crop history."),
        ("Multi-Month Context Awareness:", " Tracks prior fertilizer applications, past pest infestations, soil depletion trends, and agronomist steering notes."),
        ("Autonomous Consolidation:", " Background LLM summarizer compresses conversational turns and clinical decisions after every interaction."),
        ("Continuity Across Cycles:", " Guarantees that advice given in August accounts for chemical treatments and crop rotation applied in May."),
    ]
    for b_title, b_desc in bullets_ai3:
        p = tf_ai3.add_paragraph() if tf_ai3.paragraphs[0].text else tf_ai3.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_AMBER
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    add_footer(slide5, 5)

    # ==========================================
    # SLIDE 6: Human-in-the-Loop (HITL) Safety & Expert Steering
    # ==========================================
    slide6 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide6)
    add_header(slide6, "SAFETY GUARDRAILS & CLINICAL GOVERNANCE", "Human-in-the-Loop (HITL) Safety & Expert Steering",
               "Rule-based chemical policy interception, agronomist clinical triage queue, and authoritative expert steering drawer.")

    # Left Column: Principles & Queue
    tf_hitl_l = create_card(slide6, Inches(0.8), Inches(1.8), left_w, Inches(2.3), "Chemical Interception & Triage Queue", "CLINICAL GATE", ACCENT_ROSE)
    hitl_l_bullets = [
        ("Deterministic Safety Interceptor:", " Rule-based policy engine inspects all raw AI outputs for restricted chemical compounds (e.g. organophosphates, systemic fungicides)."),
        ("Safety Level Classification:", " Any dosage or toxicity recommendation automatically flags `safety_level = 'high_risk'` and marks `expert_status = 'pending'`."),
        ("Delivery Quarantine:", " Toxic recommendations are strictly suppressed from the farmer's mobile interface until an accredited agronomist signs off."),
    ]
    for b_title, b_desc in hitl_l_bullets:
        p = tf_hitl_l.add_paragraph() if tf_hitl_l.paragraphs[0].text else tf_hitl_l.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_ROSE
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(3)

    tf_hitl_s = create_card(slide6, Inches(0.8), Inches(4.3), left_w, Inches(2.3), "Agronomist Portal & Expert Steering", "STEERING DRAWER", ACCENT_EMERALD)
    hitl_s_bullets = [
        ("Clinical Triage Portal (`AIAdvisoryView`):", " Dedicated Web GIS clinical queue where agronomists review raw AI diagnostics alongside satellite imagery & sensor curves."),
        ("Direct Intervention Actions:", " Agronomists can: [1] Approve as-is, [2] Edit dosage/chemistry with clinical notes, or [3] Reject and substitute alternative treatments."),
        ("Authoritative Memory Injection:", " Expert steering drawer directly injects agronomist directives into `field_season_memory`, constraining future AI reasoning loops."),
    ]
    for b_title, b_desc in hitl_s_bullets:
        p = tf_hitl_s.add_paragraph() if tf_hitl_s.paragraphs[0].text else tf_hitl_s.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(3)

    # Right Column: HITL Sequence Diagram Embed
    hitl_img = os.path.join(diagrams_dir, "08_seq_ai_reasoning_hitl.png")
    if os.path.exists(hitl_img):
        card_hr = slide6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8) + left_w + gap_x, Inches(1.8), right_w, Inches(4.8))
        card_hr.fill.solid()
        card_hr.fill.fore_color.rgb = CARD_BG
        card_hr.line.color.rgb = CARD_BORDER
        card_hr.line.width = Pt(1)

        t_hr = slide6.shapes.add_textbox(Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(1.95), right_w - Inches(0.4), Inches(0.35))
        tf_hr = t_hr.text_frame
        p_hr = tf_hr.paragraphs[0]
        p_hr.text = "HITL INTERCEPTION & CLINICAL APPROVAL FLOW"
        p_hr.font.size = Pt(11)
        p_hr.font.bold = True
        p_hr.font.color.rgb = ACCENT_ROSE

        slide6.shapes.add_picture(hitl_img, Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(2.4), width=right_w - Inches(0.4), height=Inches(4.0))

    add_footer(slide6, 6)

    # ==========================================
    # SLIDE 7: Software Engineering Methodology & Resourcing
    # ==========================================
    slide7 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide7)
    add_header(slide7, "DEVELOPMENT METHODOLOGY & QUALITY GATES", "Software Engineering Methodology & Resourcing",
               "High-discipline single-lane Kanban execution across 5 tech stacks with dual-tier automated test verification.")

    # 3 Columns
    tf_meth1 = create_card(slide7, Inches(0.8), top4, col_w4, h4, "Solo Execution Constraints", "5 TECH STACKS", ACCENT_CYAN)
    bullets_m1 = [
        ("Single-Resource Execution:", " Designed, engineered, verified, and deployed entirely by sole developer Muhammad Ahmad."),
        ("Unified Systems Breadth:", " Spans ESP32-S3 C++ firmware, distributed FastAPI services, PostGIS spatial queries, SwiftUI iOS, and React 19 GIS."),
        ("Architectural Modularity:", " Decoupled micro-services and clear contract boundaries prevented dependency lock-in and cognitive overload."),
        ("Full DevOps Ownership:", " Single-handedly authored Docker Compose orchestration, TimescaleDB migrations, and CI test pipelines."),
    ]
    for b_title, b_desc in bullets_m1:
        p = tf_meth1.add_paragraph() if tf_meth1.paragraphs[0].text else tf_meth1.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    tf_meth2 = create_card(slide7, Inches(0.8) + col_w4 + gap4, top4, col_w4, h4, "Work Discipline & Kanban", "WIP LIMIT = 1", ACCENT_AMBER)
    bullets_m2 = [
        ("Single-Lane Kanban Cadence:", " Strict Work-In-Progress (WIP) limit of 1 active subsystem at any given time to eliminate context-switching waste."),
        ("Vertical-Slice Increments:", " Every sprint delivered a fully functional end-to-end slice (sensor -> MQTT -> database -> API -> mobile/web UI)."),
        ("Defect-First Triage:", " Zero tolerance for lingering architectural debt; automated regressions halted forward development until resolved."),
        ("Living Documentation:", " Complete traceability from PRD/SRS requirements to automated test case execution IDs."),
    ]
    for b_title, b_desc in bullets_m2:
        p = tf_meth2.add_paragraph() if tf_meth2.paragraphs[0].text else tf_meth2.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_AMBER
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    tf_meth3 = create_card(slide7, Inches(0.8) + (col_w4 + gap4)*2, top4, col_w4, h4, "Quality Assurance Gates", "392 AUTOMATED TESTS", ACCENT_EMERALD)
    bullets_m3 = [
        ("Automated Test Suite:", " 179 Pytest backend test cases (API routes, GIS math, Celery workers) + 213 XCTest iOS client tests (models, views, coordinators)."),
        ("Strict Static Analysis:", " Automated `oxlint` rule evaluation and zero-warning `tsc -b` TypeScript build enforcement on Web GIS."),
        ("AI-Assisted Pair Audits:", " Integrated Claude / GitHub Copilot audit branches to rigorously review security boundaries, memory leaks, and race conditions."),
        ("Regression Immunity:", " Automated pre-commit hooks ensure zero compilation errors across firmware, backend, web, and iOS targets."),
    ]
    for b_title, b_desc in bullets_m3:
        p = tf_meth3.add_paragraph() if tf_meth3.paragraphs[0].text else tf_meth3.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(11)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(8)

    add_footer(slide7, 7)

    # ==========================================
    # SLIDE 8: Multi-Tier System Architecture
    # ==========================================
    slide8 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide8)
    add_header(slide8, "DISTRIBUTED SYSTEM ARCHITECTURE", "Multi-Tier System Architecture",
               "6-tier decoupled topology with isolated container networks, Firebase JWT auth, and least-privilege security.")

    # Left: 6 Tiers Breakdown
    tf_arch_l = create_card(slide8, Inches(0.8), Inches(1.8), left_w, Inches(4.8), "6 Architectural Tiers & Security", "TIER BREAKDOWN", ACCENT_EMERALD)
    tiers = [
        ("Tier 1 - Client Presentation:", " iOS 17+ Native app (SwiftUI, MVVM-C) + Web GIS Clinical Portal (React 19, TypeScript)."),
        ("Tier 2 - Edge Hardware:", " ESP32-S3 nodes publishing encrypted telemetry over Wi-Fi via MQTT with hardware ADC fault detection."),
        ("Tier 3 - Gateway & Ingestion:", " Mosquitto MQTT Broker + FastAPI ASGI Gateway handling JWT validation, rate limiting, and routing."),
        ("Tier 4 - Domain Services & Workers:", " Celery background workers managing satellite raster sync, weather polling, and continuous telemetry rollups."),
        ("Tier 5 - Persistent Storage:", " PostgreSQL 16 + PostGIS (spatial polygons) + TimescaleDB (sensor hypertables) + Redis (cache/broker)."),
        ("Tier 6 - External Cloud Services:", " Vertex AI Search, Google Gemini Vision 1.5, AgroMonitoring Satellite APIs, Firebase Auth."),
        ("Network Security & Hardening:", " Docker bridge network (`agrivision_net`) isolates databases; non-root user execution; Firebase asymmetric JWT verification on all endpoints."),
    ]
    for b_title, b_desc in tiers:
        p = tf_arch_l.add_paragraph() if tf_arch_l.paragraphs[0].text else tf_arch_l.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(4)

    # Right: Logical Architecture Diagram Embed
    arch_img = os.path.join(diagrams_dir, "04_logical_architecture.png")
    if os.path.exists(arch_img):
        card_ar = slide8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8) + left_w + gap_x, Inches(1.8), right_w, Inches(4.8))
        card_ar.fill.solid()
        card_ar.fill.fore_color.rgb = CARD_BG
        card_ar.line.color.rgb = CARD_BORDER
        card_ar.line.width = Pt(1)

        t_ar = slide8.shapes.add_textbox(Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(1.95), right_w - Inches(0.4), Inches(0.35))
        tf_ar = t_ar.text_frame
        p_ar = tf_ar.paragraphs[0]
        p_ar.text = "LOGICAL ARCHITECTURE & DATA FLOWS"
        p_ar.font.size = Pt(11)
        p_ar.font.bold = True
        p_ar.font.color.rgb = ACCENT_CYAN

        slide8.shapes.add_picture(arch_img, Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(2.4), width=right_w - Inches(0.4), height=Inches(4.0))

    add_footer(slide8, 8)

    # ==========================================
    # SLIDE 9: Data Persistence & ERD Topology
    # ==========================================
    slide9 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide9)
    add_header(slide9, "RELATIONAL & TIME-SERIES PERSISTENCE", "Data Persistence & ERD Topology",
               "22-entity hybrid relational, spatial, and hypertable time-series schema engineered for high-throughput precision agronomy.")

    # Left: Entity Breakdown
    tf_erd_l = create_card(slide9, Inches(0.8), Inches(1.8), left_w, Inches(4.8), "Core Schema Entities & Polyglot Storage", "22 CORE ENTITIES", ACCENT_CYAN)
    erd_entities = [
        ("Spatial Entities (`fields`, `zones`):", " PostGIS `GEOMETRY(Polygon, 4326)` columns with spatial indexing (`GIST`) for rapid containment queries."),
        ("Time-Series Hypertables (`sensor_readings`):", " TimescaleDB chunked hypertable partitioned on `(time, sensor_id)` with compression policies for millions of data points."),
        ("Identity & RBAC (`users`, `user_roles`, `invitations`):", " Multi-tenant role-based access control linking Firebase UID to domain tenancy."),
        ("Telemetry Hardware (`devices`, `sensors`, `device_health`):", " Hardware registry tracking firmware versions, battery voltages, and MAC addresses."),
        ("AI & Clinical Governance (`ai_analysis_runs`, `field_recommendations`):", " Full audit log storing raw Gemini prompts, RAG references, intercepted high-risk dosage flags, and agronomist signature status."),
        ("Continuous Rollups (`sensor_readings_hourly`):", " Materialized views providing pre-computed statistical aggregations for instant dashboard charts."),
    ]
    for b_title, b_desc in erd_entities:
        p = tf_erd_l.add_paragraph() if tf_erd_l.paragraphs[0].text else tf_erd_l.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(5)

    # Right: ERD Diagram Embed
    erd_img = os.path.join(diagrams_dir, "03_database_erd.png")
    if not os.path.exists(erd_img):
        erd_img = "/Users/ahmad/AgriVision/Docs/srs/erd.png"
    if os.path.exists(erd_img):
        card_er = slide9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8) + left_w + gap_x, Inches(1.8), right_w, Inches(4.8))
        card_er.fill.solid()
        card_er.fill.fore_color.rgb = CARD_BG
        card_er.line.color.rgb = CARD_BORDER
        card_er.line.width = Pt(1)

        t_er = slide9.shapes.add_textbox(Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(1.95), right_w - Inches(0.4), Inches(0.35))
        tf_er = t_er.text_frame
        p_er = tf_er.paragraphs[0]
        p_er.text = "ENTITY-RELATIONSHIP (ERD) TOPOLOGY"
        p_er.font.size = Pt(11)
        p_er.font.bold = True
        p_er.font.color.rgb = ACCENT_AMBER

        slide9.shapes.add_picture(erd_img, Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(2.4), width=right_w - Inches(0.4), height=Inches(4.0))

    add_footer(slide9, 9)

    # ==========================================
    # SLIDE 10: Deliverables & Milestones Roadmap
    # ==========================================
    slide10 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide10)
    add_header(slide10, "DELIVERY ROADMAP & EXECUTION TIMELINE", "Deliverables & Milestones Roadmap",
               "10-month systematic milestone execution spanning Jan 2026 to Oct 2026 across all core subsystems.")

    # Left: Phases Timeline List
    tf_rd_l = create_card(slide10, Inches(0.8), Inches(1.8), left_w, Inches(4.8), "Subsystem Execution Milestones", "JAN 2026 - OCT 2026", ACCENT_AMBER)
    milestones = [
        ("Phase 1 (Jan - Feb 2026): Foundation & Mobile Architecture", " Setup FastAPI project skeleton, Docker environment, PostgreSQL/PostGIS databases, and native iOS SwiftUI architecture."),
        ("Phase 2 (Mar - Apr 2026): Edge Hardware & Telemetry Ingestion", " ESP32-S3 sensor firmware development, Mosquitto MQTT broker configuration, and TimescaleDB hypertable ingestion pipelines."),
        ("Phase 3 (May - Jun 2026): Satellite Remote Sensing & GIS Engine", " AgroMonitoring API integration, automated Sentinel-2 synchronization, PostGIS vector validation, and raster tile proxy endpoints."),
        ("Phase 4 (Jul - Aug 2026): AI Advisory, RAG & HITL Interception", " Gemini Vision multimodal model integration, Vertex AI Search RAG knowledge grounding, and clinical safety interception gate."),
        ("Phase 5 (Sep 2026): Agronomist Web GIS Portal (React 19)", " Web GIS dashboard with raster layer overlays, interactive NDVI curves, and the clinical recommendation triage review queue."),
        ("Phase 6 (Oct 2026): Comprehensive QA, Hardening & Deployment", " Complete automated test suite execution (392 tests), security audits, and production container deployment."),
    ]
    for b_title, b_desc in milestones:
        p = tf_rd_l.add_paragraph() if tf_rd_l.paragraphs[0].text else tf_rd_l.paragraphs[0]
        r1 = p.add_run()
        r1.text = "• " + b_title + ":"
        r1.font.bold = True
        r1.font.size = Pt(10)
        r1.font.color.rgb = ACCENT_AMBER
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(9.5)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(4)

    # Right: Gantt Schedule Diagram Embed
    gantt_img = os.path.join(diagrams_dir, "02_gantt_schedule.png")
    if os.path.exists(gantt_img):
        card_gr = slide10.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8) + left_w + gap_x, Inches(1.8), right_w, Inches(4.8))
        card_gr.fill.solid()
        card_gr.fill.fore_color.rgb = CARD_BG
        card_gr.line.color.rgb = CARD_BORDER
        card_gr.line.width = Pt(1)

        t_gr = slide10.shapes.add_textbox(Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(1.95), right_w - Inches(0.4), Inches(0.35))
        tf_gr = t_gr.text_frame
        p_gr = tf_gr.paragraphs[0]
        p_gr.text = "PROJECT GANTT SCHEDULE & MILESTONES"
        p_gr.font.size = Pt(11)
        p_gr.font.bold = True
        p_gr.font.color.rgb = ACCENT_MINT

        slide10.shapes.add_picture(gantt_img, Inches(0.8) + left_w + gap_x + Inches(0.2), Inches(2.4), width=right_w - Inches(0.4), height=Inches(4.0))

    add_footer(slide10, 10)

    # ==========================================
    # SLIDE 11: Summary & System Impact
    # ==========================================
    slide11 = prs.slides.add_slide(blank_slide_layout)
    set_slide_background(slide11)
    add_header(slide11, "EXECUTIVE SUMMARY & FUTURE OUTLOOK", "Summary & System Impact",
               "Delivering state-of-the-art agronomic intelligence with zero-compromise safety, spatial rigor, and production readiness.")

    # 2 Wide Columns: Key Achievements & Future Roadmap
    col_w11 = Inches(5.7)
    gap11 = Inches(0.33)

    tf_sum_l = create_card(slide11, Inches(0.8), Inches(1.8), col_w11, Inches(4.8), "Key Engineering Achievements", "CORE ACCOMPLISHMENTS", ACCENT_EMERALD)
    achievements = [
        ("Operational Tri-Source Telemetry:", " Unified satellite Earth observation (8 spectral layers), sub-surface IoT sensors (ESP32-S3), and farmer visual camera capture into one cohesive system."),
        ("Safety-Guarded Autonomous AI Advisory:", " Gemini multimodal reasoning grounded with official Punjabi agricultural guides and strictly gated behind an agronomist HITL approval workflow."),
        ("High-Performance Spatial & Time-Series Core:", " Sub-millisecond GIS polygon validation via PostGIS and scalable time-series hypertable aggregation via TimescaleDB."),
        ("Dual-Client Enterprise Experience:", " Frictionless offline-first native iOS mobile app for field operations combined with an advanced React 19 GIS clinical workstation for agronomists."),
        ("Robust Software Engineering Rigor:", " 392 automated test cases verifying 100% of critical domain services, zero-leak telemetry ingestion, and strict type safety."),
    ]
    for b_title, b_desc in achievements:
        p = tf_sum_l.add_paragraph() if tf_sum_l.paragraphs[0].text else tf_sum_l.paragraphs[0]
        r1 = p.add_run()
        r1.text = "✔ " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_MINT
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10.5)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(7)

    tf_sum_r = create_card(slide11, Inches(0.8) + col_w11 + gap11, Inches(1.8), col_w11, Inches(4.8), "Future Enhancements & Scalability", "NEXT-PHASE ROADMAP", ACCENT_CYAN)
    future = [
        ("Remote Push Notifications (APNs / FCM):", " Implement real-time background push alerts notifying farmers immediately upon critical frost warnings, drought stress, or agronomist prescription releases."),
        ("Automated Hardware Diagnostics & Over-The-Air (OTA):", " Roll out remote firmware updates over MQTT/HTTPS with automatic rollback and predictive battery failure warnings."),
        ("Edge ML Pathogen Detection:", " Deploy quantized TinyML vision models directly onto ESP32-CAM devices for offline real-time pest trap monitoring."),
        ("Automated Variable-Rate Irrigation Dispatch:", " Direct integration with motorized solenoid valves to trigger closed-loop precision irrigation based on real-time soil moisture rollups."),
        ("Multi-Regional RAG Knowledge Expansion:", " Expand vector retrieval databases to encompass Sindh, KPK, and international agronomic extension authorities."),
    ]
    for b_title, b_desc in future:
        p = tf_sum_r.add_paragraph() if tf_sum_r.paragraphs[0].text else tf_sum_r.paragraphs[0]
        r1 = p.add_run()
        r1.text = "➔ " + b_title
        r1.font.bold = True
        r1.font.size = Pt(11)
        r1.font.color.rgb = ACCENT_CYAN
        r2 = p.add_run()
        r2.text = b_desc
        r2.font.size = Pt(10.5)
        r2.font.color.rgb = TEXT_MUTED
        p.space_after = Pt(7)

    add_footer(slide11, 11)

    prs.save(output_path)
    print(f"Presentation saved successfully to: {output_path}")

if __name__ == "__main__":
    out = "/Users/ahmad/AgriVision/Docs/presentation/AgriVision_Presentation.pptx"
    create_presentation(out)
