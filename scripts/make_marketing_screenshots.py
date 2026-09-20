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
        ("01-list.png",       "hero-bleed",  "24시간 뒤<br>스스로 사라져요", "주차 위치, 사물함, 방 번호만 잠깐"),
        ("02-add.png",        "left-text",   "몇 초면 저장", "종류 고르고 값만 적으면 끝"),
        ("03-onboarding.png", "text-bottom", "머리는 비우고<br>앱에 맡기세요", "기억할 필요 없는 것만 담는 메모"),
        ("04-forget.png",     "dark",        "탭하면 복사<br>밀면 연장", "지울 일도, 쌓일 일도 없어요"),
    ],
    "en": [
        ("01-list.png",       "hero-bleed",  "Gone in<br>24 hours", "Parking spots, locker codes, room numbers"),
        ("02-add.png",        "left-text",   "Saved in seconds", "Pick a type, type the value"),
        ("03-onboarding.png", "text-bottom", "Let the app<br>hold it", "For what you need for a few hours"),
        ("04-forget.png",     "dark",        "Tap to copy,<br>swipe to keep", "Nothing to delete. Nothing piles up."),
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
        subprocess.run([CHROME, "--headless=new", f"--screenshot={out / fname}",
                        f"--window-size={W},{H}", "--force-device-scale-factor=1",
                        "--hide-scrollbars", "--disable-gpu", html_path.as_uri()],
                       check=True, capture_output=True)
        print(f"  {out.relative_to(ROOT)}/{fname}")


if __name__ == "__main__":
    targets = sys.argv[1:] or list(SHOTS)
    for loc in targets:
        print(f"── {loc}")
        render(loc)
