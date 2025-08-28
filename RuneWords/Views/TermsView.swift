//
//  TermsView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import Foundation

//
//  TermsView.swift
//  RuneWords
//
//  Created by Anthony Yarand on 7/29/25.
//

import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("terms_of_service", comment: "Terms of Service"))
                    .font(.title.bold())
                    .padding(.bottom, 4)

                Text("""
Welcome to RuneWords! By downloading or using this app you agree to the following terms:

**1. License**  
RuneWords grants you a non‑exclusive, non‑transferable license to use the app for personal entertainment. All intellectual property rights remain with the developer.

**2. In‑App Purchases**  
Digital items (hints, revelations, ad removal, coin packs) are final and non‑refundable except where required by local law.

**3. User Data**  
Gameplay analytics and crash logs are collected to improve the experience, as detailed in our Privacy Policy. You may request deletion at any time by emailing support@runewords.app with your Game Center ID.

**4. Ads**  
The ad‑supported version displays third‑party ads via Google AdMob. Ad frequency may change based on Remote Config experiments.

**5. Limitation of Liability**  
RuneWords is provided “as is” without warranties of any kind. The developer is not liable for any indirect damages arising from app usage.

**6. Updates**  
Features may change or be removed without notice. Continued use after an update signifies acceptance of any modified terms.

**7. Governing Law**  
These terms are governed by the laws of the developer’s jurisdiction, without regard to conflict of law provisions.

If you do not agree with these terms, please uninstall the app. For questions, contact support@runewords.app.
""")
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("terms_of_service", comment: "Terms of Service"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TermsView()
}
