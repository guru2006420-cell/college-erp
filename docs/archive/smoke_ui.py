"""Render every argument-free GET page as each role and report failures.

Run with: python smoke_ui.py
Uses the real dev database read-only (GET requests only).
"""

import os

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "college_management_system.settings")
django.setup()

from django.test import Client  # noqa: E402
from django.urls import URLPattern, get_resolver  # noqa: E402

from main_app.models import CustomUser  # noqa: E402

ROLE_USERS = {
    "admin": CustomUser.objects.filter(email="responsive-admin@example.com").first(),
    "staff": CustomUser.objects.filter(email="responsive-teacher@example.com").first(),
    "student": CustomUser.objects.filter(email="responsive-student@example.com").first(),
}

SKIP = {
    "user_logout",  # would end the session
    "showFirebaseJS",
    "health",
}


def _walk(patterns, prefix=""):
    for p in patterns:
        if isinstance(p, URLPattern):
            yield p, prefix + str(p.pattern)
        else:  # URLResolver
            yield from _walk(p.url_patterns, prefix + str(p.pattern))


def argfree_urls():
    for p, route in _walk(get_resolver().url_patterns):
        name = p.name
        if not name or name in SKIP:
            continue
        if "<" in route:
            continue  # needs args
        yield name, "/" + route


failures = []
for role, user in ROLE_USERS.items():
    if user is None:
        print(f"!! no user for role {role}")
        continue
    c = Client()
    c.force_login(user)
    ok = redirected = failed = 0
    for name, url in argfree_urls():
        try:
            r = c.get(url, follow=False)
        except Exception as e:  # template/view crash
            failures.append((role, name, url, f"EXC {type(e).__name__}: {e}"))
            failed += 1
            continue
        if r.status_code >= 500:
            failures.append((role, name, url, f"HTTP {r.status_code}"))
            failed += 1
        elif r.status_code in (301, 302, 403, 405):
            redirected += 1  # role-gated or POST-only: fine
        else:
            ok += 1
    print(f"{role}: {ok} ok, {redirected} gated/redirect, {failed} failed")

if failures:
    print("\nFAILURES:")
    for f in failures:
        print(" ", *f)
    raise SystemExit(1)
print("\nAll pages render cleanly for all roles.")
