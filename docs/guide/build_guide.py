"""Builds guide.html (then print to PDF with headless Chrome).
Keeps the agent prompt in sync with ../NOMCUT-AGENT-SETUP-PROMPT.txt. Styles live in style.css next to this file."""
import html
from pathlib import Path

here = Path(__file__).parent
prompt = (here.parent / 'NOMCUT-AGENT-SETUP-PROMPT.txt').read_text(encoding='utf-8').strip()
css = (here / 'style.css').read_text(encoding='utf-8')
GH = 'github.com/StingLikeABeee/NomCut'


_count = [0]


def foot(_unused=None):
    _count[0] += 1          # pages are built in order, so this is the page number (the cover has none)
    return f'<div class="foot"><span>NomCut Studio · by Nouman Arif · ★ Star: {GH}</span><span>{_count[0]}</span></div>'


def both(en, hi):
    return f'<div class="cols"><div><span class="lg">EN</span>{en}</div><div class="hi"><span class="lg">हिं</span>{hi}</div></div>'


def tile(icon, title, en, hi):
    return f'<div class="tile"><div class="ic">{icon}</div><b>{title}</b><p>{en}</p><p class="hi">{hi}</p></div>'


def step(n, en, hi):
    return f'<div class="stp"><div class="num">{n}</div><div><b>{en}</b><div class="hi">{hi}</div></div></div>'


def row(a, en, hi):
    return f'<tr><td><b>{a}</b></td><td>{en}</td><td class="hi">{hi}</td></tr>'


pages = []

pages.append(f'''<section class="page cover"><div class="sun"></div><div class="grid"></div>
<div class="txt"><div class="kicker">AI HIGHLIGHT STUDIO</div><h1>NOM<br><em>CUT</em></h1>
<p>Drop a link. Generate captioned 9:16 vertical shorts in under two minutes. Free &amp; local.<br><span class="hi">लिंक पेस्ट करो। दो मिनट में कैप्शन वाली 9:16 क्लिप पाओ। फ्री। आपके अपने कंप्यूटर पर।</span></p>
<p style="margin-top:8mm"><span class="chip">★ Star on GitHub</span><span class="chip ig">Follow @itx_noumanarif</span></p><p style="font-size:11pt">{GH}</p></div>
<div class="by">Crafted by <span>Nouman Arif</span> · Instagram @itx_noumanarif · Quick Start Guide</div></section>''')

pages.append(f'''<section class="page"><h2><span class="n">01</span>What you get <span class="hi sub">· आपको क्या मिलता है</span></h2>
<img class="shot" src="home.jpg" style="width:100%">
<div class="tiles">
{tile("⚡", "Single click", "Paste a YouTube, Twitch or Kick link, press Auto-cut clips.", "लिंक पेस्ट करो, Auto-cut clips दबाओ।")}
{tile("💬", "Hinglish captions", "Hindi speech written in Roman letters, 2–4 words at a time, active word highlighted.", "हिंदी बोली अंग्रेज़ी अक्षरों में, 2–4 शब्द करके, बोला जा रहा शब्द चमकता है।")}
{tile("🎮", "Facecam + gameplay", "Pick where the webcam is. Face on top, game below, ready for Reels and Shorts.", "वेबकैम कहाँ है चुनो। ऊपर चेहरा, नीचे गेम, Reels/Shorts के लिए तैयार।")}
{tile("🔒", "Free and private", "Runs on your computer. No account, no subscription, nothing uploaded.", "आपके कंप्यूटर पर चलता है। न अकाउंट, न सब्सक्रिप्शन, कुछ अपलोड नहीं।")}
</div>
<div class="note"><b>Fast:</b> 85-minute stream → 3 vertical shorts in ~2 minutes (fetches only peak segments, not the entire file).</div>
{foot("1")}</section>''')

pages.append(f'''<section class="page"><h2><span class="n">02</span>AI Agent Setup <span class="hi sub">· एक पेस्ट में सेटअप</span></h2>
<p class="lead">Let your AI coding agent handle the entire installation automatically.</p>
<div class="steps">
{step(1, "Open an AI agent that can run commands on your computer: Claude Code, OpenAI Codex, Google Antigravity or Cursor.", "ऐसा AI agent खोलो जो आपके कंप्यूटर पर कमांड चला सके।")}
{step(2, "Copy the prompt from docs/NOMCUT-AGENT-SETUP-PROMPT.txt and paste it.", "प्रॉम्प्ट कॉपी करके पेस्ट करो और Enter दबाओ।")}
{step(3, "Confirm when prompted. It checks your PC, installs missing tools, starts NomCut and opens your browser.", "वह आपका कंप्यूटर जाँचेगा, जो कम है वो इंस्टॉल करेगा, और NomCut चालू कर देगा।")}
</div>
<pre class="pr">{html.escape(prompt)}</pre>
{foot("2")}</section>''')

pages.append(f'''<section class="page"><h2><span class="n">03</span>Support &amp; Community</h2>
<div class="cta"><h3>Enjoying NomCut? Star the repo ★</h3>
<p><b>Your GitHub star helps NomCut grow and reach more creators.</b><br><br>
★ <a href="https://github.com/StingLikeABeee/NomCut">{GH}</a><br>📷 Instagram: <a href="https://www.instagram.com/itx_noumanarif/">@itx_noumanarif</a> · Crafted by <b>Nouman Arif</b></p></div>
{foot("3")}</section>''')

doc = ('<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><title>NomCut Studio Guide</title>\n'
       f'<style>{css}</style></head><body>\n' + '\n'.join(pages) + '\n</body></html>')
(here / 'guide.html').write_text(doc, encoding='utf-8')
print('pages', len(pages), 'bytes', len(doc))
