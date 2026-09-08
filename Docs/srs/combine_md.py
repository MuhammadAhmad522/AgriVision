import os

files = [
    "1_Scope_of_the_Project.md",
    "2_Requirements.md",
    "3_Use_Cases.md",
    "4_5_Methodology_and_WorkPlan.md",
    "6_7_ERD_and_Architecture.md",
    "8_9_Sequence_and_Class.md",
    "10_Interface_Design.md"
]
base_dir = "/Users/ahmad/AgriVision/Docs/srs"
output_path = os.path.join(base_dir, "AgriVision_SRS.md")

DOC_HEADER = '# AgriVision Software Requirements Specification (SRS)\n\n* **Project:** AgriVision — Precision Agriculture & Agronomic Intelligence Platform\n* **Document Version:** 2.0 (codebase-verified revision)\n* **Date:** 7 September 2026\n* **Author & Sole Developer:** Muhammad Ahmad\n* **Repository Scope:** `AgriVision/` (iOS client) · `AgriVision-Backend/` (FastAPI, GIS & AI services) · `AgriVision-Web/` (React 19 portal) · `esp/` (ESP32-S3 firmware)\n\n> **Verification basis.** Every requirement, diagram, schema and figure in this document was reconciled against the implementation as it stands at commit `1b3e427` (7 September 2026). Where a capability is specified but not yet built, the text says so explicitly rather than implying it exists.\n\n---\n\n'

with open(output_path, "w") as outfile:
    outfile.write(DOC_HEADER)
    for file_name in files:
        file_path = os.path.join(base_dir, file_name)
        if os.path.exists(file_path):
            with open(file_path, "r") as infile:
                outfile.write(infile.read())
                outfile.write("\n\n---\n\n")

print(f"Successfully combined files into {output_path}")
