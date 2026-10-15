// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchCameraView: View {
    let size: CGSize
    @ObservedObject private var service = CameraPreviewService.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchActivityStrings { FeatureStrings.notchActivities(l10n.language) }

    var body: some View {
        Group {
            if service.isEmbeddedPresented {
                // The preview takes the whole page, with its stop button over the image.
                CameraPreviewView(size: NotchLayout.cameraPreviewSize(in: size), showsCameraMenu: true,
                                  onStop: service.hideEmbedded)
            } else {
                // Off after Stop, or before the first frame: the empty-state shape, one next step.
                NotchEmptyView(symbol: "web.camera", message: text.cameraHint) {
                    Button(action: service.showEmbedded) {
                        Text(text.startCamera).font(NotchDesign.Typography.label.font)
                            .foregroundStyle(NotchDesign.Ink.primary)
                            .padding(.horizontal, NotchDesign.Spacing.large)
                            .frame(height: NotchDesign.Control.rowHeight)
                            .background(NotchDesign.Palette.accent, in: Capsule())
                    }
                    .buttonStyle(NotchPressStyle(shape: .capsule, washes: false))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fork change: opening the camera page starts the mirror at once, so
        // there is no second "Open camera" click. The page's Open camera
        // button stays as the way back in after Stop. macOS still shows its
        // own one-time permission prompt through beginCapture().
        .onAppear { service.showEmbedded() }
        .onDisappear { service.hideEmbedded() }
    }
}
