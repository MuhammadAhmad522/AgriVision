import os

source_file = "AgriVision/Features/Settings/Views/SettingsView.swift"
components_dir = "AgriVision/Features/Settings/Views/Components"

structs_to_extract = [
    "SettingsInfoRow",
    "StatusPill",
    "EditProfileSheet",
    "SensorPairingSheet"
]

def extract_components():
    with open(source_file, "r") as f:
        lines = f.readlines()

    out_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        found_struct = None
        for s in structs_to_extract:
            if line.startswith(f"struct {s}") or line.startswith(f"private struct {s}") or line.startswith(f"struct {s}<"):
                found_struct = s
                break
                
        if found_struct:
            struct_lines = [line]
            brace_count = line.count("{") - line.count("}")
            i += 1
            while i < len(lines) and brace_count > 0:
                l = lines[i]
                struct_lines.append(l)
                brace_count += l.count("{") - l.count("}")
                i += 1
                
            comp_path = os.path.join(components_dir, f"{found_struct}.swift")
            with open(comp_path, "w") as cf:
                cf.write("import SwiftUI\n\n")
                if struct_lines[0].startswith("private struct"):
                    struct_lines[0] = struct_lines[0].replace("private struct", "struct", 1)
                cf.writelines(struct_lines)
            print(f"Extracted {found_struct} to {comp_path}")
            continue
            
        out_lines.append(line)
        i += 1

    with open(source_file, "w") as f:
        f.writelines(out_lines)
        
    print("SettingsView.swift updated.")

if __name__ == "__main__":
    os.makedirs(components_dir, exist_ok=True)
    extract_components()
