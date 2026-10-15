// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A scrolling page fades where more of it lies beyond an edge, so a card is
/// never sliced by a hard line. The soft edge follows the scroll as Apple's
/// scroll edge effect does: it grows with how far content has passed under
/// the edge, so at rest at the start there is nothing to fade, and the last
/// row at the end stays clear. Earlier systems keep the hard edge.
struct NotchScrollEdgeFade: ViewModifier {
    var axis: Axis = .vertical
    var length: CGFloat = NotchDesign.Spacing.large
    /// 0 to 1 in sixteenths: how far content has passed each edge, as a share of the fade.
    @State private var startAmount = 0.0
    @State private var endAmount = 0.0

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .onScrollGeometryChange(for: Edges.self) { geometry in
                    let offset = axis == .vertical ? geometry.contentOffset.y : geometry.contentOffset.x
                    let visible = axis == .vertical ? geometry.containerSize.height : geometry.containerSize.width
                    let total = axis == .vertical ? geometry.contentSize.height : geometry.contentSize.width
                    func amount(_ distance: CGFloat) -> Double {
                        let share = Double(min(1, max(0, distance / max(1, length))))
                        return (share * 16).rounded() / 16
                    }
                    return Edges(start: amount(offset), end: amount(total - visible - offset))
                } action: { _, edges in
                    startAmount = edges.start
                    endAmount = edges.end
                }
                .mask { fadeMask }
        } else {
            content
        }
    }

    private struct Edges: Equatable { var start: Double; var end: Double }

    private var fadeMask: some View {
        let vertical = axis == .vertical
        return Rectangle().fill(.black)
            .overlay(alignment: vertical ? .top : .leading) {
                fade(toStart: true).opacity(startAmount)
            }
            .overlay(alignment: vertical ? .bottom : .trailing) {
                fade(toStart: false).opacity(endAmount)
            }
            .compositingGroup()
    }

    /// Erases the mask toward the edge it sits on.
    private func fade(toStart: Bool) -> some View {
        let vertical = axis == .vertical
        let from: UnitPoint = vertical ? (toStart ? .top : .bottom) : (toStart ? .leading : .trailing)
        let to: UnitPoint = vertical ? (toStart ? .bottom : .top) : (toStart ? .trailing : .leading)
        return LinearGradient(colors: [.black, .clear], startPoint: from, endPoint: to)
            .frame(width: vertical ? nil : length, height: vertical ? length : nil)
            .blendMode(.destinationOut)
    }
}

extension View {
    func notchScrollEdgeFade(_ axis: Axis = .vertical, length: CGFloat = NotchDesign.Spacing.large) -> some View {
        modifier(NotchScrollEdgeFade(axis: axis, length: length))
    }
}
