// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Parked with mediaTools (see ../RESTORE.md): the media half of
// NotchFileToolsSupport. Restore by pasting the members back into
// `enum NotchFileToolsSupport` (they were an extension here only so the file
// reads on its own).

import Foundation
import UniformTypeIdentifiers

extension NotchFileToolsSupport {
    static let dropSpacing: CGFloat = 12

    static func mediaDropArea(in geometry: NotchGeometry, size: CGSize) -> CGRect {
        let content = geometry.contentSize(for: size)
        return CGRect(x: size.width / 2 + dropSpacing / 2,
                      y: geometry.headerTopInset + geometry.headerRowHeight + NotchLayout.spacing,
                      width: max(0, (content.width - dropSpacing) / 2), height: content.height)
    }

    static func optimizationTool(for urls: [URL]) -> MediaTool? {
        if accepts(urls, for: .imageCompressor) { return .imageCompressor }
        if accepts(urls, for: .videoCompressor) { return .videoCompressor }
        return nil
    }

    static func accepts(_ urls: [URL], for tool: MediaTool) -> Bool {
        guard !urls.isEmpty, urls.allSatisfy(\.isFileURL),
              tool == .imageCompressor || urls.count == 1 else { return false }
        let types: [UTType] = tool == .videoCompressor || tool == .gifMaker
            ? [.movie, .video] : [.image]
        return urls.allSatisfy { url in
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            return MediaSupport.inputMatchesTool(contentType: type, inputTypes: types)
        }
    }
}
