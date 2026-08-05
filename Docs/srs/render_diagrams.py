import os
import re
import zlib
import base64
import urllib.request

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

def encode_kroki(text):
    compressed = zlib.compress(text.encode('utf-8'), 9)
    return base64.urlsafe_b64encode(compressed).decode('ascii')

combined_md = "# AgriVision Software Requirements Specification (SRS)\n\n"
for file_name in files:
    file_path = os.path.join(base_dir, file_name)
    if os.path.exists(file_path):
        with open(file_path, "r") as infile:
            combined_md += infile.read() + "\n\n---\n\n"

# Regex to find plantuml and mermaid blocks
pattern = re.compile(r'```(mermaid|plantuml)\n(.*?)\n```', re.DOTALL)

counter = 1
def replace_block(match):
    global counter
    diag_type = match.group(1)
    code = match.group(2)
    
    # KROKI API
    encoded = encode_kroki(code)
    url = f"https://kroki.io/{diag_type}/png/{encoded}"
    
    img_filename = f"diagram_{counter}.png"
    img_path = os.path.join(base_dir, img_filename)
    
    print(f"Downloading {diag_type} diagram to {img_filename}...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response, open(img_path, 'wb') as out_file:
            out_file.write(response.read())
        
        replacement = f"![{diag_type} diagram]({img_filename})"
    except Exception as e:
        print(f"Failed to download {img_filename}: {e}")
        replacement = f"```\nError rendering diagram\n```"
        
    counter += 1
    return replacement

rendered_md = pattern.sub(replace_block, combined_md)

out_path = os.path.join(base_dir, "AgriVision_SRS_rendered.md")
with open(out_path, "w") as f:
    f.write(rendered_md)

print("Diagrams rendered and markdown saved!")
