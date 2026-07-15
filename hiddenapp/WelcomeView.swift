//
//  WelcomeView.swift
//  hiddenapp
//
//  First-run onboarding popover shown once, anchored to the toggle chevron.
//  Explains the one non-obvious setup step (⌘-drag icons past the separator)
//  in three short steps.
//

import SwiftUI

struct WelcomeView: View {
    /// Called when the user clicks "Got It" to dismiss the popover.
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Welcome to HiddenApp")
                    .font(.headline)
            }

            Divider()

            step(
                symbol: "command",
                text: "Hold ⌘ and drag menu bar icons to the LEFT of the | separator."
            )
            step(
                symbol: "chevron.right",
                text: "Click the chevron to hide them. Click again to bring them back."
            )
            step(
                symbol: "gearshape",
                text: "Right-click the chevron for Preferences or to Quit."
            )

            Divider()

            Button {
                onDismiss()
            } label: {
                Text("Got It")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .frame(width: 300)
    }

    private func step(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(onDismiss: {})
}
