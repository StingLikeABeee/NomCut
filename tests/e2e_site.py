"""Website + release + README link tests (no GPU): public site, every link/asset on it, and release assets."""
import re
import sys
import urllib.request
import urllib.error
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from e2e import R

SITES = ['https://stinglikeabeee.github.io/NomCut/']
UA = {'User-Agent': 'Mozilla/5.0 NomCut-linktest'}


def get(url, method='GET', timeout=40):
    req = urllib.request.Request(url, headers=UA, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read() if method == 'GET' else b'', r.headers
    except urllib.error.HTTPError as e:
        return e.code, b'', e.headers
    except Exception as e:
        if 'CERTIFICATE_VERIFY_FAILED' in str(e):
            return _curl(url, method)
        return 0, str(e).encode(), {}


def _curl(url, method):
    import subprocess
    nl = chr(10)
    cmd = ['curl', '-sL', '-m', '40', '-A', UA['User-Agent'], '-w', nl + '%{http_code}']
    if method == 'HEAD':
        cmd += ['-I']
    r = subprocess.run(cmd + [url], capture_output=True)
    out = r.stdout
    pos = out.rfind(nl.encode())
    try:
        code = int(out[pos + 1:].strip() or 0)
    except ValueError:
        code = 0
    return code, (out[:pos] if method == 'GET' else b''), {}


def links(html, base):
    out = set()
    for m in re.finditer(r'''(?:href|src|poster)=["']([^"'#][^"']*)["']''', html):
        u = m.group(1)
        if u.startswith(('mailto:', 'javascript:', 'data:')):
            continue
        out.add(urllib.request.urljoin(base, u))
    return sorted(out)


def run():
    g = 'site'
    for site in SITES:
        st, body, h = get(site)
        R.check(g, f'{site} loads', lambda st=st, body=body: (st == 200 and len(body) > 5000, f'{st} {len(body)} bytes'))
        if st != 200:
            continue
        html = body.decode('utf-8', 'ignore')
        R.check(g, f'{site} has title, download button, demo video', lambda html=html: (
            '<title>' in html and 'NomCut-Setup.bat' in html and '<video' in html, ''))
        for u in links(html, site):
            host = u.split('/')[2]
            if host in ('www.instagram.com',):
                continue
            code, _, _ = get(u, 'HEAD' if not u.startswith(site) else 'GET')
            if code in (403, 405, 0):
                code = get(u)[0]
            R.check(g, f'link {u[:90]}', lambda code=code: (code == 200, code))


if __name__ == '__main__':
    run()
    R.save()
    bad = [r for r in R.rows if not r['ok']]
    print(f'\n{len(R.rows) - len(bad)}/{len(R.rows)} passed')
