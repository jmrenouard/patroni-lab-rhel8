import sys
import os
import re
from markdown_it import MarkdownIt

def generate_html(md_path):
    if not os.path.exists(md_path):
        print(f"Error: {md_path} not found.")
        sys.exit(1)

    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()

    md = MarkdownIt()
    # Custom rendering for checkboxes if needed, but standard should work
    html_body = md.render(md_content)

    # Style definitions (Premiun Aesthetic)
    css = """
    :root {
        --bg-color: #0f172a;
        --card-bg: #1e293b;
        --text-color: #f1f5f9;
        --accent-color: #38bdf8;
        --success-color: #22c55e;
        --fail-color: #ef4444;
        --border-color: #334155;
    }
    body {
        font-family: 'Inter', system-ui, -apple-system, sans-serif;
        background-color: var(--bg-color);
        color: var(--text-color);
        line-height: 1.6;
        padding: 2rem;
        max-width: 1000px;
        margin: 0 auto;
    }
    h1 { color: var(--accent-color); border-bottom: 2px solid var(--border-color); padding-bottom: 0.5rem; }
    h2 { margin-top: 2.5rem; color: var(--accent-color); display: flex; align-items: center; justify-content: space-between;}
    h3 { color: #94a3b8; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 1.5rem;}
    
    pre {
        background: #000;
        padding: 1rem;
        border-radius: 8px;
        overflow-x: auto;
        border: 1px solid var(--border-color);
        font-family: 'Fira Code', 'JetBrains Mono', monospace;
        font-size: 0.85rem;
    }
    code { font-family: inherit; }
    
    .status-badge {
        padding: 0.25rem 0.75rem;
        border-radius: 9999px;
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
    }
    .status-success { background: rgba(34, 197, 94, 0.2); color: #4ade80; border: 1px solid #22c55e; }
    .status-fail { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #ef4444; }
    
    hr { border: 0; border-top: 1px solid var(--border-color); margin: 3rem 0; }
    
    blockquote {
        border-left: 4px solid var(--accent-color);
        padding-left: 1rem;
        margin: 1rem 0;
        color: #94a3b8;
    }

    /* Enhancements for results */
    p strong:contains("✅ SUCCESS") { color: var(--success-color); }
    p strong:contains("❌ FAIL") { color: var(--fail-color); }
    """

    # Post-processing HTML to add badges
    html_body = html_body.replace("✅ SUCCESS", '<span class="status-badge status-success">SUCCESS</span>')
    html_body = html_body.replace("❌ FAIL", '<span class="status-badge status-fail">FAIL</span>')

    full_html = f"""
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport d'Audit Patroni HA</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&family=Fira+Code&display=swap" rel="stylesheet">
    <style>
        {css}
    </style>
</head>
<body>
    <div class="container">
        {html_body}
    </div>
</body>
</html>
    """

    html_path = md_path.replace(".md", ".html")
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(full_html)
    
    print(f"Report generated: {html_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 generate_html_report.py <report.md>")
        sys.exit(1)
    generate_html(sys.argv[1])
