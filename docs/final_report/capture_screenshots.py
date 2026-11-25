import os
import time
from playwright.sync_api import sync_playwright

OUT_DIR = r"c:\Users\MOK\Downloads\salonemarket\docs\final_report\report_screenshots"
os.makedirs(OUT_DIR, exist_ok=True)

BASE = "http://localhost:8085"

ROUTES = [
    ("01_onboarding.png", "/#/onboarding", 8),
    ("02_welcome.png", "/#/welcome", 6),
    ("03_login.png", "/#/login", 6),
    ("04_home.png", "/#/home", 10),
    ("05_search.png", "/#/search", 8),
    ("06_cart.png", "/#/cart", 6),
]

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            channel="chrome",
            headless=True,
            args=["--disable-gpu", "--no-sandbox"],
        )
        context = browser.new_context(
            viewport={"width": 430, "height": 860},
            device_scale_factor=2,
        )
        page = context.new_page()

        # First load to warm up Flutter CanvasKit / Dart Web
        page.goto(f"{BASE}/#/onboarding", wait_until="domcontentloaded", timeout=45000)
        page.wait_for_timeout(12000)

        for filename, route, wait_sec in ROUTES:
            url = f"{BASE}{route}"
            print(f"Navigating to {url}...")
            page.goto(url, wait_until="domcontentloaded", timeout=30000)
            page.wait_for_timeout(wait_sec * 1000)
            out_path = os.path.join(OUT_DIR, filename)
            page.screenshot(path=out_path)
            print(f"Saved {out_path} ({os.path.getsize(out_path)} bytes)")

        browser.close()

if __name__ == "__main__":
    main()
