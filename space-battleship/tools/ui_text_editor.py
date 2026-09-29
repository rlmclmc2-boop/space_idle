"""Local-only UI copy editor. Only the text column is writable."""
import argparse
import hashlib
import json
import os
import secrets
import tempfile
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from ui_text import CATALOG, CONTRACT, ROOT, validate, t


def revision(raw):
    return hashlib.sha256(raw).hexdigest()


def read_document():
    raw = CATALOG.read_bytes()
    rows = json.loads(raw)
    contract = json.loads(CONTRACT.read_text(encoding='utf-8'))['entries']
    for row in rows:
        row['params'] = ','.join('{' + p + '}' for p in contract[row['key']]['params'])
    return {'rows': rows, 'revision': revision(raw), 'errors': validate(rows, contract)}


def save_document(request):
    raw = CATALOG.read_bytes()
    if request.get('revision') != revision(raw):
        raise ValueError(t('system.editor.conflict'))
    rows = json.loads(raw)
    edits = request.get('texts')
    if not isinstance(edits, dict) or set(edits) != {row['key'] for row in rows}:
        raise ValueError(t('system.editor.invalid_keys'))
    contract = json.loads(CONTRACT.read_text(encoding='utf-8'))['entries']
    for row in rows:
        row['text'] = edits[row['key']]
    errors = validate(rows, contract)
    if errors:
        raise ValueError('\n'.join(errors))
    return write_document(raw, rows, 'system.editor.saved')


def set_deleted(request):
    raw = CATALOG.read_bytes()
    if request.get('revision') != revision(raw):
        raise ValueError(t('system.editor.conflict'))
    rows = json.loads(raw)
    row = next((r for r in rows if r['key'] == request.get('key')), None)
    if row is None or type(request.get('deleted')) is not bool:
        raise ValueError(t('system.editor.invalid_keys'))
    if request['deleted']:
        row['deleted'] = True
    else:
        row.pop('deleted', None)
    errors = validate(rows)
    if errors:
        raise ValueError('\n'.join(errors))
    return write_document(raw, rows, 'system.editor.deleted_saved' if request['deleted'] else 'system.editor.restored')


def write_document(raw, rows, message_key):
    output = (json.dumps(rows, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    if output != raw:
        # All validation precedes any write. Never touch game_data or player saves.
        runtime = ROOT / '.runtime'
        runtime.mkdir(exist_ok=True)
        (runtime / 'ui_text.backup.json').write_bytes(raw)
        fd, path = tempfile.mkstemp(prefix='.ui_text-', suffix='.tmp', dir=CATALOG.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(output)
                stream.flush()
                os.fsync(stream.fileno())
            if CATALOG.read_bytes() != raw:
                raise ValueError(t('system.editor.conflict_save'))
            os.replace(path, CATALOG)
        finally:
            if os.path.exists(path):
                os.unlink(path)
    return {'revision': revision(output), 'message': t(message_key)}


def render_html():
    import html as escape_html
    rows = json.loads(CATALOG.read_text(encoding='utf-8'))
    labels = {r['key'].removeprefix('system.editor.'): r['text'] for r in rows if r['key'].startswith('system.editor.')}
    categories = {r['key'].removeprefix('system.category.'): r['text'] for r in rows if r['key'].startswith('system.category.')}
    page = Path(__file__).with_suffix('.html').read_text(encoding='utf-8')
    for key, value in labels.items():
        page = page.replace('__UI_' + key + '__', escape_html.escape(value, quote=True))
    # Text containing closing script tags cannot escape the JSON string.
    page = page.replace('__LABELS__', json.dumps(labels, ensure_ascii=True).replace('<', '\\u003c'))
    return page.replace('__CATEGORIES__', json.dumps(categories, ensure_ascii=True).replace('<', '\\u003c'))


def make_server():
    token = secrets.token_urlsafe(32)
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def send(self, status, content, kind='application/json; charset=utf-8'):
            body = content.encode('utf-8') if isinstance(content, str) else json.dumps(content, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def authorized(self):
            origin = self.headers.get('Origin')
            expected = f'http://127.0.0.1:{self.server.server_port}'
            return self.headers.get('X-UI-Token') == token and (not origin or origin == expected)

        def do_GET(self):
            if self.path == '/?token=' + token:
                html = render_html()
                self.send(200, html.replace('__TOKEN__', token), 'text/html; charset=utf-8')
            elif self.path == '/catalog' and self.authorized():
                self.send(200, read_document())
            else:
                self.send(403, {'error': 'Forbidden'})

        def do_POST(self):
            if not self.authorized() or self.path not in ('/save', '/deleted') or self.headers.get('Content-Type') != 'application/json':
                self.send(403, {'error': 'Forbidden'})
                return
            try:
                length = int(self.headers.get('Content-Length', 0))
                if not 0 < length <= 4_000_000:
                    raise ValueError('Invalid request size')
                request = json.loads(self.rfile.read(length))
                if not isinstance(request, dict):
                    raise ValueError('Invalid request')
                with lock:
                    result = save_document(request) if self.path == '/save' else set_deleted(request)
                self.send(200, result)
            except (ValueError, OSError, TypeError) as error:
                self.send(400, {'error': str(error)})

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    return server, f'http://127.0.0.1:{server.server_port}/?token={token}'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--no-browser', action='store_true')
    args = parser.parse_args()
    if args.check:
        document = read_document()
        print('\n'.join(document['errors']) or f"UI catalog: {len(document['rows'])} rows, valid")
        raise SystemExit(bool(document['errors']))
    server, url = make_server()
    print(url, flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
