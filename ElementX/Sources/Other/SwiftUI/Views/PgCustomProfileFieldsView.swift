//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct PgCustomProfileFieldsView: View {
    let email: String?
    let function: String?
    let department: String?
    
    var body: some View {
        let hasProfileFields = email != nil || function != nil || department != nil
        
        if hasProfileFields {
            VStack(alignment: .leading, spacing: 8) {
                if let department {
                    Label(department, icon: \.company)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyLG)
                }
                if let function {
                    Label(function, icon: \.user)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyLG)
                }
                if let email {
                    Label(email, icon: \.email)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyLG)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
