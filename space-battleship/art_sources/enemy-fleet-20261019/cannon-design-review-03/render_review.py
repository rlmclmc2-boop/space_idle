"""Render the static HTML art review at device scale 1; does not launch Godot."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from functools import partial
from threading import Thread
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
Thread(target=server.serve_forever,daemon=True).start()
try:
    with sync_playwright() as w:
        browser=w.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
        page=browser.new_page(viewport={'width':1240,'height':1100},device_scale_factor=1)
        url='http://127.0.0.1:'+str(server.server_port)+'/'+str((HERE/'review.html').relative_to(ROOT))
        page.goto(url,wait_until='networkidle')
        broken=page.locator('img').evaluate_all('(xs)=>xs.filter(x=>!x.complete||x.naturalWidth===0).map(x=>x.src)')
        assert not broken,broken
        page.locator('.board').screenshot(path=str(HERE/'design-board.png'))
        print('DESIGN_BOARD PASS image references loaded; native 1x browser capture')
        browser.close()
finally:
    server.shutdown();server.server_close()
