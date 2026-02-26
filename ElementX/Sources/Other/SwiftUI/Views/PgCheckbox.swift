//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct PgCheckbox<Label: View>: View {
    @Binding var isChecked: Bool
    var label: () -> Label

    var body: some View {
        Button(action: { isChecked.toggle() }, label: {
            HStack(spacing: 8) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.compound.bgAccentRest)
                    .font(.compound.headingLG)

                label()
            }
        })
    }
}
