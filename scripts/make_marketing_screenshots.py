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
    "en-GB": [
        ("01-main.png", "hero-bleed", "Get it out<br>of your head", "Jot it down the moment it comes to you"),
        ("02-typing.png", "left-text", "A few words<br>and you're done", "No lists, no folders, no due dates"),
        ("03-review.png", "text-bottom", "Sort them out<br>in the evening", "Do it, schedule it or drop it"),
        ("04-schedule.png", "flat-rotate", "Not now?<br>Pick a time", "It comes back right when you said"),
        ("05-donow.png", "left-text", "Two minutes?<br>Just do it", "Start the timer and come back"),
        ("06-clear.png", "dark", "Clear list,<br>clear head", "Nothing is left to go stale"),
    ],
    "zh-Hans": [
        ("01-main.png", "hero-bleed", "想到就记，<br>然后忘掉", "“啊对了，我得……”的时候，马上记下"),
        ("02-typing.png", "left-text", "写几个字就行", "没有清单、文件夹，也没有截止日期"),
        ("03-review.png", "text-bottom", "晚上逐项<br>给个了结", "现在做、定个时间或不做了"),
        ("04-schedule.png", "flat-rotate", "现在不做？<br>那就定个时间", "到点准时再提醒你"),
        ("05-donow.png", "left-text", "两分钟能搞定，<br>就现在做", "开个计时，做完再回来"),
        ("06-clear.png", "dark", "清单空了，<br>脑子也空了", "不会越积越多"),
    ],
    "zh-Hant": [
        ("01-main.png", "hero-bleed", "想到就記，<br>然後忘掉", "「啊對了，我得……」的時候，馬上記下"),
        ("02-typing.png", "left-text", "寫幾個字就行", "沒有清單、資料夾，也沒有截止日期"),
        ("03-review.png", "text-bottom", "晚上逐項<br>給個了結", "現在做、訂個時間或不做了"),
        ("04-schedule.png", "flat-rotate", "現在不做？<br>那就訂個時間", "到點準時再提醒你"),
        ("05-donow.png", "left-text", "兩分鐘能搞定，<br>就現在做", "開個計時，做完再回來"),
        ("06-clear.png", "dark", "清單空了，<br>腦袋也空了", "不會越積越多"),
    ],
    "ja": [
        ("01-main.png", "hero-bleed", "思いついたら、<br>書いて忘れよう", "「あ、あれやらなきゃ」のときに、すぐ書ける"),
        ("02-typing.png", "left-text", "数文字で完了", "リストもフォルダも期限もなし"),
        ("03-review.png", "text-bottom", "夜に、ひとつずつ<br>結論を出す", "今やる・時間を決める・捨てる、から選ぶ"),
        ("04-schedule.png", "flat-rotate", "今できないなら<br>時間を決めよう", "決めた時間に、もう一度お知らせ"),
        ("05-donow.png", "left-text", "2分で終わるなら<br>今すぐ", "タイマーを押して、やってこよう"),
        ("06-clear.png", "dark", "リストが空なら<br>頭もすっきり", "たまって腐るものはありません"),
    ],
    "ru": [
        ("01-main.png", "hero-bleed", "Вынесите это<br>из головы", "Запишите, как только мысль пришла"),
        ("02-typing.png", "left-text", "Пара слов —<br>и готово", "Ни списков, ни папок, ни сроков"),
        ("03-review.png", "text-bottom", "Вечером разберите<br>всё по одному", "Сделать, назначить время или отбросить"),
        ("04-schedule.png", "flat-rotate", "Не сейчас?<br>Назначьте время", "Напомним точно в срок"),
        ("05-donow.png", "left-text", "Две минуты?<br>Сделайте сразу", "Включите таймер и возвращайтесь"),
        ("06-clear.png", "dark", "Пустой список —<br>свободная голова", "Ничто не залежится"),
    ],
    "es": [
        ("01-main.png", "hero-bleed", "Sácalo<br>de tu cabeza", "Anótalo en cuanto se te ocurra"),
        ("02-typing.png", "left-text", "Unas palabras<br>y listo", "Sin listas, sin carpetas, sin fechas límite"),
        ("03-review.png", "text-bottom", "Resuélvelo<br>por la noche", "Hazlo, prográmalo o descártalo"),
        ("04-schedule.png", "flat-rotate", "¿Ahora no?<br>Elige una hora", "Vuelve justo cuando dijiste"),
        ("05-donow.png", "left-text", "¿Dos minutos?<br>Hazlo ya", "Pon el temporizador y vuelve"),
        ("06-clear.png", "dark", "Lista vacía,<br>mente despejada", "Nada se queda pudriéndose"),
    ],
    "de": [
        ("01-main.png", "hero-bleed", "Raus aus<br>dem Kopf", "Schreib es auf, sobald es dir einfällt"),
        ("02-typing.png", "left-text", "Ein paar Worte,<br>fertig", "Keine Listen, keine Ordner, keine Fristen"),
        ("03-review.png", "text-bottom", "Am Abend<br>abschließen", "Erledigen, planen oder verwerfen"),
        ("04-schedule.png", "flat-rotate", "Gerade nicht?<br>Zeit wählen", "Es kommt genau dann zurück"),
        ("05-donow.png", "left-text", "Zwei Minuten?<br>Mach es gleich", "Timer starten und loslegen"),
        ("06-clear.png", "dark", "Leere Liste,<br>freier Kopf", "Nichts bleibt liegen"),
    ],
    "fr": [
        ("01-main.png", "hero-bleed", "Sortez-le<br>de votre tête", "Notez-le dès que ça vous vient"),
        ("02-typing.png", "left-text", "Quelques mots<br>et c’est fait", "Ni listes, ni dossiers, ni échéances"),
        ("03-review.png", "text-bottom", "Le soir, réglez<br>chaque chose", "Faire, planifier ou abandonner"),
        ("04-schedule.png", "flat-rotate", "Pas maintenant ?<br>Choisissez l’heure", "Ça revient à l’heure dite"),
        ("05-donow.png", "left-text", "Deux minutes ?<br>Faites-le", "Lancez le minuteur, puis revenez"),
        ("06-clear.png", "dark", "Liste vide,<br>esprit libre", "Rien ne traîne"),
    ],
    "it": [
        ("01-main.png", "hero-bleed", "Toglilo<br>dalla testa", "Scrivilo appena ti viene in mente"),
        ("02-typing.png", "left-text", "Due parole<br>e hai finito", "Niente liste, cartelle o scadenze"),
        ("03-review.png", "text-bottom", "La sera,<br>chiudi tutto", "Fallo, programmalo o lascia perdere"),
        ("04-schedule.png", "flat-rotate", "Non ora?<br>Scegli l’orario", "Torna proprio quando hai detto"),
        ("05-donow.png", "left-text", "Due minuti?<br>Fallo subito", "Avvia il timer e torna"),
        ("06-clear.png", "dark", "Lista vuota,<br>testa libera", "Niente resta a marcire"),
    ],
    "pt-BR": [
        ("01-main.png", "hero-bleed", "Tire isso<br>da cabeça", "Anote assim que vier à mente"),
        ("02-typing.png", "left-text", "Poucas palavras<br>e pronto", "Sem listas, sem pastas, sem prazos"),
        ("03-review.png", "text-bottom", "Resolva tudo<br>à noite", "Faça, agende ou descarte"),
        ("04-schedule.png", "flat-rotate", "Agora não?<br>Escolha a hora", "Volta exatamente na hora marcada"),
        ("05-donow.png", "left-text", "Dois minutos?<br>Faça já", "Ligue o timer e volte"),
        ("06-clear.png", "dark", "Lista vazia,<br>cabeça leve", "Nada fica acumulando"),
    ],
    "th": [
        ("01-main.png", "hero-bleed", "ดึงออกจากหัว<br>ก่อนลืม", "จดทันทีที่มีอะไรผุดขึ้นมา"),
        ("02-typing.png", "left-text", "พิมพ์ไม่กี่คำ<br>ก็เสร็จ", "ไม่มีลิสต์ ไม่มีโฟลเดอร์ ไม่มีกำหนดส่ง"),
        ("03-review.png", "text-bottom", "ตอนเย็นค่อย<br>สะสางทีละเรื่อง", "ทำเลย กำหนดเวลา หรือทิ้งไป"),
        ("04-schedule.png", "flat-rotate", "ยังไม่ว่าง?<br>เลือกเวลาไว้", "จะกลับมาตรงเวลาที่เลือก"),
        ("05-donow.png", "left-text", "แค่ 2 นาที<br>ทำเลย", "เปิดตัวจับเวลาแล้วไปทำให้เสร็จ"),
        ("06-clear.png", "dark", "ลิสต์โล่ง<br>หัวก็โล่ง", "ไม่มีอะไรค้างจนเน่า"),
    ],
    "vi": [
        ("01-main.png", "hero-bleed", "Đưa việc vừa nghĩ ra<br>khỏi đầu", "Ghi lại ngay khi chợt nhớ"),
        ("02-typing.png", "left-text", "Chỉ vài chữ<br>là xong", "Không danh sách, không thư mục, không hạn chót"),
        ("03-review.png", "text-bottom", "Tối đến giải quyết<br>từng việc", "Làm ngay, hẹn giờ hoặc bỏ đi"),
        ("04-schedule.png", "flat-rotate", "Chưa làm được?<br>Hẹn giờ nhé", "Đúng giờ đó, việc sẽ quay lại"),
        ("05-donow.png", "left-text", "Hai phút thôi?<br>Làm luôn", "Bật hẹn giờ rồi quay lại"),
        ("06-clear.png", "dark", "Danh sách trống,<br>đầu óc nhẹ", "Không việc nào bị bỏ quên"),
    ],
    "cs": [
        ("01-main.png", "hero-bleed", "Dostaňte to<br>z hlavy", "Zapište to hned, jak vás to napadne"),
        ("02-typing.png", "left-text", "Pár slov<br>a je hotovo", "Žádné seznamy, složky ani termíny"),
        ("03-review.png", "text-bottom", "Večer vyřešte<br>vše jedno po druhém", "Udělat, naplánovat, nebo zahodit"),
        ("04-schedule.png", "flat-rotate", "Teď ne?<br>Určete čas", "Vrátí se přesně, kdy chcete"),
        ("05-donow.png", "left-text", "Dvě minuty?<br>Udělejte to hned", "Zapněte časovač a vraťte se"),
        ("06-clear.png", "dark", "Prázdný seznam,<br>čistá hlava", "Nic se nehromadí"),
    ],
    "da": [
        ("01-main.png", "hero-bleed", "Få det ud<br>af hovedet", "Skriv det ned i det øjeblik, det dukker op"),
        ("02-typing.png", "left-text", "Et par ord,<br>så er du færdig", "Ingen lister, mapper eller deadlines"),
        ("03-review.png", "text-bottom", "Afgør alt<br>om aftenen", "Gør det, vælg et tidspunkt eller drop det"),
        ("04-schedule.png", "flat-rotate", "Ikke nu?<br>Vælg et tidspunkt", "Det kommer tilbage lige da"),
        ("05-donow.png", "left-text", "To minutter?<br>Gør det nu", "Start timeren, og kom tilbage"),
        ("06-clear.png", "dark", "Tom liste,<br>frit hoved", "Intet bliver liggende og rådne"),
    ],
    "el": [
        ("01-main.png", "hero-bleed", "Βγάλε το από<br>το μυαλό σου", "Σημείωσέ το μόλις σου έρθει"),
        ("02-typing.png", "left-text", "Λίγες λέξεις<br>και τελείωσες", "Χωρίς λίστες, φακέλους, προθεσμίες"),
        ("03-review.png", "text-bottom", "Κλείσε τα όλα<br>το βράδυ", "Κάνε το, όρισε ώρα ή πέτα το"),
        ("04-schedule.png", "flat-rotate", "Όχι τώρα;<br>Όρισε ώρα", "Επιστρέφει όταν το ορίσεις"),
        ("05-donow.png", "left-text", "Δύο λεπτά;<br>Κάνε το τώρα", "Ξεκίνα το χρονόμετρο και πήγαινε"),
        ("06-clear.png", "dark", "Καθαρή λίστα,<br>καθαρό μυαλό", "Τίποτα δεν μένει να σαπίζει"),
    ],
    "fi": [
        ("01-main.png", "hero-bleed", "Pois päästä,<br>talteen", "Kirjaa ylös heti, kun mieleen tulee"),
        ("02-typing.png", "left-text", "Muutama sana,<br>ja valmista", "Ei listoja, ei kansioita, ei määräaikoja"),
        ("03-review.png", "text-bottom", "Päätä asiat<br>illalla", "Tee, ajasta tai hylkää"),
        ("04-schedule.png", "flat-rotate", "Ei nyt?<br>Valitse aika", "Se palaa juuri silloin kuin sovit"),
        ("05-donow.png", "left-text", "Kaksi minuuttia?<br>Tee heti", "Käynnistä ajastin ja palaa"),
        ("06-clear.png", "dark", "Tyhjä lista,<br>kevyt mieli", "Mikään ei jää lahoamaan"),
    ],
    "id": [
        ("01-main.png", "hero-bleed", "Keluarkan dari<br>kepalamu", "Catat begitu terlintas"),
        ("02-typing.png", "left-text", "Cukup beberapa<br>kata", "Tanpa daftar, folder, atau tenggat"),
        ("03-review.png", "text-bottom", "Selesaikan<br>di malam hari", "Kerjakan, jadwalkan, atau buang"),
        ("04-schedule.png", "flat-rotate", "Belum sempat?<br>Pilih waktunya", "Kembali tepat saat kamu minta"),
        ("05-donow.png", "left-text", "Dua menit?<br>Langsung saja", "Nyalakan timer, lalu kembali"),
        ("06-clear.png", "dark", "Daftar kosong,<br>kepala lega", "Tak ada yang menumpuk jadi basi"),
    ],
    "nb": [
        ("01-main.png", "hero-bleed", "Få det ut<br>av hodet", "Skriv det ned i det øyeblikket det dukker opp"),
        ("02-typing.png", "left-text", "Noen få ord,<br>så er du ferdig", "Ingen lister, mapper eller frister"),
        ("03-review.png", "text-bottom", "Avgjør alt<br>om kvelden", "Gjør det, sett en tid eller dropp det"),
        ("04-schedule.png", "flat-rotate", "Ikke nå?<br>Velg et tidspunkt", "Det kommer tilbake akkurat da"),
        ("05-donow.png", "left-text", "To minutter?<br>Gjør det nå", "Start timeren og kom tilbake"),
        ("06-clear.png", "dark", "Tom liste,<br>ryddig hode", "Ingenting blir liggende og råtne"),
    ],
    "nl": [
        ("01-main.png", "hero-bleed", "Haal het uit<br>je hoofd", "Noteer het meteen als het opkomt"),
        ("02-typing.png", "left-text", "Een paar woorden<br>en klaar", "Geen lijsten, mappen of deadlines"),
        ("03-review.png", "text-bottom", "Los alles op<br>in de avond", "Doe het, plan het of gooi het weg"),
        ("04-schedule.png", "flat-rotate", "Nu niet?<br>Kies een tijd", "Het komt terug precies wanneer jij wilt"),
        ("05-donow.png", "left-text", "Twee minuten?<br>Doe het nu", "Start de timer en kom terug"),
        ("06-clear.png", "dark", "Lege lijst,<br>opgeruimd hoofd", "Niets blijft liggen rotten"),
    ],
    "pl": [
        ("01-main.png", "hero-bleed", "Wyrzuć to<br>z głowy", "Zapisz, gdy tylko przyjdzie do głowy"),
        ("02-typing.png", "left-text", "Kilka słów<br>i gotowe", "Bez list, folderów i terminów"),
        ("03-review.png", "text-bottom", "Wieczorem załatw<br>sprawy po kolei", "Zrób, wyznacz czas albo odpuść"),
        ("04-schedule.png", "flat-rotate", "Nie teraz?<br>Wyznacz czas", "Wróci dokładnie wtedy, kiedy chcesz"),
        ("05-donow.png", "left-text", "Dwie minuty?<br>Zrób od razu", "Włącz timer i wracaj"),
        ("06-clear.png", "dark", "Pusta lista,<br>czysta głowa", "Nic nie leży odłogiem"),
    ],
    "sv": [
        ("01-main.png", "hero-bleed", "Få det ur<br>huvudet", "Skriv ner det direkt när det dyker upp"),
        ("02-typing.png", "left-text", "Några ord,<br>sen är det klart", "Inga listor, inga mappar, inga deadlines"),
        ("03-review.png", "text-bottom", "Avgör allt<br>på kvällen", "Gör det, välj en tid eller släng"),
        ("04-schedule.png", "flat-rotate", "Inte nu?<br>Välj en tid", "Det kommer tillbaka när du sagt"),
        ("05-donow.png", "left-text", "Två minuter?<br>Gör det nu", "Starta timern och kom tillbaka"),
        ("06-clear.png", "dark", "Tom lista,<br>rensat huvud", "Inget blir liggande och mögla"),
    ],
    "tr": [
        ("01-main.png", "hero-bleed", "Aklındakini<br>dışarı çıkar", "Aklına geldiği anda not al"),
        ("02-typing.png", "left-text", "Birkaç kelime<br>yeter", "Liste yok, klasör yok, son tarih yok"),
        ("03-review.png", "text-bottom", "Akşam hepsini<br>sonuçlandır", "Yap, zamanla ya da vazgeç"),
        ("04-schedule.png", "flat-rotate", "Şimdi olmaz mı?<br>Saat seç", "Dediğin saatte geri gelir"),
        ("05-donow.png", "left-text", "İki dakika mı?<br>Hemen yap", "Zamanlayıcıyı başlat, dön"),
        ("06-clear.png", "dark", "Liste boş,<br>kafa rahat", "Hiçbir şey birikip çürümez"),
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
