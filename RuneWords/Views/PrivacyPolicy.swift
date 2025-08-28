//
//  PrivacyPolicy.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation

//
//  PrivacyPolicyView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("privacy_policy", comment: "Privacy Policy"))
                    .font(.title.bold())
                    .padding(.bottom, 4)

                Text("""
We respect your privacy. RuneWords collects aggregated, anonymized analytics data through Firebase to improve gameplay and diagnose crashes. No personally identifiable information is sold or shared with third parties for marketing purposes.

**What we collect**

• Gameplay events (levels played, words found, time‑on‑level)  
• Crash reports & performance metrics  
• Anonymous purchase identifiers (for validating in‑app purchases)  
• Advertising identifiers *only* if you play the ad‑supported version

All data stays within Google‑hosted services (Firebase & Google AdMob). You can reset your advertising identifier at any time in iOS Settings › Privacy › Advertising.

**Your choices**

• Opt‑out of analytics in Settings › Privacy on your device.  
• Disable personalized ads via iOS Settings › Privacy › Apple Advertising.  
• Contact support@runewords.app to request data deletion (include your Game Center ID).

By continuing to use RuneWords you agree to this policy. This document may evolve; material changes will appear in‑app on first launch after an update.
""")
                .font(.body)
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("privacy_policy", comment: "Privacy Policy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PrivacyPolicyView()
}
