# SaloneMarket Final Project Report — Completion Summary

## Deliverables Produced

| Deliverable | Path | Status |
|---|---|---|
| Editable Word Report | [`docs/final_report/SaloneMarket_Final_Project_Report.docx`](SaloneMarket_Final_Project_Report.docx) | Generated (A4, Tahoma 12 pt, 1.5 line spacing, 1-inch margins) |
| Genuine App Screenshots | [`docs/final_report/report_screenshots/`](report_screenshots/) | 6 screenshots captured from running Flutter app (`http://localhost:8085`) |
| Architecture & Lifecycle Diagrams | [`docs/final_report/diagrams/`](diagrams/) | 3 diagrams + Title Page logo PNG |
| PDF Rendering (`SaloneMarket_Final_Project_Report.pdf`) | — | Not generated: neither Microsoft Word COM (`WINWORD.EXE` not registered) nor LibreOffice (`soffice`) is installed in this environment |

---

## Page Count & Formatting Verification

- **Page Size:** A4 (`210 mm × 297 mm`), 1-inch margins on all four sides.
- **Typography & Spacing:** `Tahoma` `12 pt` across all body text, headings (bold + brand colour), tables, captions, references, and page-number footers; `1.5` line spacing; justified body paragraphs.
- **Estimated Rendered Page Count:** **18 pages** (last page fill `304.8 / 698.0 pt`, enlarged per user request for maximum screenshot and diagram readability), verified via [`verify_layout.py`](verify_layout.py) using `C:\Windows\Fonts\tahoma.ttf` glyph widths and exact embedded image dimensions. Open in Microsoft Word to confirm exact final pagination on your machine.

---

## Report Structure

1. **Title Page** — SaloneMarket logo, academic title, repository URL, and student/institution placeholders.
2. **Chapter One: Introduction** — Background, Problem Statement, Aim & Objectives, Scope, Significance.
3. **Chapter Two: Literature Review and Business Model** — Mobile Commerce, Sierra Leone context, UN SDGs (Goal 8 & Goal 9), 5% commission business model.
4. **Chapter Three: System Analysis and Design** — Requirements, User Roles table, System Architecture (Figure 3.1), PostgreSQL Database Design (Figure 3.2), User Workflows.
5. **Chapter Four: Implementation** — Technologies, Customer/Vendor/Admin portals, UI/UX & real application screenshots (Figures 4.1–4.3).
6. **Chapter Five: Payment System and Security** — Monime Caph API lifecycle (Figure 5.1), idempotency, atomic settlement, reconciliation, vendor payouts, and security/RLS.
7. **Chapter Six: Testing, Results and Discussion** — Testing approach, functional/payment testing, observed results table, and honest limitations.
8. **Chapter Seven: Conclusion and Recommendations** — Summary and concrete next steps.
9. **References** — 8 verified Harvard-style references matching all in-text citations.

---

## Genuine Application Screenshots (`report_screenshots/`)

1. `01_onboarding.png` — Onboarding Screen 1 (*Discover products around you*)
2. `02_welcome.png` — Welcome Screen (*Direct from local vendors to your door*)
3. `03_login.png` — Customer/User Sign In Screen
4. `04_home.png` — Customer Homepage (brand header, search bar, showcase banner, bottom navigation)
5. `05_search.png` — Product Catalog & Search (live Supabase category chips)
6. `06_cart.png` — Shopping Cart Screen

---

## References Included

- Flutter (2024) *Flutter Documentation*
- GSMA (2024) *State of the Industry Report on Mobile Money 2024*
- Laudon, K.C. and Traver, C.G. (2021) *E-Commerce 2021–2022: Business, Technology, and Society*
- Monime (2025) *Monime Developer Documentation: Payment Codes API (Caph) and Webhook HMAC Verification*
- Supabase (2024) *Supabase Documentation*
- United Nations (2015) *Transforming our world: the 2030 Agenda for Sustainable Development (SDGs 8 and 9)*
- World Bank (2020) *Sierra Leone Digital Economy Diagnostic*
- World Bank (2022) *The Global Findex Database 2021*
