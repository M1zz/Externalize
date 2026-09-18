# Externalize (뇌모리)

> Don't spend your brain on things you don't need to remember.

한국어 이름은 **뇌모리** — 뇌 + 외부 메모리. 한국어 기기에서는 홈 화면·앱 제목·위젯·Siri 문구가 모두 "뇌모리"로 표시되고, 영어 기기에서는 Externalize.

주차 위치, 사물함 비번, 호텔 방 번호 같은 **단기 휘발성 정보 전용** 앱. 저장한 건 기본 24시간 후 스스로 삭제되고, 잠금화면 위젯에 늘 떠 있음.

## 요구사항
- Xcode 16 이상 (프로젝트는 폴더 동기화 그룹, objectVersion 77 사용)
- iOS 17.0+

## 처음 열었을 때 할 일 (3분)
1. `Externalize.xcodeproj` 열기
2. **두 타깃 모두** (Externalize, ExternalizeWidgetExtension) → Signing & Capabilities → Team 선택
3. 번들 ID `com.devkoan.externalize`를 본인 것으로 바꿀 경우:
   - 앱 / 위젯(`.widget` 접미사) 번들 ID
   - App Group `group.com.devkoan.externalize` → `Config/*.entitlements` 두 파일 + `Shared/MemoRepository.swift`의 `AppGroup.identifier` 세 곳을 같이 수정
   - IAP 상품 ID → `PurchaseManager.lifetimeProductID` + `Config/Products.storekit`
4. Run. 스킴에 `Products.storekit`이 연결돼 있어 시뮬레이터에서 바로 $2.99 구매 테스트 가능
   (연결이 풀려 있으면 Edit Scheme → Run → Options → StoreKit Configuration에서 선택)

## 구조
```
Externalize/          앱 타깃 (SwiftUI, @Observable)
  ExternalizeApp.swift
  ContentView.swift     목록 · 탭하면 복사 · 스와이프 삭제/+24h
  AddMemoView.swift     종류 칩 + 값 + 만료시간(1h/8h/24h)
  PaywallView.swift     $2.99 lifetime
  PurchaseManager.swift StoreKit 2, 비소모성 1개
  RememberIntent.swift  App Intent + Siri/액션버튼 단축어
  OnboardingView.swift  첫 실행 온보딩 5페이지 (툴바 ? 버튼으로 다시 보기)
  AppShortcuts.xcstrings  Siri 단축어 문구 (한국어: "뇌모리에 기억해")
ExternalizeWidget/    위젯 익스텐션 (잠금화면 rectangular/circular/inline + 홈 small)
Shared/               두 타깃 공유 — 모델, App Group 저장소, 무료 한도
  Localizable.xcstrings 앱·위젯 공용 문자열 카탈로그 (en 원문 + ko)
  InfoPlist.xcstrings   앱 표시 이름 (ko: 뇌모리)
Config/               entitlements, StoreKit 설정
```

## 핵심 설계
- **자동 만료**: 읽을 때마다 만료분 필터, 앱 활성화/30초마다 디스크에서 물리 삭제. 위젯 타임라인은 각 만료 시각마다 엔트리를 만들어 잠금화면에서도 제시간에 사라짐.
- **저장소**: App Group UserDefaults에 JSON. 수십 개 수준이라 SwiftData는 과함. 쓸 때마다 `WidgetCenter.reloadAllTimelines()`.
- **수익화**: 무료 = 동시 2개, Lifetime = 무제한. 한도는 `ProAccess.freeSlotLimit` 하나로 조정. 구매 상태는 App Group에 캐시해서 App Intent도 한도를 지킴.
- **입력 최소화**: 단축어 "Remember in Externalize" → 액션 버튼에 걸면 앱 안 열고 저장.
- **지역화**: 영어 원문 + 한국어. 문자열 카탈로그는 `Shared/`에 하나만 둬서 앱·위젯이 같이 씀 (각 타깃에 따로 두면 `Localizable.strings` 출력이 겹침). `String`을 반환하는 곳은 `String(localized:)`로 감쌈.
- **Privacy manifest** 포함 (UserDefaults: CA92.1, 1C8F.1). 수집 데이터 없음.

## 출시 전 체크
- App Store Connect에 비소모성 IAP `com.devkoan.externalize.lifetime` ($2.99) 생성
- "Externalize" / "뇌모리" 이름 선점 여부 확인 (App Store Connect 한국어 현지화에 앱 이름 뇌모리 입력)
- 앱 아이콘은 임시(PIL로 생성). 교체 필요
