#!/usr/bin/env python3
"""Render docs/privacy.md and docs/support.md to docs/privacy.html and docs/support.html.

GitHub Pages only converts Markdown that has Jekyll front matter, so the pages the app and App
Store Connect link to are generated here and committed. Run after editing either .md file:

    pip install markdown && python3 scripts/build-pages.py
"""
from pathlib import Path

import markdown
from markdown.extensions.toc import slugify_unicode

DOCS = Path(__file__).resolve().parent.parent / "docs"

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  :root {{ --bg:#ffffff; --fg:#17122b; --muted:#5b5670; --violet:#3b1f8f; --card:#f4f1fb; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --bg:#120d24; --fg:#f3f0fa; --muted:#b4aecb; --violet:#a58bff; --card:#1d1637; }} }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--fg); font:17px/1.6 -apple-system, system-ui, "Segoe UI", sans-serif; }}
  main {{ max-width:720px; margin:0 auto; padding:40px 20px 64px; }}
  h1 {{ font-size:clamp(1.8rem,5vw,2.4rem); line-height:1.15; margin:0 0 16px; }}
  h2 {{ font-size:1.3rem; margin:36px 0 10px; }}
  em {{ color:var(--muted); }}
  a {{ color:var(--violet); }}
  hr {{ border:0; border-top:1px solid var(--card); margin:48px 0; }}
  code {{ background:var(--card); border-radius:6px; padding:1px 6px; }}
  nav {{ margin-bottom:24px; font-size:.95rem; }}
  footer {{ margin-top:48px; font-size:.9rem; color:var(--muted); }}
</style>
</head>
<body>
<main>
<nav><a href="./">&larr; MURMUR</a></nav>
{body}
<footer><a href="privacy.html">Privacy policy</a> · <a href="support.html">Support</a> · <a href="https://github.com/Cosmichomeless/MURMUR">Source</a></footer>
</main>
</body>
</html>
"""

PAGES = {
    "privacy": "MURMUR Privacy Policy",
    "support": "MURMUR Support",
}

for name, title in PAGES.items():
    md = markdown.Markdown(extensions=["toc"], extension_configs={"toc": {"slugify": slugify_unicode}})
    body = md.convert((DOCS / f"{name}.md").read_text(encoding="utf-8"))
    (DOCS / f"{name}.html").write_text(PAGE.format(title=title, body=body), encoding="utf-8")
    print(f"wrote docs/{name}.html")
