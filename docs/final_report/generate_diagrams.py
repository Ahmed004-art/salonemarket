import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = r"c:\Users\MOK\Downloads\salonemarket\docs\final_report\diagrams"
os.makedirs(OUT_DIR, exist_ok=True)

# Brand colours
FOREST = "#123C35"
EMERALD = "#0E8F6E"
GOLD = "#E7AD55"
CREAM = "#F5F2E9"
TEXT = "#202B28"
MUTED = "#68756F"
WHITE = "#FFFFFF"
BG = "#F7F8F5"
BORDER = "#D4DDD9"

def get_font(size, bold=False):
    candidates = [
        r"C:\Windows\Fonts\tahomabd.ttf" if bold else r"C:\Windows\Fonts\tahoma.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def draw_rounded_box(draw, xy, fill, outline, radius=16, width=3):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def draw_arrow(draw, x1, y1, x2, y2, color=FOREST, width=4, label=None, font=None):
    draw.line((x1, y1, x2, y2), fill=color, width=width)
    # Arrowhead
    import math
    angle = math.atan2(y2 - y1, x2 - x1)
    size = 14
    p1 = (x2 - size * math.cos(angle - math.pi / 6), y2 - size * math.sin(angle - math.pi / 6))
    p2 = (x2 - size * math.cos(angle + math.pi / 6), y2 - size * math.sin(angle + math.pi / 6))
    draw.polygon([(x2, y2), p1, p2], fill=color)
    if label and font:
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        bbox = draw.textbbox((0, 0), label, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.rectangle((mx - tw // 2 - 6, my - th // 2 - 4, mx + tw // 2 + 6, my + th // 2 + 4), fill=WHITE)
        draw.text((mx - tw // 2, my - th // 2), label, fill=TEXT, font=font)

def centered_text(draw, box, lines, font, fill=TEXT, spacing=6):
    x1, y1, x2, y2 = box
    cx = (x1 + x2) // 2
    total_h = 0
    heights = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        h = bbox[3] - bbox[1]
        heights.append(h)
        total_h += h
    total_h += spacing * (len(lines) - 1)
    cur_y = y1 + (y2 - y1 - total_h) // 2
    for line, h in zip(lines, heights):
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        draw.text((cx - w // 2, cur_y), line, fill=fill, font=font)
        cur_y += h + spacing

# ------------------------------------------------------------------
# 1. System Architecture Diagram
# ------------------------------------------------------------------
def make_architecture_diagram():
    W, H = 1600, 900
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    f_title = get_font(28, bold=True)
    f_head = get_font(22, bold=True)
    f_body = get_font(18, bold=False)
    f_small = get_font(16, bold=False)

    draw.text((40, 24), "SaloneMarket System Architecture", fill=FOREST, font=f_title)

    # Column 1: Client Layer
    draw_rounded_box(draw, (40, 90, 420, 820), BG, FOREST, width=3)
    draw_rounded_box(draw, (40, 90, 420, 155), FOREST, FOREST, width=3)
    centered_text(draw, (40, 90, 420, 155), ["Client Layer (Flutter / Dart)"], f_head, WHITE)

    boxes_c1 = [
        (190, 340, "Customer Portal\nMarketplace, Search, Cart,\nCheckout, Orders, Receipts"),
        (375, 525, "Vendor Portal\nOnboarding, Products,\nOrder Fulfilment, Payouts"),
        (560, 710, "Admin Portal\nVendor Verification, Moderation,\nOrders, Transactions, Payouts"),
    ]
    for y1, y2, txt in boxes_c1:
        draw_rounded_box(draw, (70, y1, 390, y2), WHITE, EMERALD, width=2)
        centered_text(draw, (70, y1, 390, y2), txt.split("\n"), f_body, TEXT)
    draw.text((80, 755), "Provider + go_router + supabase_flutter", fill=MUTED, font=f_small)

    # Column 2: Supabase Platform
    draw_rounded_box(draw, (510, 90, 1080, 820), BG, EMERALD, width=3)
    draw_rounded_box(draw, (510, 90, 1080, 155), EMERALD, EMERALD, width=3)
    centered_text(draw, (510, 90, 1080, 155), ["Backend Layer (Supabase Platform)"], f_head, WHITE)

    draw_rounded_box(draw, (540, 185, 790, 310), WHITE, FOREST, width=2)
    centered_text(draw, (540, 185, 790, 310), ["Supabase Auth & Storage", "JWT Auth, Role Profiles", "Product & Avatar Buckets"], f_body, TEXT)

    draw_rounded_box(draw, (810, 185, 1050, 310), CREAM, GOLD, width=2)
    centered_text(draw, (810, 185, 1050, 310), ["Edge Functions (Deno)", "initiate-checkout", "process-payment", "monime-webhook | generate-receipt"], f_small, TEXT)

    draw_rounded_box(draw, (540, 355, 1050, 785), WHITE, FOREST, width=3)
    draw_rounded_box(draw, (540, 355, 1050, 415), FOREST, FOREST, width=2)
    centered_text(draw, (540, 355, 1050, 415), ["PostgreSQL 15 Database (23 Tables + RLS)"], f_head, WHITE)
    centered_text(draw, (555, 430, 1035, 770), [
        "Core Tables: profiles, vendors, categories, products, addresses,",
        "carts, cart_items, customer_orders, vendor_orders, order_items",
        "",
        "Payment & Ledger: payment_attempts, transactions,",
        "payment_webhook_events, checkout_idempotency_log,",
        "vendor_payout_destinations, vendor_payouts, vendor_earnings_ledger",
        "",
        "Atomic RPCs: create_checkout_order, create_or_get_payment_attempt,",
        "settle_order_payment, claim_payment_webhook_event, expire_unpaid_order"
    ], f_small, TEXT, spacing=7)

    # Column 3: External Payment Gateway
    draw_rounded_box(draw, (1170, 90, 1560, 820), BG, GOLD, width=3)
    draw_rounded_box(draw, (1170, 90, 1560, 155), GOLD, GOLD, width=3)
    centered_text(draw, (1170, 90, 1560, 155), ["Payment Provider (Monime)"], f_head, TEXT)

    draw_rounded_box(draw, (1200, 195, 1530, 360), WHITE, FOREST, width=2)
    centered_text(draw, (1200, 195, 1530, 360), ["Monime Caph API", "POST /v1/payment-codes", "Providers: m17 (Orange Money)", "and m18 (AfriMoney)"], f_body, TEXT)

    draw_rounded_box(draw, (1200, 415, 1530, 580), WHITE, EMERALD, width=2)
    centered_text(draw, (1200, 415, 1530, 580), ["Subscriber USSD Handset", "Customer dials USSD code", "& enters Mobile Money PIN"], f_body, TEXT)

    draw_rounded_box(draw, (1200, 635, 1530, 785), CREAM, FOREST, width=2)
    centered_text(draw, (1200, 635, 1530, 785), ["Signed Webhooks", "HMAC-SHA256 (monime-signature)", "payment_code.completed / failed"], f_small, TEXT)

    # Arrows
    draw_arrow(draw, 420, 260, 540, 245, FOREST, label="HTTPS / JWT", font=f_small)
    draw_arrow(draw, 420, 450, 540, 450, EMERALD, label="PostgREST + RLS", font=f_small)
    draw_arrow(draw, 1050, 245, 1200, 245, FOREST, label="Bearer + Space ID", font=f_small)
    draw_arrow(draw, 1365, 360, 1365, 415, EMERALD)
    draw_arrow(draw, 1365, 580, 1365, 635, EMERALD)
    draw_arrow(draw, 1200, 705, 1050, 300, GOLD, label="Webhook POST", font=f_small)

    img.save(os.path.join(OUT_DIR, "fig_3_1_architecture.png"), dpi=(300, 300))

# ------------------------------------------------------------------
# 2. Database Entity-Relationship Overview
# ------------------------------------------------------------------
def make_erd_diagram():
    W, H = 1600, 880
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    f_title = get_font(28, bold=True)
    f_head = get_font(19, bold=True)
    f_body = get_font(16, bold=False)

    draw.text((40, 24), "Core Database Entities & Relationships (PostgreSQL)", fill=FOREST, font=f_title)

    def entity(x, y, w, h, title, fields, hdr_color=FOREST):
        draw_rounded_box(draw, (x, y, x + w, y + h), WHITE, hdr_color, radius=12, width=2)
        draw_rounded_box(draw, (x, y, x + w, y + 42), hdr_color, hdr_color, radius=10, width=2)
        centered_text(draw, (x, y, x + w, y + 42), [title], f_head, WHITE if hdr_color != GOLD else TEXT)
        cur_y = y + 52
        for fld in fields:
            draw.text((x + 14, cur_y), fld, fill=TEXT, font=f_body)
            cur_y += 24

    entity(40, 90, 290, 175, "profiles", ["PK id (auth.users)", "role (customer|vendor|admin)", "full_name, phone, is_active"])
    entity(40, 330, 290, 195, "vendors", ["PK id", "FK profile_id -> profiles", "shop_name, status", "commission_rate (0.0500)"])
    entity(40, 600, 290, 195, "products", ["PK id", "FK vendor_id -> vendors", "FK category_id -> categories", "price, stock_quantity, status"])

    entity(430, 90, 320, 195, "carts & cart_items", ["carts.customer_id -> profiles", "cart_items.cart_id -> carts", "cart_items.product_id -> products", "quantity, unit_price"])
    entity(430, 340, 320, 220, "customer_orders", ["PK id", "FK customer_id -> profiles", "status, payment_status", "total, shipping_address_id", "payment_method"])
    entity(430, 615, 320, 200, "vendor_orders & items", ["vendor_orders.customer_order_id", "vendor_orders.vendor_id", "commission_amount, vendor_payout", "order_items (immutable snapshot)"])

    entity(860, 90, 340, 210, "payment_attempts", ["PK id", "FK customer_order_id", "provider, method, currency (SLE)", "idempotency_key (UNIQUE)", "provider_reference, status"])
    entity(860, 355, 340, 195, "transactions (Ledger)", ["PK id (Append-Only)", "FK payment_attempt_id", "FK customer_order_id", "reference, amount, status"])
    entity(860, 605, 340, 195, "payment_webhook_events", ["PK id", "UNIQUE (provider, event_id)", "status (processing|completed)", "processing_expires_at (lease)"])

    entity(1260, 140, 300, 185, "vendor_payouts", ["PK id, payout_reference", "FK vendor_id -> vendors", "amount, status, method", "provider_payout_id"], EMERALD)
    entity(1260, 400, 300, 205, "vendor_earnings_ledger", ["PK id (Append-Only)", "FK vendor_id, vendor_order_id", "type (order_credit|payout_debit)", "gross, commission, net_amount"], EMERALD)
    entity(1260, 650, 300, 150, "Engagement Tables", ["reviews, wishlists", "notifications, promotions", "customer_feedback"], GOLD)

    # Relationships
    draw_arrow(draw, 185, 265, 185, 330, FOREST)
    draw_arrow(draw, 185, 525, 185, 600, FOREST)
    draw_arrow(draw, 330, 175, 430, 175, EMERALD)
    draw_arrow(draw, 330, 210, 430, 410, FOREST)
    draw_arrow(draw, 590, 560, 590, 615, FOREST)
    draw_arrow(draw, 750, 420, 860, 200, EMERALD)
    draw_arrow(draw, 750, 460, 860, 460, FOREST)
    draw_arrow(draw, 1030, 300, 1030, 355, FOREST)
    draw_arrow(draw, 1030, 605, 1030, 550, GOLD)
    draw_arrow(draw, 750, 700, 1260, 500, EMERALD)
    draw_arrow(draw, 1410, 325, 1410, 400, EMERALD)

    img.save(os.path.join(OUT_DIR, "fig_3_2_database_erd.png"), dpi=(300, 300))

# ------------------------------------------------------------------
# 3. Payment Lifecycle Diagram
# ------------------------------------------------------------------
def make_payment_diagram():
    W, H = 1600, 780
    img = Image.new("RGB", (W, H), WHITE)
    draw = ImageDraw.Draw(img)
    f_title = get_font(28, bold=True)
    f_head = get_font(19, bold=True)
    f_body = get_font(16, bold=False)

    draw.text((40, 24), "Monime Payment Initiation & Authoritative Webhook Settlement Lifecycle", fill=FOREST, font=f_title)

    steps = [
        (50, 110, 330, 270, "1. Order Creation", ["initiate-checkout Edge Fn", "create_checkout_order RPC", "Status: pending_payment"], FOREST),
        (430, 110, 710, 270, "2. Payment Initiation", ["Customer picks Orange/AfriMoney", "process-payment Edge Fn", "create_or_get_payment_attempt"], EMERALD),
        (810, 110, 1120, 270, "3. Monime Payment Code", ["POST /v1/payment-codes", "Amount in SLE cents (x100)", "Returns USSD code (HTTP 202)"], FOREST),
        (1220, 110, 1540, 270, "4. Customer Handset", ["App displays USSD code", "Customer dials & enters PIN", "App polls status every 4s"], GOLD),

        (1220, 430, 1540, 610, "5. Webhook Delivery", ["Monime POSTs signed event", "monime-signature (HMAC-SHA256)", "Replay window <= 300s"], FOREST),
        (810, 430, 1120, 610, "6. Lease & Validation", ["claim_payment_webhook_event", "Verify order, currency (SLE),", "and exact amount match"], EMERALD),
        (430, 430, 710, 610, "7. Atomic Settlement", ["Only payment_code.completed", "settle_order_payment RPC", "Ledger + Order = confirmed/paid"], FOREST),
        (50, 430, 330, 610, "8. Receipt & Vendor Credit", ["App detects paid status", "generate-receipt Edge Fn", "Vendor credited 95% (5% fee)"], EMERALD),
    ]

    for x1, y1, x2, y2, title, lines, col in steps:
        draw_rounded_box(draw, (x1, y1, x2, y2), BG, col, radius=14, width=3)
        draw_rounded_box(draw, (x1, y1, x2, y1 + 46), col, col, radius=12, width=2)
        centered_text(draw, (x1, y1, x2, y1 + 46), [title], f_head, WHITE if col != GOLD else TEXT)
        centered_text(draw, (x1 + 10, y1 + 52, x2 - 10, y2 - 8), lines, f_body, TEXT, spacing=6)

    draw_arrow(draw, 330, 190, 430, 190, FOREST)
    draw_arrow(draw, 710, 190, 810, 190, EMERALD)
    draw_arrow(draw, 1120, 190, 1220, 190, FOREST)
    draw_arrow(draw, 1380, 270, 1380, 430, GOLD, label="Async Event", font=f_body)
    draw_arrow(draw, 1220, 520, 1120, 520, FOREST)
    draw_arrow(draw, 810, 520, 710, 520, EMERALD)
    draw_arrow(draw, 430, 520, 330, 520, FOREST)

    draw_rounded_box(draw, (50, 660, 1540, 740), CREAM, GOLD, radius=10, width=2)
    centered_text(draw, (50, 660, 1540, 740), [
        "Security Invariant: Intermediate payment_code.processed events NEVER mark an order as paid. Only verified payment_code.completed",
        "settles the order; duplicate or late payments after cancellation are logged with reconciliation_needed = true and alert admins."
    ], f_body, TEXT, spacing=4)

    img.save(os.path.join(OUT_DIR, "fig_5_1_payment_lifecycle.png"), dpi=(300, 300))

make_architecture_diagram()
make_erd_diagram()
make_payment_diagram()
print("Diagrams generated successfully in", OUT_DIR)
