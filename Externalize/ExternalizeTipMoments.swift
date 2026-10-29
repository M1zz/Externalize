//
//  ExternalizeTipMoments.swift
//  Externalize
//
//  팁을 부탁해도 되는 고마운 순간 — 이 앱 덕에 머리에서 내려놓은 것(끝냈거나 버린 것)의 누적 수.
//  카드는 저녁 정리를 다 마친 화면(ReviewView)에만 선다. 얼마나 드물게 물을지는 LeeoKit 이 정한다.
//

import Foundation
import LeeoKit

enum ExternalizeTipMoments {
    /// 내려놓은 수의 문턱. 큰 것부터.
    static let settled = [300, 100, 30]

    /// 넘어선 순간, 인상적인 것부터.
    static func reached(settledTotal total: Int) -> [LeeoTipMoment] {
        settled.filter { total >= $0 }.map { threshold in
            LeeoTipMoment(id: "settled.\(threshold)",
                          message: String(localized: "You've cleared \(total) things off your mind so far",
                                          comment: "Tip ask card: how many thoughts the person has settled (done or dropped) in total"))
        }
    }

    static var reachedNow: [LeeoTipMoment] { reached(settledTotal: ResolvedCounter.total) }
}
