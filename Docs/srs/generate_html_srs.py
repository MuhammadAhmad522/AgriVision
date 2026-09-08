#!/usr/bin/env python3
"""
generate_html_srs.py
Converts AgriVision_SRS.md to a self-contained, publication-quality HTML document
with embedded Mermaid.js for client-side vector diagram rendering.
"""

import os
import re
import html

base_dir = "/Users/ahmad/AgriVision/Docs/srs"
md_path = os.path.join(base_dir, "AgriVision_SRS.md")
html_path = os.path.join(base_dir, "AgriVision_SRS.html")

with open(md_path, "r", encoding="utf-8") as f:
    md_content = f.read()

def parse_markdown(text):
    # Protect mermaid blocks
    mermaid_blocks = []
    def save_mermaid(match):
        code = match.group(1).strip()
        idx = len(mermaid_blocks)
        mermaid_blocks.append(code)
        return f"<!--MERMAID_BLOCK_{idx}-->"
    
    text = re.sub(r'```mermaid\n(.*?)\n```', save_mermaid, text, flags=re.DOTALL)
    
    # Protect generic code blocks
    code_blocks = []
    def save_code(match):
        lang = match.group(1) or ""
        code = match.group(2)
        idx = len(code_blocks)
        code_blocks.append((lang, code))
        return f"<!--CODE_BLOCK_{idx}-->"
        
    text = re.sub(r'```(\w*)\n(.*?)\n```', save_code, text, flags=re.DOTALL)

    # Convert horizontal rules
    text = re.sub(r'^---$', '<hr class="chapter-divider" />', text, flags=re.MULTILINE)

    # Convert headers
    text = re.sub(r'^# (.*?)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.*?)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^### (.*?)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^#### (.*?)$', r'<h4>\1</h4>', text, flags=re.MULTILINE)

    # Inline formatting
    text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.*?)\*', r'<em>\1</em>', text)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)

    # Process tables
    def parse_table(match):
        table_text = match.group(0).strip()
        lines = table_text.split('\n')
        if len(lines) < 2:
            return table_text
        
        headers = [c.strip() for c in lines[0].strip('|').split('|')]
        # line 1 is separator
        html_out = ['<div class="table-responsive"><table><thead><tr>']
        for h in headers:
            html_out.append(f'<th>{h}</th>')
        html_out.append('</tr></thead><tbody>')
        
        for row in lines[2:]:
            cols = [c.strip() for c in row.strip('|').split('|')]
            html_out.append('<tr>')
            for c in cols:
                html_out.append(f'<td>{c}</td>')
            html_out.append('</tr>')
        html_out.append('</tbody></table></div>')
        return '\n'.join(html_out)

    text = re.sub(r'(?:^\|.*?\|\n)+', parse_table, text, flags=re.MULTILINE)

    # Lists
    def parse_list(match):
        list_text = match.group(0).strip()
        items = re.findall(r'^\s*[\*\-]\s+(.*?)$', list_text, flags=re.MULTILINE)
        return '<ul>\n' + '\n'.join([f'  <li>{item}</li>' for item in items]) + '\n</ul>'
    
    text = re.sub(r'(?:^\s*[\*\-]\s+.*?\n)+', parse_list, text, flags=re.MULTILINE)

    # Numbered lists
    def parse_num_list(match):
        list_text = match.group(0).strip()
        items = re.findall(r'^\s*\d+\.\s+(.*?)$', list_text, flags=re.MULTILINE)
        return '<ol>\n' + '\n'.join([f'  <li>{item}</li>' for item in items]) + '\n</ol>'
        
    text = re.sub(r'(?:^\s*\d+\.\s+.*?\n)+', parse_num_list, text, flags=re.MULTILINE)

    # Blockquotes (callout notes)
    def parse_blockquote(match):
        body = match.group(0).strip()
        text_lines = [re.sub(r'^\s*>\s?', '', l) for l in body.split('\n')]
        return '<blockquote>' + ' '.join(l for l in text_lines if l.strip()) + '</blockquote>'

    text = re.sub(r'(?:^>.*?\n)+', parse_blockquote, text + '\n', flags=re.MULTILINE).rstrip('\n')

    # Paragraphs (lines that aren't tags)
    lines = text.split('\n\n')
    parsed_paras = []
    for para in lines:
        p = para.strip()
        if not p:
            continue
        if p.startswith(('<h', '<ul', '<ol', '<div', '<hr', '<blockquote', '<!--')):
            parsed_paras.append(p)
        else:
            parsed_paras.append(f'<p>{p}</p>')
    text = '\n\n'.join(parsed_paras)

    # Restore generic code blocks
    for idx, (lang, code) in enumerate(code_blocks):
        escaped_code = html.escape(code)
        block = f'<pre><code class="language-{lang}">{escaped_code}</code></pre>'
        text = text.replace(f"<!--CODE_BLOCK_{idx}-->", block)

    # Restore mermaid blocks
    for idx, code in enumerate(mermaid_blocks):
        escaped_code = html.escape(code)
        block = f'<div class="diagram-wrapper"><div class="mermaid">\n{escaped_code}\n</div></div>'
        text = text.replace(f"<!--MERMAID_BLOCK_{idx}-->", block)

    return text

parsed_body = parse_markdown(md_content)

html_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgriVision - Software Requirements Specification (SRS)</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {{
      --primary: #059669;
      --primary-dark: #065f46;
      --primary-light: #ecfdf5;
      --text-main: #1e293b;
      --text-muted: #64748b;
      --border-color: #e2e8f0;
      --bg-surface: #ffffff;
      --bg-subtle: #f8fafc;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.7;
      color: var(--text-main);
      background-color: var(--bg-subtle);
      margin: 0;
      padding: 40px 20px;
    }}
    .document-container {{
      max-width: 1040px;
      margin: 0 auto;
      background: var(--bg-surface);
      padding: 60px 80px;
      border-radius: 12px;
      box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.05), 0 2px 6px -1px rgba(0, 0, 0, 0.03);
      border: 1px solid var(--border-color);
    }}
    h1 {{
      font-size: 2.2rem;
      font-weight: 700;
      color: var(--primary-dark);
      border-bottom: 2px solid var(--primary);
      padding-bottom: 12px;
      margin-top: 48px;
      margin-bottom: 24px;
    }}
    .document-container > h1:first-of-type {{
      font-size: 2.7rem;
      text-align: center;
      border-bottom: none;
      color: #0f172a;
      margin-top: 0;
      margin-bottom: 40px;
    }}
    h2 {{
      font-size: 1.5rem;
      font-weight: 600;
      color: #0f172a;
      margin-top: 36px;
      margin-bottom: 16px;
      padding-bottom: 6px;
      border-bottom: 1px solid var(--border-color);
    }}
    h3 {{
      font-size: 1.2rem;
      font-weight: 600;
      color: #334155;
      margin-top: 24px;
      margin-bottom: 12px;
    }}
    h4 {{
      font-size: 1.05rem;
      font-weight: 600;
      color: #475569;
      margin-top: 20px;
      margin-bottom: 8px;
    }}
    p, li {{
      font-size: 1.02rem;
      color: #334155;
    }}
    ul, ol {{
      padding-left: 28px;
      margin-bottom: 20px;
    }}
    li {{
      margin-bottom: 8px;
    }}
    code {{
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.9em;
      background: #f1f5f9;
      color: #0f172a;
      padding: 2px 6px;
      border-radius: 4px;
      border: 1px solid #e2e8f0;
    }}
    pre {{
      background: #0f172a;
      color: #f8fafc;
      padding: 18px 24px;
      border-radius: 8px;
      overflow-x: auto;
      font-size: 0.92rem;
      line-height: 1.5;
    }}
    pre code {{
      background: transparent;
      color: inherit;
      padding: 0;
      border: none;
    }}
    .table-responsive {{
      overflow-x: auto;
      margin: 28px 0;
      border: 1px solid var(--border-color);
      border-radius: 8px;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      text-align: left;
      font-size: 0.95rem;
    }}
    th {{
      background-color: #f8fafc;
      color: #0f172a;
      font-weight: 600;
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-color);
    }}
    td {{
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-color);
      color: #334155;
      vertical-align: top;
    }}
    tr:last-child td {{
      border-bottom: none;
    }}
    tr:hover td {{
      background-color: #f8fafc;
    }}
    .chapter-divider {{
      border: 0;
      height: 1px;
      background: linear-gradient(to right, transparent, #cbd5e1, transparent);
      margin: 50px 0;
    }}
    blockquote {{
      margin: 20px 0;
      padding: 14px 20px;
      background: var(--primary-light);
      border-left: 4px solid var(--primary);
      border-radius: 0 6px 6px 0;
      color: #334155;
      font-size: 1.0rem;
    }}
    .diagram-wrapper {{
      /* Diagrams break out of the 1040px prose measure: dense architecture and class
         diagrams need the pixels, while body text stays at a readable line length. */
      width: min(1600px, calc(100vw - 80px));
      margin: 32px 0 32px 50%;
      transform: translateX(-50%);
      padding: 24px;
      background: #ffffff;
      border: 1px solid var(--border-color);
      border-radius: 8px;
      display: flex;
      justify-content: center;
      align-items: center;
      overflow-x: auto;
      box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.05);
    }}
    .mermaid {{
      text-align: center;
      width: 100%;
    }}
    .mermaid svg {{
      height: auto;
    }}
    @media print {{
      body {{
        background: white;
        padding: 0;
      }}
      .document-container {{
        box-shadow: none;
        border: none;
        padding: 0;
        max-width: 100%;
      }}
      h1 {{
        page-break-before: always;
      }}
      .document-container > h1:first-of-type {{
        page-break-before: avoid;
      }}
      .diagram-wrapper {{
        box-shadow: none;
        page-break-inside: avoid;
      }}
      table {{
        page-break-inside: avoid;
      }}
    }}
  </style>
</head>
<body>
  <div class="document-container">
    {parsed_body}
  </div>

  <!-- Local bundle first so the document renders without network access; CDN is the fallback. -->
  <script src="mermaid.min.js"></script>
  <script>
    if (typeof mermaid === 'undefined') {{
      document.write('<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"><' + '/script>');
    }}
  </script>
  <script>
    window.addEventListener('load', async function () {{
      if (typeof mermaid === 'undefined') {{
        console.error('Mermaid failed to load from both the local bundle and the CDN.');
        return;
      }}
      mermaid.initialize({{
        startOnLoad: false,
        theme: 'neutral',
        securityLevel: 'loose',
        fontFamily: 'Inter, sans-serif',
        maxTextSize: 200000
      }});
      try {{
        await mermaid.run({{ querySelector: '.mermaid' }});
      }} catch (err) {{
        console.error('Mermaid rendering failed:', err);
      }}
    }});
  </script>
</body>
</html>
"""

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_template)

print(f"Successfully generated clean HTML SRS at: {html_path}")
