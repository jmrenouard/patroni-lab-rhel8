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
    html_body = md.render(md_content)

    # Styling (Premium Aesthetic - Dark Mode OLED)
    css = """
    :root {
        --bg-color: #020617; /* Deepest blue/black */
        --card-bg: #0f172a;
        --card-hover: #1e293b;
        --text-color: #f8fafc;
        --text-muted: #94a3b8;
        --accent-color: #38bdf8;
        --primary: #3b82f6;
        --success: #10b981;
        --fail: #ef4444;
        --warning: #f59e0b;
        --border: #1e293b;
        --glow: rgba(56, 189, 248, 0.15);
    }
    
    * { box-sizing: border-box; }
    
    body {
        font-family: 'Fira Sans', system-ui, -apple-system, sans-serif;
        background-color: var(--bg-color);
        color: var(--text-color);
        line-height: 1.6;
        padding: 2rem 1rem;
        max-width: 1100px;
        margin: 0 auto;
    }
    
    .header { 
        text-align: center; 
        margin-bottom: 4rem;
        padding: 2rem;
        background: radial-gradient(circle at center, var(--glow) 0%, transparent 70%);
    }
    
    h1 { 
        font-family: 'Fira Code', monospace;
        color: var(--text-color); 
        font-size: 2.5rem; 
        font-weight: 800;
        letter-spacing: -0.05em; 
        margin-bottom: 0.5rem;
        text-shadow: 0 0 20px var(--glow);
    }
    
    .header p { color: var(--accent-color); font-weight: 600; text-transform: uppercase; letter-spacing: 0.1em; font-size: 0.9rem; }
    
    /* Tables Styling */
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 1.5rem 0;
        background: var(--card-bg);
        border-radius: 8px;
        overflow: hidden;
        border: 1px solid var(--border);
    }
    
    th {
        background: var(--card-hover);
        color: var(--accent-color);
        text-align: left;
        padding: 0.75rem 1rem;
        font-size: 0.85rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    td {
        padding: 0.75rem 1rem;
        border-bottom: 1px solid var(--border);
        font-size: 0.9rem;
    }
    
    tr:last-child td { border-bottom: none; }
    
    tr:hover td { background: rgba(255, 255, 255, 0.02); }
    
    /* Collapsible Sections */
    details {
        background: var(--card-bg);
        border: 1px solid var(--border);
        border-radius: 12px;
        margin-bottom: 1.25rem;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    }
    
    details[open] {
        border-color: var(--primary);
        background: #020617;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 0 15px var(--glow);
    }
    
    summary {
        padding: 1.25rem 1.75rem;
        cursor: pointer;
        display: flex;
        align-items: center;
        list-style: none;
        user-select: none;
    }
    
    summary::-webkit-details-marker { display: none; }
    
    summary:hover { background: var(--card-hover); border-radius: 12px; }
    
    .status-icon {
        margin-right: 1.25rem;
        font-size: 1.25rem;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    
    .summary-title { 
        flex-grow: 1; 
        font-weight: 700; 
        font-size: 1.1rem; 
        color: var(--text-color);
    }
    
    .section-content {
        padding: 0 1.75rem 2rem 1.75rem;
        border-top: 1px solid var(--border);
    }
    
    /* Code Blocks */
    pre {
        background: #000;
        padding: 1.25rem;
        border-radius: 8px;
        overflow-x: auto;
        border: 1px solid var(--border);
        font-family: 'Fira Code', monospace;
        font-size: 0.85rem;
        margin: 1.5rem 0;
        color: #e2e8f0;
    }
    
    code { font-family: 'Fira Code', monospace; }
    
    .status-badge {
        display: inline-flex;
        align-items: center;
        padding: 0.25rem 0.75rem;
        border-radius: 9999px;
        font-size: 0.75rem;
        font-weight: 700;
        letter-spacing: 0.025em;
        margin-left: 1rem;
    }
    
    .status-pass { background: rgba(16, 185, 129, 0.1); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.2); }
    .status-fail { background: rgba(239, 68, 68, 0.1); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.2); }
    
    h3 { 
        color: var(--text-muted); 
        font-size: 0.8rem; 
        text-transform: uppercase; 
        letter-spacing: 0.1em; 
        margin-top: 2rem; 
        margin-bottom: 0.75rem;
        display: flex;
        align-items: center;
    }
    
    h3::after {
        content: "";
        flex-grow: 1;
        height: 1px;
        background: var(--border);
        margin-left: 1rem;
    }
    
    .action-cmd {
        background: #000;
        padding: 0.75rem 1rem;
        border-radius: 8px;
        font-family: 'Fira Code', monospace;
        color: var(--accent-color);
        display: block;
        border-left: 4px solid var(--primary);
        margin: 1rem 0;
        font-size: 0.9rem;
    }
    
    /* Test Blocks */
    .test-block {
        background: rgba(15, 23, 42, 0.5);
        border: 1px solid var(--border);
        border-radius: 10px;
        margin: 1.5rem 0;
        padding: 1.25rem;
        transition: border-color 0.2s;
    }
    
    .test-block:hover { border-color: var(--card-hover); }
    
    .test-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 0.75rem;
    }
    
    .test-title { color: var(--text-color); font-weight: 700; font-size: 1rem; }
    .test-cmd { font-family: 'Fira Code', monospace; font-size: 0.8rem; color: var(--text-muted); }
    
    @media (max-width: 640px) {
        body { padding: 1rem; }
        h1 { font-size: 1.75rem; }
        summary { padding: 1rem; }
        .summary-title { font-size: 1rem; }
    }
    """

    def process_content(content):
        # Specific patterns for individual tests [TEST #n]
        # We try to wrap them in .test-block
        lines = content.split('\n')
        new_content = []
        in_code_block = False
        
        i = 0
        while i < len(lines):
            line = lines[i]
            # Clean line for matching
            clean_line = re.sub(r'\x1B\[[0-9;]*[mK]', '', line)
            
            if line.startswith('```'):
                in_code_block = not in_code_block
                new_content.append(line)
                i += 1
                continue
            
            if not in_code_block and '[TEST #' in clean_line:
                # Start of a test block
                title = clean_line.strip()
                cmd = ""
                result = ""
                error_lines = []
                
                # Look ahead for CMD and RESULT
                j = i + 1
                while j < len(lines) and '[TEST #' not in lines[j] and not lines[j].startswith('##'):
                    l = lines[j]
                    if '[CMD]' in l:
                        cmd = l.replace('[CMD]', '').strip()
                    elif '[RESULT]' in l:
                        result = l.replace('[RESULT]', '').strip()
                        # If FAIL, skip ahead for ERROR OUTPUT
                        if "FAIL" in result:
                            k = j + 1
                            if k < len(lines) and "--- ERROR OUTPUT ---" in lines[k]:
                                k += 1
                                while k < len(lines) and "--------------------" not in lines[k]:
                                    error_lines.append(lines[k].strip('| ').strip())
                                    k += 1
                                j = k
                        break
                    j += 1
                
                # Format the block
                res_class = "status-pass" if "OK" in result else "status-fail"
                res_text = "PASS" if "OK" in result else "FAIL"
                
                block_html = f'<div class="test-block">'
                block_html += f'  <div class="test-header"><span class="test-title">{title}</span><span class="status-badge {res_class}">{res_text}</span></div>'
                if cmd:
                    block_html += f'  <span class="test-cmd"><code>{cmd}</code></span>'
                if error_lines:
                    # Clean up ANSI escape codes
                    err_text = '\n'.join(error_lines)
                    err_text = re.sub(r'\x1B\[[0-9;]*[mK]', '', err_text)
                    block_html += f'  <pre style="border-left: 4px solid var(--fail); background: #0c0a09; color: #fca5a5;"><code>{err_text}</code></pre>'
                block_html += '</div>'
                
                new_content.append(block_html)
                i = j + 1
                continue
            
            new_content.append(line)
            i += 1
            
        return '\n'.join(new_content)

    sections = re.split(r'(<h2.*?>.*?</h2>)', html_body)
    new_html_body = sections[0]
    
    for i in range(1, len(sections), 2):
        header = sections[i]
        content = sections[i+1] if i+1 < len(sections) else ""
        
        # Clean title from header
        title = re.sub(r'<.*?>', '', header)
        badge = ""
        icon = """<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="color: var(--text-muted)"><circle cx="12" cy="12" r="10"></circle></svg>""" 
        
        if "✅ SUCCESS" in content:
            badge = '<span class="status-badge status-pass">COMPLET</span>'
            icon = """<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#34d399" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>"""
            content = content.replace("✅ SUCCESS", "")
        elif "❌ FAIL" in content:
            badge = '<span class="status-badge status-fail">ÉCHEC</span>'
            icon = """<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f87171" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>"""
            content = content.replace("❌ FAIL", "")
            
        # Refined content processing
        content = process_content(content)
        
        # Format Reproduction Command
        content = content.replace("<h3>Reproduction Command</h3>", "<h3>Commande de Reproduction</h3>")
        content = content.replace("<strong>Action :</strong>", "<h3>Commande Exécutée</h3>")
        content = re.sub(r'<code>(.*?\.sh.*?)</code>', r'<span class="action-cmd">\1</span>', content)

        new_html_body += f"""
        <details>
            <summary>
                <span class="status-icon">{icon}</span>
                <span class="summary-title">{title}</span>
                {badge}
            </summary>
            <div class="section-content">
                {content}
            </div>
        </details>
        """

    full_html = f"""
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Patroni Cluster Audit Report</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;700&family=Fira+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        {css}
    </style>
</head>
<body>
    <div class="header">
        <h1>Patroni Lab Audit</h1>
        <p>PostgreSQL High Availability Validation</p>
    </div>
    <div class="container">
        {new_html_body}
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
