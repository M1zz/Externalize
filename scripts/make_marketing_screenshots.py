#!/usr/bin/env python3
"""앱스토어 마케팅 스크린샷 생성: 원본 캡처 + 헤드라인 → 헤드리스 Chrome 렌더링.

  docs/screenshots/raw/<언어>/NN-*.png   원본 (시뮬레이터 1320×2868)
        ↓  이 스크립트
  docs/screenshots/marketing/<언어>/NN-*.png   제출본 (1242×2688)

DeployBar 가 배포할 때 marketing/ 을 읽어 App Store Connect 에 올린다.
다음 릴리즈에는 원본만 다시 찍고 이 스크립트를 다시 돌리면 된다.
"""
import subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS_DIR = ROOT / "docs" / "screenshots"
WORK = pathlib.Path(__file__).parent / ".marketing-build"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688          # App Store 제출 규격 (6.5")

# 언어별 (파일명, 레이아웃, 헤드라인, 서브카피)
SHOTS = {
    "ko": [
        ("01-main.png",     "hero-bleed",  "떠오른 할 일,<br>적고 잊으세요", "“아 맞다, 그거 해야 하는데” 할 때 바로"),
        ("02-typing.png",   "left-text",   "몇 글자면 끝", "목록도 폴더도 마감일도 없어요"),
        ("03-review.png",   "text-bottom", "저녁에 하나씩<br>결말을 내요", "하기, 시간 정하기, 버리기 중 하나로"),
        ("04-schedule.png", "flat-rotate", "미룰 거면<br>시간을 정해요", "그 시간에 다시 알려 드려요"),
        ("05-donow.png",    "left-text",   "2분이면 끝날 일은<br>지금 바로", "타이머 켜고 하고 오세요"),
        ("06-clear.png",    "dark",        "목록이 비면<br>머리도 비어요", "쌓여서 썩는 건 없어요"),
    ],
    "en": [
        ("01-main.png",     "hero-bleed",  "Get it out<br>of your head", "Write it down the moment it pops up"),
        ("02-typing.png",   "left-text",   "A few words<br>and you're done", "No lists, no folders, no due dates"),
        ("03-review.png",   "text-bottom", "Settle them<br>in the evening", "Do it, schedule it, or drop it"),
        ("04-schedule.png", "flat-rotate", "Not now?<br>Pick a time", "It comes back right when you said"),
        ("05-donow.png",    "left-text",   "Two minutes?<br>Just do it", "Start the timer and come back"),
        ("06-clear.png",    "dark",        "Clear list,<br>clear head", "Nothing is left to rot"),
    ],
}

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:#f2f2f7; font-family:-apple-system, "Apple SD Gothic Neo", sans-serif; position:relative; }}
.headline {{ font-size:96px; font-weight:800; color:#141416; letter-spacing:-2px; line-height:1.22; }}
.sub {{ font-size:46px; font-weight:500; color:#9a9aa0; letter-spacing:-1px; line-height:1.35; }}
.phone {{ background:#17171a; border-radius:110px; border:3px solid #3a3a3e; padding:22px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.26), 20px 30px 50px rgba(0,0,0,.16); }}
.phone img {{ width:100%; display:block; border-radius:88px; }}
"""

LAYOUTS = {
    "hero-bleed": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:140px; }
.phone { width:930px; }
""",
    "left-text": """
.headline { text-align:left; margin:270px 0 0 100px; }
.sub { text-align:left; margin:44px 100px 0 104px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:270px; top:940px; }
.phone { width:790px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:150px; }
.phone { width:820px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:110px; padding:0 70px; }
.sub { text-align:center; margin-top:42px; padding:0 80px; }
""",
    "flat-rotate": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { position:absolute; left:150px; top:900px; }
.phone { width:900px; transform:rotate(-5deg); }
""",
    "dark": """
body { background:#131316; }
.headline { color:#f5f5f7; text-align:center; margin-top:250px; padding:0 70px; }
.sub { color:#77777d; text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:140px; }
.phone { width:870px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(108,99,255,.25), 40px 70px 110px rgba(0,0,0,.55); }
""",
}

BODY_TEXT_FIRST = '<div class="headline">{headline}</div><div class="sub">{sub}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
BODY_PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{headline}</div><div class="sub">{sub}</div>'
HTML = """<!doctype html><html><head><meta charset="utf-8"><style>
{base}{layout}
</style></head><body>{body}</body></html>"""


def render(locale):
    src = SHOTS_DIR / "raw" / locale
    out = SHOTS_DIR / "marketing" / locale
    out.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    for fname, layout, headline, sub in SHOTS[locale]:
        img = src / fname
        if not img.exists():
            print(f"  건너뜀 — 원본 없음: {img}")
            continue
        body_tpl = BODY_PHONE_FIRST if layout == "text-bottom" else BODY_TEXT_FIRST
        body = body_tpl.format(headline=headline, sub=sub, img=img.as_uri())
        html_path = WORK / f"{locale}-{fname.replace('.png', '.html')}"
        html_path.write_text(HTML.format(base=BASE_CSS, layout=LAYOUTS[layout], body=body), encoding="utf-8")
        # 다른 세션의 Chrome 과 겹치면 가끔 실패하거나 끝나지 않는다 — 새 프로필로 다시 시도한다.
        for attempt in range(4):
            (out / fname).unlink(missing_ok=True)
            try:
                subprocess.run([CHROME, "--headless=new", f"--screenshot={out / fname}",
                                f"--window-size={W},{H}", "--force-device-scale-factor=1",
                                "--hide-scrollbars", "--disable-gpu", "--no-first-run",
                                f"--user-data-dir={WORK / f'chrome-{attempt}'}", html_path.as_uri()],
                               capture_output=True, timeout=40)
            except subprocess.TimeoutExpired:
                pass
            if (out / fname).exists() and (out / fname).stat().st_size > 0:
                break
        else:
            sys.exit(f"렌더 실패: {out / fname}")
        print(f"  {out.relative_to(ROOT)}/{fname}")


if __name__ == "__main__":
    targets = sys.argv[1:] or list(SHOTS)
    for loc in targets:
        print(f"── {loc}")
        render(loc)
