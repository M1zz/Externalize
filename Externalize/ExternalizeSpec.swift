//
//  ExternalizeSpec.swift
//  Externalize
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백·리뷰·진단 구현은 전부 LeeoKit 에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 — 변경 금지.
//

import Foundation
import LeeoKit

enum ExternalizeSpec: LeeoAppSpec {
    static let appName = "뇌모리"
    static let developerEmail = "leeo@kakao.com"

    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier(번들 ID)로 앱을 구분한다.
    /// ⚠️ 아직 이 앱의 entitlements 에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 **없다.**
    ///    그래서 부트스트랩에서 크래시 진단(CloudKit 전송)을 꺼 두었다 (→ ExternalizeApp).
    ///    피드백 화면·진단을 켜기 전에 iCloud(CloudKit) 기능과 이 컨테이너부터 넣을 것.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.devkoan.externalize"
    )

    /// 개인정보·지원 페이지 (LeeoKit 3.x 부터 필수). APPSTORE.md (한국어 절) 에 적힌 주소를 그대로 쓴다.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/Externalize/privacy.html?lang=ko")!,
        supportURL: URL(string: "https://m1zz.github.io/Externalize/support.html?lang=ko")!,
        marketingURL: URL(string: "https://m1zz.github.io/Externalize/?lang=ko")!
    )

    /// 수익모델 (LeeoKit 3.x 부터 필수) — 인앱 결제가 없는 무료 앱.
    static let monetization = LeeoMonetization.free
}
