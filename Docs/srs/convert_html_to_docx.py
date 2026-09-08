#!/usr/bin/env python3
"""
convert_html_to_docx.py
Converts AgriVision_SRS.html into an exact, beautifully styled Microsoft Word (.docx) document,
including all 16 embedded high-resolution diagrams, formatted tables, lists, and typography.
"""

import os
import re
import html
from bs4 import BeautifulSoup, NavigableString, Tag
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

HTML_FILE = "/Users/ahmad/AgriVision/Docs/srs/AgriVision_SRS.html"
DOCX_FILE = "/Users/ahmad/AgriVision/Docs/srs/AgriVision_SRS.docx"

DIAGRAM_IMAGES = [
    "/tmp/srs_diagrams/diag_00.jpg",
    "/tmp/srs_diagrams/diag_01.jpg",
    "/tmp/srs_diagrams/diag_02.jpg",
    "/Users/ahmad/AgriVision/Docs/srs/erd.png",
    "/tmp/srs_diagrams/diag_04.jpg",
    "/tmp/srs_diagrams/diag_05.jpg",
    "/tmp/srs_diagrams/diag_06.jpg",
    "/tmp/srs_diagrams/diag_07.jpg",
    "/tmp/srs_diagrams/diag_08.jpg",
    "/tmp/srs_diagrams/diag_09.jpg",
    "/tmp/srs_diagrams/diag_10.jpg",
    "/Users/ahmad/AgriVision/Docs/srs/diagrams/13_class_backend.png",
    "/tmp/srs_diagrams/diag_12.jpg",
    "/tmp/srs_diagrams/diag_13.jpg",
    "/tmp/srs_diagrams/diag_14.jpg",
    "/Users/ahmad/AgriVision/Docs/srs/diagrams/11_class_ios_client.png",
]

# Color constants
COLOR_PRIMARY_DARK = RGBColor(6, 95, 70)     # #065f46
COLOR_TEXT_MAIN = RGBColor(30, 41, 59)        # #1e293b
COLOR_TEXT_MUTED = RGBColor(100, 116, 139)    # #64748b
COLOR_CODE_TEXT = RGBColor(15, 23, 42)        # #0f172a
COLOR_BORDER_HEX = "E2E8F0"
COLOR_HEADER_BG_HEX = "F8FAFC"
COLOR_CODE_BG_HEX = "F1F5F9"
COLOR_QUOTE_BG_HEX = "ECFDF5"

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def set_table_borders(table, color="CBD5E1"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="single" w:sz="4" w:space="0" w:color="{color}"/>'
        f'<w:bottom w:val="single" w:sz="4" w:space="0" w:color="{color}"/>'
        f'<w:left w:val="none"/>'
        f'<w:right w:val="none"/>'
        f'<w:insideH w:val="single" w:sz="4" w:space="0" w:color="{color}"/>'
        f'<w:insideV w:val="none"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def add_inline_runs(paragraph, node, bold=False, italic=False, is_code=False):
    """Recursively parses child nodes and adds formatted runs to paragraph."""
    if isinstance(node, NavigableString):
        text = str(node)
        if text:
            # Replace non-breaking spaces
            text = text.replace('\xa0', ' ')
            run = paragraph.add_run(text)
            if bold:
                run.bold = True
            if italic:
                run.italic = True
            if is_code:
                run.font.name = "Courier New"
                run.font.size = Pt(9.0)
                run.font.color.rgb = COLOR_CODE_TEXT
            else:
                run.font.color.rgb = COLOR_TEXT_MAIN
        return

    if not isinstance(node, Tag):
        return

    tag_name = node.name.lower()
    cur_bold = bold or (tag_name in ['strong', 'b'])
    cur_italic = italic or (tag_name in ['em', 'i'])
    cur_code = is_code or (tag_name in ['code', 'kbd'])

    if tag_name == 'br':
        paragraph.add_run('\n')
        return

    for child in node.children:
        add_inline_runs(paragraph, child, bold=cur_bold, italic=cur_italic, is_code=cur_code)

def main():
    print("Reading HTML file...")
    with open(HTML_FILE, 'r', encoding='utf-8') as f:
        html_content = f.read()

    soup = BeautifulSoup(html_content, 'html.parser')
    container = soup.find('div', class_='document-container')
    if not container:
        container = soup.body if soup.body else soup

    doc = Document()

    # Set page margins to 0.75 in (54 pt) to maximize layout room for tables and diagrams
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)
        section.page_width = Inches(8.5)
        section.page_height = Inches(11.0)

    # Set normal style font
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = COLOR_TEXT_MAIN
    normal_style.paragraph_format.line_spacing = 1.15
    normal_style.paragraph_format.space_after = Pt(4)

    diagram_idx = 0

    print("Iterating over DOM elements...")
    for elem in container.children:
        if isinstance(elem, NavigableString):
            txt = str(elem).strip()
            if txt:
                p = doc.add_paragraph()
                p.add_run(txt)
            continue

        if not isinstance(elem, Tag):
            continue

        tag = elem.name.lower()

        # Check for diagram wrapper
        if tag == 'div' and ('diagram-wrapper' in elem.get('class', []) or 'mermaid-diagram-card' in elem.get('class', [])):
            if diagram_idx < len(DIAGRAM_IMAGES):
                img_path = DIAGRAM_IMAGES[diagram_idx]
                if os.path.exists(img_path):
                    p = doc.add_paragraph()
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    p.paragraph_format.space_before = Pt(8)
                    p.paragraph_format.space_after = Pt(12)
                    run = p.add_run()
                    # Scale image to fit width (max 6.8 inches)
                    run.add_picture(img_path, width=Inches(6.8))
                    print(f"  Inserted diagram {diagram_idx + 1:02d}: {os.path.basename(img_path)}")
                else:
                    print(f"  Missing diagram file: {img_path}")
                diagram_idx += 1
            continue

        # Check for standalone mermaid div
        if tag == 'div' and 'mermaid' in elem.get('class', []):
            if diagram_idx < len(DIAGRAM_IMAGES):
                img_path = DIAGRAM_IMAGES[diagram_idx]
                if os.path.exists(img_path):
                    p = doc.add_paragraph()
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    p.paragraph_format.space_before = Pt(8)
                    p.paragraph_format.space_after = Pt(12)
                    run = p.add_run()
                    run.add_picture(img_path, width=Inches(6.8))
                    print(f"  Inserted diagram {diagram_idx + 1:02d}: {os.path.basename(img_path)}")
                diagram_idx += 1
            continue

        # Headings
        if tag == 'h1':
            is_title = (elem == container.find('h1'))
            p = doc.add_paragraph()
            p.paragraph_format.keep_with_next = True
            if is_title:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.paragraph_format.space_before = Pt(12)
                p.paragraph_format.space_after = Pt(16)
                add_inline_runs(p, elem)
                for run in p.runs:
                    run.font.size = Pt(24)
                    run.font.bold = True
                    run.font.color.rgb = COLOR_PRIMARY_DARK
            else:
                p.paragraph_format.space_before = Pt(20)
                p.paragraph_format.space_after = Pt(6)
                add_inline_runs(p, elem)
                for run in p.runs:
                    run.font.size = Pt(18)
                    run.font.bold = True
                    run.font.color.rgb = COLOR_PRIMARY_DARK
            continue

        if tag == 'h2':
            p = doc.add_paragraph()
            p.paragraph_format.keep_with_next = True
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(4)
            add_inline_runs(p, elem)
            for run in p.runs:
                run.font.size = Pt(14)
                run.font.bold = True
                run.font.color.rgb = COLOR_CODE_TEXT
            continue

        if tag == 'h3':
            p = doc.add_paragraph()
            p.paragraph_format.keep_with_next = True
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(3)
            add_inline_runs(p, elem)
            for run in p.runs:
                run.font.size = Pt(12)
                run.font.bold = True
                run.font.color.rgb = COLOR_TEXT_MAIN
            continue

        if tag == 'h4':
            p = doc.add_paragraph()
            p.paragraph_format.keep_with_next = True
            p.paragraph_format.space_before = Pt(8)
            p.paragraph_format.space_after = Pt(2)
            add_inline_runs(p, elem)
            for run in p.runs:
                run.font.size = Pt(11)
                run.font.bold = True
                run.font.color.rgb = COLOR_TEXT_MUTED
            continue

        # Paragraph
        if tag == 'p':
            p = doc.add_paragraph()
            p.paragraph_format.space_after = Pt(5)
            add_inline_runs(p, elem)
            continue

        # Blockquote
        if tag == 'blockquote':
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.4)
            p.paragraph_format.right_indent = Inches(0.2)
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(6)
            add_inline_runs(p, elem, italic=True)
            for run in p.runs:
                run.font.color.rgb = COLOR_PRIMARY_DARK
            continue

        # Code block (pre)
        if tag == 'pre':
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.3)
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(6)
            run = p.add_run(elem.get_text())
            run.font.name = "Courier New"
            run.font.size = Pt(9.0)
            run.font.color.rgb = COLOR_CODE_TEXT
            continue

        # Lists
        if tag in ['ul', 'ol']:
            is_ordered = (tag == 'ol')
            for li_idx, li in enumerate(elem.find_all('li', recursive=False)):
                p = doc.add_paragraph(style='List Number' if is_ordered else 'List Bullet')
                p.paragraph_format.space_after = Pt(3)
                add_inline_runs(p, li)
            continue

        # Table container or table
        table_elem = elem if tag == 'table' else elem.find('table')
        if table_elem:
            rows = table_elem.find_all('tr')
            if not rows:
                continue

            # Determine max cols
            max_cols = max(len(r.find_all(['th', 'td'])) for r in rows)
            doc_table = doc.add_table(rows=len(rows), cols=max_cols)
            doc_table.alignment = WD_TABLE_ALIGNMENT.CENTER
            set_table_borders(doc_table)

            for r_idx, row in enumerate(rows):
                doc_row = doc_table.rows[r_idx]
                # Keep row together on page
                trPr = doc_row._tr.get_or_add_trPr()
                trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))

                cells = row.find_all(['th', 'td'])
                is_header = bool(row.find('th')) or (r_idx == 0)

                if is_header:
                    trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))

                for c_idx, cell in enumerate(cells):
                    if c_idx >= max_cols:
                        break
                    doc_cell = doc_row.cells[c_idx]
                    doc_cell.vertical_alignment = WD_ALIGN_VERTICAL.TOP
                    set_cell_margins(doc_cell, top=100, bottom=100, left=140, right=140)

                    if is_header:
                        set_cell_background(doc_cell, COLOR_HEADER_BG_HEX)

                    p = doc_cell.paragraphs[0]
                    p.paragraph_format.space_after = Pt(2)
                    p.paragraph_format.line_spacing = 1.1
                    add_inline_runs(p, cell, bold=is_header)
                    if is_header:
                        for run in p.runs:
                            run.font.bold = True
                            run.font.size = Pt(9.5)

            p_after = doc.add_paragraph()
            p_after.paragraph_format.space_before = Pt(4)
            p_after.paragraph_format.space_after = Pt(4)
            continue

        # Horizontal rule / page break
        if tag == 'hr':
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(12)
            p.paragraph_format.space_after = Pt(12)
            # Add thin divider
            continue

    print(f"Saving DOCX to {DOCX_FILE}...")
    doc.save(DOCX_FILE)
    file_size = os.path.getsize(DOCX_FILE)
    print(f"Successfully generated DOCX! Size: {file_size:,} bytes")

if __name__ == "__main__":
    main()
