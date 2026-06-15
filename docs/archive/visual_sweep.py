"""Visual sweep: login per role, screenshot redesigned pages at phone/desktop,
flag console errors and horizontal overflow. Run: python visual_sweep.py
"""

from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8000"
OUT = "test-results/visual-sweep"
PASSWORD = "SmokeTest123!"

PLANS = {
    "TCRESP1": [
        ("/staff/home/", "staff-home"),
        ("/staff/addbook/", "staff-add-book"),
        ("/staff/issue_book/", "staff-issue-book"),
        ("/staff/view_issued_book/", "staff-loans"),
    ],
    "ICRESP1": [
        ("/student/home/", "student-home"),
        ("/student/viewbooks/", "student-library"),
    ],
    "responsive-admin@example.com": [
        ("/admin/home/", "admin-home"),
        ("/branch/add/", "admin-add-branch"),
        ("/enrollment/add/", "admin-add-enrollment"),
        ("/student/manage/", "admin-manage-students"),
    ],
}

VIEWPORTS = [("phone", 390, 844), ("desktop", 1366, 900)]

issues = []
with sync_playwright() as p:
    browser = p.chromium.launch()
    roles = {
        "TCRESP1": "teacher",
        "ICRESP1": "student",
        "responsive-admin@example.com": "admin",
    }
    for email, pages in PLANS.items():
        role = roles[email]
        ctx = browser.new_context(viewport={"width": 1366, "height": 900})
        pg = ctx.new_page()
        errors = []
        pg.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        pg.on("pageerror", lambda e: errors.append(str(e)))
        pg.goto(BASE + "/login/")
        pg.fill("#id_identifier", email)
        pg.fill("#id_password", PASSWORD)
        pg.click("button[type=submit]")
        pg.wait_for_load_state("networkidle")
        if "/login" in pg.url or "doLogin" in pg.url:
            issues.append(f"{role}: LOGIN FAILED (still at {pg.url})")
            ctx.close()
            continue
        print(f"{role}: logged in -> {pg.url}")
        for path, name in pages:
            for vp_name, w, h in VIEWPORTS:
                pg.set_viewport_size({"width": w, "height": h})
                resp = pg.goto(BASE + path)
                pg.wait_for_load_state("networkidle")
                if resp and resp.status >= 400:
                    issues.append(f"{role} {path} [{vp_name}]: HTTP {resp.status}")
                overflow = pg.evaluate(
                    "document.scrollingElement.scrollWidth - document.documentElement.clientWidth"
                )
                if overflow > 2:
                    issues.append(f"{role} {path} [{vp_name}]: horizontal overflow {overflow}px")
                pg.screenshot(path=f"{OUT}/{name}-{vp_name}.png", full_page=False)
        if errors:
            issues.append(f"{role}: console errors: {errors[:5]}")
        ctx.close()
    browser.close()

print()
if issues:
    print("ISSUES:")
    for i in issues:
        print(" -", i)
else:
    print("Visual sweep clean: no overflow, no console errors, all pages load.")
