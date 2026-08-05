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

with open(output_path, "w") as outfile:
    outfile.write("# AgriVision Software Requirements Specification (SRS)\n\n")
    for file_name in files:
        file_path = os.path.join(base_dir, file_name)
        if os.path.exists(file_path):
            with open(file_path, "r") as infile:
                outfile.write(infile.read())
                outfile.write("\n\n---\n\n")

print(f"Successfully combined files into {output_path}")
