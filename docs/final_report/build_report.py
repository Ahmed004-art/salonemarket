import os
from docx import Document
from docx.shared import Inches, Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

BASE_DIR = r"c:\Users\MOK\Downloads\salonemarket\docs\final_report"
DIAG_DIR = os.path.join(BASE_DIR, "diagrams")
SHOT_DIR = os.path.join(BASE_DIR, "report_screenshots")
OUT_DOCX = os.path.join(BASE_DIR, "SaloneMarket_Final_Project_Report.docx")

# Brand colours
C_FOREST = RGBColor(0x12, 0x3C, 0x35)
C_EMERALD = RGBColor(0x0E, 0x8F, 0x6E)
C_TEXT = RGBColor(0x20, 0x2B, 0x28)
C_MUTED = RGBColor(0x68, 0x75, 0x6F)

FONT_NAME = "Tahoma"
FONT_SIZE = Pt(12)


def set_cell_shading(cell, hex_color):
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    cell._tc.get_or_add_tcPr().append(shading)


def set_cell_margins(cell, top=80, bottom=80, left=120, right=120):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement("w:tcMar")
    for m, val in [("top", top), ("bottom", bottom), ("left", left), ("right", right)]:
        node = OxmlElement(f"w:{m}")
        node.set(qn("w:w"), str(val))
        node.set(qn("w:type"), "dxa")
        tcMar.append(node)
    tcPr.append(tcMar)


def add_page_number_field(run):
    fldChar1 = parse_xml(r'<w:fldChar %s w:fldCharType="begin"/>' % nsdecls("w"))
    instrText = parse_xml(r'<w:instrText %s xml:space="preserve"> PAGE </w:instrText>' % nsdecls("w"))
    fldChar2 = parse_xml(r'<w:fldChar %s w:fldCharType="separate"/>' % nsdecls("w"))
    fldChar3 = parse_xml(r'<w:fldChar %s w:fldCharType="end"/>' % nsdecls("w"))
    run._r.append(fldChar1)
    run._r.append(instrText)
    run._r.append(fldChar2)
    run._r.append(fldChar3)


def add_numpages_field(run):
    fldChar1 = parse_xml(r'<w:fldChar %s w:fldCharType="begin"/>' % nsdecls("w"))
    instrText = parse_xml(r'<w:instrText %s xml:space="preserve"> NUMPAGES </w:instrText>' % nsdecls("w"))
    fldChar2 = parse_xml(r'<w:fldChar %s w:fldCharType="separate"/>' % nsdecls("w"))
    fldChar3 = parse_xml(r'<w:fldChar %s w:fldCharType="end"/>' % nsdecls("w"))
    run._r.append(fldChar1)
    run._r.append(instrText)
    run._r.append(fldChar2)
    run._r.append(fldChar3)


def style_run(run, bold=False, italic=False, color=C_TEXT):
    run.font.name = FONT_NAME
    run.font.size = FONT_SIZE
    run.bold = bold
    run.italic = italic
    run.font.color.rgb = color


def add_body(doc, text, space_after=4):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(0)
    pf.space_after = Pt(space_after)
    r = p.add_run(text)
    style_run(r)
    return p


def add_bullet(doc, lead, text):
    p = doc.add_paragraph(style="List Bullet")
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(0)
    pf.space_after = Pt(3)
    if lead:
        r1 = p.add_run(lead + " ")
        style_run(r1, bold=True, color=C_FOREST)
    r2 = p.add_run(text)
    style_run(r2)
    return p


def add_h1(doc, text, page_break_before=False):
    if page_break_before:
        doc.add_page_break()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(6)
    pf.space_after = Pt(6)
    pf.keep_with_next = True
    r = p.add_run(text)
    style_run(r, bold=True, color=C_FOREST)
    return p


def add_h2(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(8)
    pf.space_after = Pt(3)
    pf.keep_with_next = True
    r = p.add_run(text)
    style_run(r, bold=True, color=C_EMERALD)
    return p


def add_caption(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(2)
    pf.space_after = Pt(8)
    r = p.add_run(text)
    style_run(r, italic=True, color=C_MUTED)
    return p


def add_single_figure(doc, img_path, width_in, caption):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    run = p.add_run()
    run.add_picture(img_path, width=Inches(width_in))
    add_caption(doc, caption)


def add_two_screenshots(doc, img1_path, img2_path, width_in, caption):
    tbl = doc.add_table(rows=1, cols=2)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    for idx, img_path in enumerate([img1_path, img2_path]):
        cell = tbl.cell(0, idx)
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.15
        p.add_run().add_picture(img_path, width=Inches(width_in))
    add_caption(doc, caption)


def add_styled_table(doc, headers, rows, col_widths=None):
    tbl = doc.add_table(rows=1 + len(rows), cols=len(headers))
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl.style = "Table Grid"
    hdr_cells = tbl.rows[0].cells
    for i, h in enumerate(headers):
        set_cell_shading(hdr_cells[i], "123C35")
        set_cell_margins(hdr_cells[i], top=70, bottom=70, left=100, right=100)
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.line_spacing = 1.25
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(0)
        r = p.add_run(h)
        style_run(r, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
        if col_widths:
            hdr_cells[i].width = Inches(col_widths[i])

    for r_idx, row_data in enumerate(rows):
        row_cells = tbl.rows[r_idx + 1].cells
        bg = "F7F8F5" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(row_data):
            set_cell_shading(row_cells[c_idx], bg)
            set_cell_margins(row_cells[c_idx], top=60, bottom=60, left=100, right=100)
            p = row_cells[c_idx].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.line_spacing = 1.25
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            r = p.add_run(val)
            style_run(r)
            if col_widths:
                row_cells[c_idx].width = Inches(col_widths[c_idx])

    sp = doc.add_paragraph()
    sp.paragraph_format.space_before = Pt(0)
    sp.paragraph_format.space_after = Pt(4)
    sp.paragraph_format.line_spacing = 1.0


def build_document():
    doc = Document()

    # Configure A4 page & 1-inch margins
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Inches(1.0)
    section.bottom_margin = Inches(1.0)
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)
    section.different_first_page_header_footer = True

    # Set Normal style to Tahoma 12 pt
    normal = doc.styles["Normal"]
    normal.font.name = FONT_NAME
    normal.font.size = FONT_SIZE
    normal.font.color.rgb = C_TEXT

    # Footer with page numbers (pages 2+)
    footer = section.footer
    fp = footer.paragraphs[0]
    fp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r_pre = fp.add_run("SaloneMarket Final Project Report  |  Page ")
    style_run(r_pre, color=C_MUTED)
    r_pg = fp.add_run()
    style_run(r_pg, bold=True, color=C_FOREST)
    add_page_number_field(r_pg)
    r_mid = fp.add_run(" of ")
    style_run(r_mid, color=C_MUTED)
    r_tot = fp.add_run()
    style_run(r_tot, bold=True, color=C_FOREST)
    add_numpages_field(r_tot)

    # ================================================================
    # PAGE 1: TITLE PAGE
    # ================================================================
    p_logo = doc.add_paragraph()
    p_logo.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_logo.paragraph_format.space_before = Pt(24)
    p_logo.paragraph_format.space_after = Pt(24)
    p_logo.add_run().add_picture(os.path.join(DIAG_DIR, "salone_logo_title.png"), width=Inches(3.2))

    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.line_spacing = 1.5
    p_title.paragraph_format.space_before = Pt(12)
    p_title.paragraph_format.space_after = Pt(18)
    r_t = p_title.add_run("SALONEMARKET: DESIGN AND DEVELOPMENT OF A MULTI-VENDOR MOBILE COMMERCE PLATFORM FOR SIERRA LEONE")
    style_run(r_t, bold=True, color=C_FOREST)

    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_sub.paragraph_format.line_spacing = 1.5
    p_sub.paragraph_format.space_after = Pt(24)
    r_s = p_sub.add_run("Final Academic Project Report\nRepository: https://github.com/Ahmed004-art/salonemarket")
    style_run(r_s, italic=True, color=C_EMERALD)

    meta_rows = [
        ("Student Name:", "[Insert Student Full Name]"),
        ("Student ID:", "[Insert Student ID Number]"),
        ("Institution:", "[Insert University / Institution Name]"),
        ("Department:", "[Insert Department Name]"),
        ("Course / Programme:", "[Insert Degree / Course Title]"),
        ("Supervisor:", "[Insert Supervisor Name]"),
        ("Submission Date:", "[Insert Submission Date]"),
    ]
    add_styled_table(doc, ["Project Submission Detail", "Entry"], meta_rows, col_widths=[2.3, 3.9])

    # ================================================================
    # CHAPTER ONE: INTRODUCTION
    # ================================================================
    add_h1(doc, "CHAPTER ONE: INTRODUCTION", page_break_before=True)

    add_h2(doc, "1.1 Background of the Study")
    add_body(doc, "Mobile commerce (m-commerce) is a primary driver of retail participation in emerging economies where smartphone adoption outpaces desktop computing and branch banking. Across Sub-Saharan Africa, mobile money ecosystems have transformed trade by turning handsets into accessible financial instruments (GSMA, 2024). In Sierra Leone, small merchants across Freetown, Bo, Kenema, and Makeni rely heavily on informal messaging channels and cash-on-delivery arrangements, resulting in fragmented discovery and limited digital infrastructure.")
    add_body(doc, "SaloneMarket addresses this gap as a multi-vendor mobile commerce platform tailored to Sierra Leone. Built with Flutter for cross-platform delivery, Supabase (PostgreSQL, Auth, Storage, and Deno Edge Functions) for backend orchestration, and the Monime Caph API for Sierra Leonean Leone (SLE) mobile money collection, the platform unifies product discovery, multi-vendor carts, atomic checkout, and verifiable receipts.")

    add_h2(doc, "1.2 Problem Statement")
    add_body(doc, "Local merchants and consumers in Sierra Leone face five structural barriers in digital trade:")
    add_bullet(doc, "Limited Online Visibility:", "Independent vendors lack affordable storefronts with structured catalogues and inventory tracking.")
    add_bullet(doc, "Fragmented Discovery:", "Buyers must browse disparate social media pages to compare prices across cities.")
    add_bullet(doc, "Multi-Seller Ordering Complexity:", "Buying from multiple sellers requires separate negotiations and inconsistent tracking.")
    add_bullet(doc, "Payment Trust Challenges:", "Low formal banking penetration and cash reliance create settlement risk for remote orders (World Bank, 2020; World Bank, 2022).")
    add_bullet(doc, "Absence of Authoritative Records:", "Informal trade rarely yields auditable receipts or commission ledgers.")

    add_h2(doc, "1.3 Aim and Objectives")
    add_body(doc, "This project aims to design, implement, and verify a secure multi-vendor mobile commerce platform for Sierra Leone. Specific objectives are to: (1) build Customer, Vendor, and Administrator portals in Flutter; (2) enforce a normalised PostgreSQL schema with Row Level Security (RLS); (3) implement atomic server-side checkout and stock locking; (4) integrate Monime mobile money with HMAC-verified webhooks and idempotent settlement; and (5) verify behaviour through automated tests and runtime checks.")

    add_h2(doc, "1.4 Scope of the Project")
    add_body(doc, "SaloneMarket serves Customers (browsing, multi-vendor cart, checkout, mobile money payment, order tracking, reviews, wishlists), Vendors (onboarding, product/inventory management, order fulfilment, 95% net payout requests), and Administrators (vendor verification, moderation, transaction and payout oversight) in SLE currency.")

    add_h2(doc, "1.5 Significance of the Study")
    add_body(doc, "For consumers and MSMEs, SaloneMarket lowers digital retail barriers with transparent SLE pricing and verifiable records. Technically, it demonstrates how server-authoritative pricing, PostgreSQL row-level locking, and HMAC-verified payment webhooks prevent price tampering and overselling.")

    # ================================================================
    # CHAPTER TWO: LITERATURE REVIEW AND BUSINESS MODEL
    # ================================================================
    add_h1(doc, "CHAPTER TWO: LITERATURE REVIEW AND BUSINESS MODEL", page_break_before=False)

    add_h2(doc, "2.1 Mobile Commerce")
    add_body(doc, "Mobile commerce encompasses product discovery, cart management, electronic settlement, and post-purchase engagement via mobile devices (Laudon and Traver, 2021). In developing markets, mobile-first commerce succeeds when interfaces are bandwidth-conscious and integrated with local mobile money wallets rather than credit cards (GSMA, 2024).")

    add_h2(doc, "2.2 Existing Challenges and Opportunities in Sierra Leone")
    add_body(doc, "World Bank diagnostics show that despite low traditional banking penetration outside Freetown, mobile financial services and the National Payment Switch provide a viable path to broader inclusion (World Bank, 2020; World Bank, 2022). Across Sub-Saharan Africa, mobile money is shifting from peer-to-peer transfers toward merchant payments (GSMA, 2024). In Sierra Leone, Orange Money and AfriMoney dominate mobile wallets, making USSD collection essential, while data costs and fraud caution require clear prompts and server-verified receipts.")

    add_h2(doc, "2.3 Relevant Sustainable Development Goals")
    add_body(doc, "SaloneMarket supports two UN Sustainable Development Goals, recognising that software alone does not achieve macro-level targets (United Nations, 2015):")
    add_bullet(doc, "SDG 8 — Decent Work and Economic Growth (Targets 8.2, 8.3, 8.10):", "Provides MSMEs with digital storefronts, inventory tracking, and traceable mobile money earnings.")
    add_bullet(doc, "SDG 9 — Industry, Innovation and Infrastructure (Targets 9.3, 9.c):", "Integrates small merchants into regional digital value chains via mobile payment gateways.")

    add_h2(doc, "2.4 Business Model")
    add_body(doc, "SaloneMarket operates a commission-based marketplace model:")
    add_bullet(doc, "Target Users & Value:", "Urban and regional consumers across Freetown, Bo, Kenema, and Makeni; verified local retailers. Buyers get unified discovery and receipts; vendors get zero-upfront storefronts.")
    add_bullet(doc, "5% Commission Model:", "Verified in vendors.commission_rate (0.0500) and create_checkout_order, the platform deducts 5% per vendor order and credits 95% (vendor_payout) to the seller.")
    add_bullet(doc, "Acquisition & Sustainability:", "Promotions (WELCOME10, SALONE50) and reviews drive adoption, while serverless hosting keeps operating costs low.")

    # ================================================================
    # CHAPTER THREE: SYSTEM ANALYSIS AND DESIGN
    # ================================================================
    add_h1(doc, "CHAPTER THREE: SYSTEM ANALYSIS AND DESIGN", page_break_before=False)

    add_h2(doc, "3.1 System Requirements")
    add_body(doc, "Functional requirements span customer discovery (category filtering, keyword search, wishlists), multi-vendor cart synchronisation, atomic checkout, Monime mobile money payment initiation, real-time status polling, receipt generation, vendor product/order/payout management, and admin moderation. Non-functional requirements include server-authoritative pricing and stock validation, cryptographic webhook security, Row Level Security isolation across user roles, responsive mobile rendering, and accessibility support (reduced motion and high-contrast typography).")

    add_h2(doc, "3.2 User Roles")
    add_styled_table(
        doc,
        ["Role", "Primary Responsibilities", "Access Enforcement"],
        [
            ("Customer", "Browse catalogue, manage cart & addresses, apply promos, checkout, pay via Monime, track orders, view receipts, review products.", "profiles.role = 'customer'; RLS restricts orders, carts, and addresses to auth.uid()."),
            ("Vendor", "Apply for store approval, create/edit products, track inventory, fulfil vendor orders, view 95% net balance, request payouts.", "profiles.role = 'vendor' + active vendor status; RLS scopes mutations to owned store."),
            ("Administrator", "Approve/suspend vendors, moderate products, inspect orders & transactions, approve/disburse/reject vendor payouts.", "public.is_admin() RLS helper + admin_get_* / admin_approve_* SECURITY DEFINER RPCs."),
        ],
        col_widths=[1.2, 2.7, 2.3],
    )

    add_h2(doc, "3.3 System Architecture")
    add_body(doc, "SaloneMarket employs a three-tier serverless architecture (Figure 3.1). The Flutter client communicates directly with Supabase Auth, Storage, and PostgREST for standard CRUD protected by RLS, while sensitive multi-step operations—checkout creation, payment initiation, webhook settlement, and receipt generation—execute inside Deno Edge Functions backed by atomic PostgreSQL RPCs.")
    add_single_figure(doc, os.path.join(DIAG_DIR, "fig_3_1_architecture.png"), 5.8, "Figure 3.1: SaloneMarket System Architecture connecting Flutter, Supabase, and Monime.")

    add_h2(doc, "3.4 Database Design")
    add_body(doc, "The PostgreSQL 15 database comprises 23 tables across 13 versioned SQL migrations. Core commerce entities separate customer-facing orders (customer_orders) from per-seller fulfillment units (vendor_orders) and immutable line-item snapshots (order_items), ensuring that later price edits do not alter historical orders. Financial integrity is enforced through append-only ledgers (transactions and vendor_earnings_ledger), idempotency logs (checkout_idempotency_log), and webhook lease tracking (payment_webhook_events), as illustrated in Figure 3.2.")
    add_single_figure(doc, os.path.join(DIAG_DIR, "fig_3_2_database_erd.png"), 5.8, "Figure 3.2: Core PostgreSQL Database Entities and Relationships.")

    add_h2(doc, "3.5 User Workflows")
    add_body(doc, "In the primary purchasing workflow, a customer signs in, adds items from one or more vendors to their cart, selects a saved delivery address, and submits checkout. The client syncs the cart to PostgreSQL and invokes initiate-checkout, which executes create_checkout_order inside a single transaction with FOR UPDATE product row locks. The customer is routed to OrderConfirmationScreen, selects Orange Money or AfriMoney, enters their phone number, receives a Monime USSD code, approves payment with their mobile wallet PIN, and views the official receipt once monime-webhook settles the order.")

    # ================================================================
    # CHAPTER FOUR: IMPLEMENTATION
    # ================================================================
    add_h1(doc, "CHAPTER FOUR: IMPLEMENTATION", page_break_before=False)

    add_h2(doc, "4.1 Development Technologies")
    add_body(doc, "The frontend is implemented in Flutter (Dart SDK >= 3.3.0) using Provider for state management, go_router for declarative role-guarded navigation, supabase_flutter for backend integration, google_fonts for Manrope and Inter typography, cached_network_image, shimmer, and flutter_svg (Flutter, 2024). Backend services run on Supabase (PostgreSQL 15, GoTrue Auth, Storage buckets product-images and avatars, and Deno TypeScript Edge Functions) (Supabase, 2024). Payments integrate with the Monime Caph API (version caph.2025-08-23) (Monime, 2025).")

    add_h2(doc, "4.2 Customer Application")
    add_body(doc, "The customer application begins with SplashScreen (checking SharedPreferences onboarding state and Supabase auth session), a three-slide OnboardingScreen, and WelcomeScreen before entering HomeScreen. Customers can search and filter products via ProductCatalogScreen, inspect product details, manage quantities in CartScreen, save delivery addresses, apply server-validated promo codes (apply_promo_code RPC), complete checkout, pay via Monime mobile money, track order status, submit product reviews, manage wishlists, and send feedback.")

    add_h2(doc, "4.3 Vendor Application")
    add_body(doc, "Authenticated users can apply to become sellers through VendorApplyScreen. Once approved by an administrator, VendorDashboardScreen displays store revenue summaries (today, week, month), pending/active orders, and quick-action buttons. Vendors manage products and stock via VendorProductsScreen and VendorProductFormScreen, update fulfillment states on VendorOrdersScreen, and manage Orange Money, AfriMoney, or bank payout destinations on VendorPayoutsScreen.")

    add_h2(doc, "4.4 Administrator Application")
    add_body(doc, "The Admin Portal (AdminDashboardScreen) provides platform KPIs (gross merchandise volume, users, vendors, orders) and dedicated management screens for Users, Vendor Verification (approve, suspend, reactivate), Product Moderation, Order Oversight, Transaction Monitoring, and Payout Administration. During engineering verification, a RenderFlex infinite-width layout defect affecting Row-embedded buttons in the admin and vendor portals was identified and resolved by applying explicit minimumSize constraints and high-contrast foreground colours.")

    add_h2(doc, "4.5 User Interface and Experience")
    add_body(doc, "A unified design system ('Premium Modern African Commerce') is implemented in SaloneColors and SaloneMarketTheme (app_theme.dart), using Forest Green (#123C35), Emerald (#0E8F6E), Light Cream (#F5F2E9), and Warm Gold (#E7AD55) with Manrope headings, Inter body controls, and a custom vector SaloneLogo widget. Figures 4.1 to 4.3 present genuine screenshots captured directly from the running SaloneMarket Flutter application.")

    add_two_screenshots(
        doc,
        os.path.join(SHOT_DIR, "01_onboarding.png"),
        os.path.join(SHOT_DIR, "02_welcome.png"),
        2.35,
        "Figure 4.1: Genuine Onboarding (left) and Welcome (right) screens from the running application.",
    )
    add_two_screenshots(
        doc,
        os.path.join(SHOT_DIR, "03_login.png"),
        os.path.join(SHOT_DIR, "04_home.png"),
        2.35,
        "Figure 4.2: Genuine Sign In (left) and Customer Homepage (right) screens from the running application.",
    )
    add_two_screenshots(
        doc,
        os.path.join(SHOT_DIR, "05_search.png"),
        os.path.join(SHOT_DIR, "06_cart.png"),
        2.35,
        "Figure 4.3: Genuine Product Catalog with live Supabase categories (left) and Shopping Cart (right).",
    )

    # ================================================================
    # CHAPTER FIVE: PAYMENT SYSTEM AND SECURITY
    # ================================================================
    add_h1(doc, "CHAPTER FIVE: PAYMENT SYSTEM AND SECURITY", page_break_before=False)

    add_h2(doc, "5.1 Monime Payment Architecture and Lifecycle")
    add_body(doc, "Client applications never mark orders as paid or calculate authoritative totals. When a customer selects Orange Money (m17) or AfriMoney (m18) and enters a phone number on OrderConfirmationScreen, PaymentRepository invokes process-payment, which validates ownership, order state (pending_payment), and total amount, logs a payment_attempts row via create_or_get_payment_attempt, and calls MonimePaymentProvider (POST /v1/payment-codes) in SLE minor units (amount * 100) with E.164 phone normalisation (+232...) and 30-minute expiry (Monime, 2025). Monime returns HTTP 202 with a USSD code persisted onto payment_attempts.provider_reference; the app polls customer_orders every four seconds while the subscriber approves via PIN (Figure 5.1).")
    add_single_figure(doc, os.path.join(DIAG_DIR, "fig_5_1_payment_lifecycle.png"), 5.8, "Figure 5.1: End-to-End Monime Payment Initiation and Authoritative Webhook Settlement Lifecycle.")

    add_h2(doc, "5.2 Idempotency, Settlement, and Reconciliation")
    add_body(doc, "Duplicate submissions are blocked at three layers: checkout_idempotency_log (24-hour TTL), idx_payment_attempts_customer_idempotency, and Monime's Idempotency-Key header. In monime-webhook/index.ts, incoming events are claimed via claim_payment_webhook_event with a 60-second lease (returning HTTP 429 Retry-After on concurrent delivery). Intermediate payment_code.processed events never settle an order; only verified payment_code.completed triggers settle_order_payment('succeeded'), which locks customer_orders FOR UPDATE, appends to transactions, marks customer_orders confirmed/paid and vendor_orders confirmed, and notifies both parties.")
    add_body(doc, "Cancelled or expired events mark the attempt failed while leaving the order in pending_payment for retry without premature stock restoration. Late or duplicate successes after cancellation or payment are recorded with reconciliation_needed = true and trigger administrator alerts.")

    add_h2(doc, "5.3 Vendor Commission, Payouts, and Live Verification Status")
    add_body(doc, "Vendor earnings are tracked in vendor_earnings_ledger (5% commission deducted, 95% credited). Vendors register mobile money or bank destinations and submit payout requests. While manual payout approval and disbursement by administrators is fully operational in AdminPayoutsScreen, automated outbound disbursement via Monime's /v1/payouts endpoint (monime_payout_adapter.ts) is not yet wired to an Edge Function in admin_payout_repository.dart. Furthermore, while all three payment Edge Functions (process-payment, monime-webhook with --no-verify-jwt, and generate-receipt) and Monime credentials have been configured, a live end-to-end production money transfer has not yet been executed in this audit; therefore, simulated/unit-verified behaviour is strictly distinguished from live production settlement.")

    add_h2(doc, "5.4 Security and Privacy")
    add_body(doc, "Security controls span five layers: (1) Supabase JWT authentication with role checks; (2) PostgreSQL Row Level Security across all 23 tables, denying public access to checkout_idempotency_log and payment_webhook_events; (3) SECURITY DEFINER financial RPCs restricted strictly to service_role; (4) server-side secret isolation for MONIME_ACCESS_TOKEN, MONIME_SPACE_ID, and MONIME_WEBHOOK_SECRET; and (5) HMAC-SHA256 webhook signature verification over timestamp_rawBody with constant-time comparison and a 300-second replay window (Monime, 2025).")

    # ================================================================
    # CHAPTER SIX: TESTING, RESULTS AND DISCUSSION
    # ================================================================
    add_h1(doc, "CHAPTER SIX: TESTING, RESULTS AND DISCUSSION", page_break_before=False)

    add_h2(doc, "6.1 Testing Approach")
    add_body(doc, "Verification combined static Dart analysis (flutter analyze), automated unit and widget tests (flutter test --no-pub), headless Chrome runtime verification against the live Supabase development backend, and Android debug APK compilation. Unit tests used mocktail and deterministic repository doubles to validate state machines, webhook signature verification, and UI rendering without executing real-money transfers.")

    add_h2(doc, "6.2 Functional and Payment Testing")
    add_body(doc, "Payment testing covered signature validation (valid, invalid, missing, tampered, and expired >300s headers), intermediate payment_code.processed non-settlement, terminal payment_code.completed settlement, cancelled/expired retryability, lease conflict handling (HTTP 429), and late-payment reconciliation flags. Customer UI flows were verified by compiling and running the Flutter web client against Supabase and capturing screenshots of onboarding, welcome, authentication, homepage, catalog, and cart screens.")

    add_h2(doc, "6.3 Observed Test Results")
    add_styled_table(
        doc,
        ["Test Suite / Verification", "Scope Verified", "Observed Result", "Status"],
        [
            ("monime_webhook_security_test.dart", "HMAC-SHA256, replay window, lease 429, processed vs completed states", "16 / 16 tests passed (exit code 0)", "PASSED"),
            ("payment_workflow_test.dart, payment_foundation_test.dart, receipt_screen_test.dart, checkout_screen_test.dart", "PaymentNotifier state machine, settlement contracts, receipt & checkout UI", "25 passed, 6 PostgreSQL integration specs skipped by design", "PASSED (Unit/Widget)"),
            ("Admin & Auth UI suites (earlier redesign run)", "admin_dashboard_render_test, auth_notifier_test, vendor_admin_portals_test", "15 / 15 tests passed after Row button constraint fix", "PASSED"),
            ("vendor_payouts_and_settlement_test.dart (earlier run)", "5% commission rounding & payout settlement unit tests", "10 / 11 passed; 1 pre-existing rounding failure (expected 7.5 vs 8.0)", "PARTIAL (1 Fail)"),
            ("Android Debug APK Build", "flutter build apk --debug --dart-define-from-file=../supabase.dev.json", "Built app-debug.apk cleanly (non-blocking share_plus KGP warning)", "PASSED"),
            ("Live Monime Production Transfer", "End-to-end real SLE Mobile Money USSD + live webhook delivery", "Code & secrets deployed; live real-money test not yet executed", "PENDING LIVE TEST"),
        ],
        col_widths=[1.7, 1.9, 1.6, 1.0],
    )

    add_h2(doc, "6.4 Limitations")
    add_body(doc, "Remaining limitations are: (1) a live real-money Monime transaction must still be smoke-tested on the rebuilt APK; (2) automated outbound Monime vendor payouts require wiring admin_payout_repository.dart to an Edge Function calling monime_payout_adapter.ts; (3) one pre-existing rounding discrepancy in vendor_payouts_and_settlement_test.dart remains; (4) the development catalog currently holds seeded categories with zero active products in unauthenticated view; and (5) authenticated Vendor, Admin, and Checkout screens were omitted from headless capture to avoid exposing credentials.")

    # ================================================================
    # CHAPTER SEVEN: CONCLUSION AND RECOMMENDATIONS
    # ================================================================
    add_h1(doc, "CHAPTER SEVEN: CONCLUSION AND RECOMMENDATIONS", page_break_before=False)

    add_h2(doc, "7.1 Conclusion")
    add_body(doc, "SaloneMarket delivers a structured, secure multi-vendor mobile commerce platform for Sierra Leone across Customer, Vendor, and Administrator portals. Backed by 23 PostgreSQL tables with RLS, atomic checkout RPCs, a 5% commission ledger, and HMAC-verified Monime webhooks, the architecture prevents client-side price tampering and premature payment confirmation.")

    add_h2(doc, "7.2 Recommendations and Future Improvements")
    add_bullet(doc, "1. Live Monime Smoke Test:", "Execute a low-value (SLE 1-5) Orange Money and AfriMoney transaction on the rebuilt APK to confirm live webhook delivery.")
    add_bullet(doc, "2. Automated Outbound Payouts:", "Wire monime_payout_adapter.ts to an admin-only Edge Function for one-click Monime vendor disbursements.")
    add_bullet(doc, "3. Commission Rounding Alignment:", "Resolve the pre-existing rounding discrepancy in vendor_payouts_and_settlement_test.dart across Dart and SQL.")
    add_bullet(doc, "4. Production Monitoring:", "Enable automated expire_unpaid_order scheduling and webhook failure alerts.")

    # ================================================================
    # REFERENCES
    # ================================================================
    add_h1(doc, "REFERENCES", page_break_before=False)
    refs = [
        "Flutter (2024) Flutter Documentation: Building user interfaces and multi-platform applications. Google. Available at: https://docs.flutter.dev/ (Accessed: 25 November 2026).",
        "GSMA (2024) State of the Industry Report on Mobile Money 2024. London: GSM Association. Available at: https://www.gsma.com/sotir/ (Accessed: 25 November 2026).",
        "Laudon, K.C. and Traver, C.G. (2021) E-Commerce 2021-2022: Business, Technology, and Society. 17th edn. Harlow: Pearson Education.",
        "Monime (2025) Monime Developer Documentation: Payment Codes API (Caph) and Webhook HMAC Verification. Available at: https://docs.monime.io/ (Accessed: 25 November 2026).",
        "Supabase (2024) Supabase Documentation: PostgreSQL, Row Level Security, Auth, and Edge Functions. Available at: https://supabase.com/docs (Accessed: 25 November 2026).",
        "United Nations (2015) Transforming our world: the 2030 Agenda for Sustainable Development (Sustainable Development Goals 8 and 9). New York: United Nations. Available at: https://sdgs.un.org/goals (Accessed: 25 November 2026).",
        "World Bank (2020) Sierra Leone Digital Economy Diagnostic. Washington, DC: World Bank Group. Available at: https://www.worldbank.org/ (Accessed: 25 November 2026).",
        "World Bank (2022) The Global Findex Database 2021: Financial Inclusion, Digital Payments, and Resilience in the Age of COVID-19. Washington, DC: World Bank Group.",
    ]
    for ref in refs:
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        pf = p.paragraph_format
        pf.line_spacing = 1.5
        pf.left_indent = Inches(0.35)
        pf.first_line_indent = Inches(-0.35)
        pf.space_before = Pt(0)
        pf.space_after = Pt(6)
        r = p.add_run(ref)
        style_run(r)

    doc.save(OUT_DOCX)
    print("Saved DOCX:", OUT_DOCX)


if __name__ == "__main__":
    build_document()
