import os

source_file = "AgriVision/Features/Dashboard/Views/DashboardView.swift"
components_dir = "AgriVision/Features/Dashboard/Views/Components"

structs_to_extract = [
    "DataAvailabilityCard",
    "DashboardHeaderView",
    "WeatherCardShape",
    "WeatherCardView",
    "SoilTempCardView",
    "HealthCardView",
    "LiquidGlassCard",
    "MoistureCardView",
    "PHLevelCardView",
    "NDVICardView",
    "SensorLiveCardView",
    "VegetationIndicesCardView",
    "UVIndexCardView",
    "SatelliteQualityCardView",
    "ForecastCardView",
    "SensorChemistryCardView",
    "SatelliteImageCardView",
    "AlertsBottomSheet",
    "AlertRow"
]

def extract_components():
    with open(source_file, "r") as f:
        lines = f.readlines()

    out_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check if line starts a struct we want to extract
        found_struct = None
        for s in structs_to_extract:
            if line.startswith(f"struct {s}") or line.startswith(f"private struct {s}") or line.startswith(f"struct {s}<"):
                found_struct = s
                break
                
        if found_struct:
            # Found a struct, parse to the end of it
            struct_lines = [line]
            brace_count = line.count("{") - line.count("}")
            i += 1
            while i < len(lines) and brace_count > 0:
                l = lines[i]
                struct_lines.append(l)
                brace_count += l.count("{") - l.count("}")
                i += 1
                
            # Write to component file
            comp_path = os.path.join(components_dir, f"{found_struct}.swift")
            with open(comp_path, "w") as cf:
                cf.write("import SwiftUI\n")
                if "Chart" in "".join(struct_lines):
                    cf.write("import Charts\n")
                cf.write("\n")
                
                # if private struct, remove private for extraction
                if struct_lines[0].startswith("private struct"):
                    struct_lines[0] = struct_lines[0].replace("private struct", "struct", 1)
                    
                cf.writelines(struct_lines)
            print(f"Extracted {found_struct} to {comp_path}")
            continue
            
        out_lines.append(line)
        i += 1

    with open(source_file, "w") as f:
        f.writelines(out_lines)
        
    print("DashboardView.swift updated.")

if __name__ == "__main__":
    os.makedirs(components_dir, exist_ok=True)
    extract_components()
