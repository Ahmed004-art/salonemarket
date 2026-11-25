import os
from docx import Document
from PIL import Image, ImageFont

DOCX_PATH = r"c:\Users\MOK\Downloads\salonemarket\docs\final_report\SaloneMarket_Final_Project_Report.docx"
FONT_REG = ImageFont.truetype(r"C:\Windows\Fonts\tahoma.ttf", 12)
FONT_BOLD = ImageFont.truetype(r"C:\Windows\Fonts\tahomabd.ttf", 12)

# A4: 210mm x 297mm = 595.28pt x 841.89pt; 1 in margins = 72pt
PRINT_W_PT = 595.28 - 144.0   # 451.28 pt
PRINT_H_PT = 841.89 - 144.0   # 697.89 pt
LINE_H_PT = 14.4 * 1.5  # Tahoma 12pt single line ~14.4pt -> 1.5x = 21.6 pt/line in Word

def wrap_lines(text, font, max_w_pt):
    if not text.strip():
        return 1
    words = text.split()
    lines = 1
    cur = ""
    for w in words:
        cand = (cur + " " + w).strip()
        if font.getlength(cand) <= max_w_pt:
            cur = cand
        else:
            lines += 1
            cur = w
    return lines

doc = Document(DOCX_PATH)
pages = 1
cur_y = 0.0
chapter_pages = []
cur_chap = "Title Page"
chap_start = 1

def new_page(reason=""):
    global pages, cur_y
    pages += 1
    cur_y = 0.0

for block in doc.element.body:
    tag = block.tag.split("}")[-1]
    if tag == "p":
        # Check for page break
        xml_str = block.xml
        if 'w:type="page"' in xml_str:
            chapter_pages.append((cur_chap, chap_start, pages, round(cur_y, 1)))
            new_page("explicit_break")
            chap_start = pages
            continue

        text = "".join(t.text or "" for t in block.iter() if t.tag.endswith("}t"))
        if text.startswith("CHAPTER ") or text == "REFERENCES":
            cur_chap = text

        # Check for embedded drawing
        if "blip" in xml_str:
            # Find extent cy in EMUs (914400 EMU = 1 inch = 72 pt)
            import re
            m = re.search(r'<wp:extent[^>]*cy="(\d+)"', xml_str)
            if m:
                h_pt = int(m.group(1)) / 914400.0 * 72.0 + 10.0
                if cur_y + h_pt > PRINT_H_PT:
                    new_page("image")
                cur_y += h_pt
                continue

        is_bold = "<w:b/>" in xml_str or "<w:b " in xml_str
        f = FONT_BOLD if is_bold else FONT_REG
        n_lines = wrap_lines(text, f, PRINT_W_PT)
        h_pt = n_lines * LINE_H_PT + 6.0
        if cur_y + h_pt > PRINT_H_PT:
            new_page("para")
        cur_y += h_pt

    elif tag == "tbl":
        # Estimate table height
        rows = [r for r in block if r.tag.endswith("}tr")]
        xml_str = block.xml
        if "blip" in xml_str:
            import re
            ys = [int(x) for x in re.findall(r'<wp:extent[^>]*cy="(\d+)"', xml_str)]
            h_pt = (max(ys) / 914400.0 * 72.0 if ys else 200.0) + 14.0
        else:
            h_pt = len(rows) * 34.0 + 10.0
        if cur_y + h_pt > PRINT_H_PT:
            new_page("table")
        cur_y += h_pt

chapter_pages.append((cur_chap, chap_start, pages, round(cur_y, 1)))
print(f"ESTIMATED_TOTAL_PAGES: {pages}")
for name, s, e, last_y in chapter_pages:
    print(f"  {name}: pages {s}-{e} (last page fill: {last_y}/{PRINT_H_PT:.0f} pt)")
