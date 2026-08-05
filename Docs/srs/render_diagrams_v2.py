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
    # MUST strip trailing '=' for Kroki to accept it!
    return base64.urlsafe_b64encode(compressed).decode('ascii').rstrip('=')

combined_md = "# AgriVision Software Requirements Specification (SRS)\n\n"
for file_name in files:
    file_path = os.path.join(base_dir, file_name)
    if os.path.exists(file_path):
        with open(file_path, "r") as infile:
            combined_md += infile.read() + "\n\n---\n\n"

pattern = re.compile(r'```(mermaid|plantuml)\n(.*?)\n```', re.DOTALL)

def replace_block(match):
    diag_type = match.group(1)
    code = match.group(2)
    encoded = encode_kroki(code)
    # Using SVG for perfect scaling directly inline in HTML
    url = f"https://kroki.io/{diag_type}/svg/{encoded}"
    
    print(f"Downloading {diag_type} from Kroki...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            svg_data = response.read().decode('utf-8')
        
        # Wrap SVG in a div for Markdown safety
        return f'\n<div class="diagram-container" style="text-align: center; margin: 20px 0; overflow: auto;">\n{svg_data}\n</div>\n'
    except Exception as e:
        print(f"Failed to download {diag_type}: {e}")
        return f"```\nError rendering diagram: {e}\n```"

print("Parsing markdown and fetching diagrams from Kroki API...")
rendered_md = pattern.sub(replace_block, combined_md)

# Inject some basic CSS for the final HTML
css_injection = """
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 1000px; margin: 0 auto; padding: 20px; color: #333; }
  h1, h2, h3 { color: #2c3e50; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
  table { border-collapse: collapse; width: 100%; margin: 20px 0; }
  th, td { border: 1px solid #dfe2e5; padding: 8px 12px; }
  th { background-color: #f6f8fa; }
  svg { max-width: 100%; height: auto; }
</style>
"""

out_path = os.path.join(base_dir, "AgriVision_SRS_Inline.md")
with open(out_path, "w") as f:
    f.write(css_injection + "\n\n" + rendered_md)

print("Saved intermediate markdown with inline SVGs!")
