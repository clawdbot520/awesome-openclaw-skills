#!/usr/bin/env python3
"""
Send a message to Antigravity IDE via CDP (Chrome DevTools Protocol).
Usage: ask_antigravity.py <message>
"""
import sys
import json
import time
import subprocess
import urllib.request

def get_antigravity_page_id():
    with urllib.request.urlopen('http://localhost:9222/json') as r:
        pages = json.loads(r.read())
    for p in pages:
        if 'workspace-antigravity' in p.get('title', ''):
            return p['id']
    return None

def send_to_ide(message, page_id):
    try:
        import websocket
    except ImportError:
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'websocket-client', '-q'])
        import websocket

    ws = websocket.create_connection(f'ws://localhost:9222/devtools/page/{page_id}')

    def cdp(id, expr):
        ws.send(json.dumps({'id': id, 'method': 'Runtime.evaluate',
                            'params': {'expression': expr, 'returnByValue': True}}))
        return json.loads(ws.recv())

    # Put message in clipboard
    subprocess.run(['pbcopy'], input=message.encode(), check=True)
    time.sleep(0.1)

    # Paste into chat input
    cdp(1, """(function(){
  const inputs = document.querySelectorAll("div[role='textbox']");
  const chat = Array.from(inputs).find(e => !e.classList.contains('native-edit-context'));
  if (!chat) return 'not found';
  chat.focus();
  document.execCommand('paste');
  return 'ok';
})()""")
    time.sleep(0.3)

    # Press Enter to submit
    cdp(2, """(function(){
  const inputs = document.querySelectorAll("div[role='textbox']");
  const chat = Array.from(inputs).find(e => !e.classList.contains('native-edit-context'));
  if (!chat) return 'not found';
  chat.dispatchEvent(new KeyboardEvent('keydown', {key:'Enter',code:'Enter',keyCode:13,bubbles:true}));
  return 'ok';
})()""")
    ws.close()

def main():
    prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "hello"

    page_id = get_antigravity_page_id()
    if not page_id:
        print("ERROR: Antigravity workspace page not found via CDP", file=sys.stderr)
        sys.exit(1)

    send_to_ide(prompt, page_id)
    print(f"Message sent to Antigravity IDE (page: {page_id})")

if __name__ == '__main__':
    main()
