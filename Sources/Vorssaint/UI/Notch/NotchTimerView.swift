// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchTimerView: View {
    private typealias Design = NotchDesign
    let size: CGSize
    @ObservedObject private var service = NotchTimerService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchTimerMode) private var mode: NotchTimerMode = .timer
    @AppStorage(DefaultsKey.notchPomodoroFocusMinutes) private var focusMinutes = 25
    @AppStorage(DefaultsKey.notchPomodoroShortBreakMinutes) private var shortBreakMinutes = 5
    @AppStorage(DefaultsKey.notchPomodoroLongBreakMinutes) private var longBreakMinutes = 15
    @AppStorage(DefaultsKey.notchPomodoroLongBreakInterval) private var longBreakInterval = 4
    @AppStorage(DefaultsKey.notchPomodoroTotalSessions) private var totalSessions = 4
    @AppStorage(DefaultsKey.notchTimerMinutes) private var savedMinutes = 15
    @Namespace private var modeSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    private var text: NotchActivityStrings { FeatureStrings.notchActivities(l10n.language) }

    private var wide: Bool { size.width >= NotchLayout.timerWideWidth }

    var body: some View {
        Group {
            if service.session.hasSession { activeTimer }
            else { setup }
        }
        // Readout page: centred in the canvas (NOTCH-DESIGN 2.3) so slack splits evenly.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .tint(Design.Palette.accent)
    }

    /// The mode row over the ruler's row, whatever the mode: the
    /// timer and the Pomodoro's focus set on the ruler, the stopwatch's
    /// clock alone in that row. The Pomodoro adds one quiet line of
    /// readouts; a narrow island gives Start the last row and seats the
    /// readouts beside it.
    private var setup: some View {
        let rulerHeight = NotchLayout.timerRulerHeight(mode: mode, width: size.width, height: size.height)
        let locale = Locale(identifier: l10n.language.rawValue)
        return VStack(spacing: NotchLayout.timerRowSpacing) {
            HStack(spacing: Design.Spacing.medium) {
                modePicker
                Spacer(minLength: 0)
                if wide { startButton }
            }
            .frame(height: NotchLayout.timerTopRowHeight)
            HStack(spacing: Design.Spacing.medium) {
                switch mode {
                case .timer:
                    NotchTimerRuler(minutes: timerMinutes, label: text.timer, locale: locale)
                        .frame(height: rulerHeight)
                case .pomodoro:
                    NotchTimerRuler(minutes: binding(.focus), label: text.focus, locale: locale)
                        .frame(height: rulerHeight)
                case .stopwatch:
                    Spacer(minLength: 0)
                }
                if wide || mode == .stopwatch { clock(setupClock) }
            }
            .frame(height: rulerHeight)
            if mode == .pomodoro {
                HStack(spacing: Design.Spacing.medium) {
                    if !wide { clock(setupClock) }
                    pomodoroSettings
                    if !wide { startButton }
                }
                .frame(height: wide ? NotchLayout.timerSettingsRowHeight : NotchLayout.timerStartHeight)
            } else if !wide {
                HStack(spacing: Design.Spacing.medium) {
                    if mode == .timer { clock(setupClock) }
                    Spacer(minLength: 0)
                    startButton
                }
                .frame(height: NotchLayout.timerStartHeight)
            }
        }
    }

    /// Start is the commit class: it fires on press down, the glyph kicks up and a few
    /// particles leave the rim. Round, as in Apple's Timer and Stopwatch.
    private var startButton: some View {
        NotchCommitButton(text.start, symbol: "play.fill", kick: .up,
                          hint: mode == .pomodoro ? text.pomodoroHint : nil,
                          size: NotchLayout.timerStartHeight, filled: true, tint: Design.Palette.accent) {
            service.start(mode: mode, minutes: timerMinutes.wrappedValue)
        }
    }

    private var setupClock: String {
        switch mode {
        case .timer: return NotchTimerSupport.clockText(Double(timerMinutes.wrappedValue) * 60)
        case .pomodoro: return NotchTimerSupport.clockText(Double(binding(.focus).wrappedValue) * 60)
        case .stopwatch: return NotchTimerSupport.stopwatchText(0)
        }
    }

    /// A segmented control on the tokens: a track, one chosen plate that slides between
    /// the words. Each segment is as wide as its word, so the longest translation never
    /// pushes the three past a narrow island.
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(NotchTimerMode.allCases, id: \.self) { candidate in
                let selected = mode == candidate
                Button { NotchService.shared.selectTimerMode(candidate) } label: {
                    Text(title(for: candidate))
                        .font(Design.Typography.label.font)
                        .lineLimit(1)
                        .foregroundStyle(selected ? Design.Ink.primary : Design.Ink.secondary)
                        .padding(.horizontal, Design.Spacing.medium)
                        .frame(height: Design.Control.rowHeight)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous)
                                    .fill(Design.Fill.selected)
                                    .matchedGeometryEffect(id: "selection", in: modeSelection)
                            }
                        }
                }
                .buttonStyle(NotchPressStyle(shape: .rounded(Design.Radius.control), lifts: false))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .background(Design.Fill.control, in: RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous)
                    .strokeBorder(Design.Stroke.increasedContrast, lineWidth: Design.Stroke.increasedContrastWidth)
            }
        }
        .animation(Design.Motion.animation(Design.Motion.snappy, reduceMotion: reduceMotion), value: mode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text.timer)
    }

    private func title(for mode: NotchTimerMode) -> String {
        switch mode {
        case .timer: return text.timer
        case .pomodoro: return text.pomodoro
        case .stopwatch: return text.stopwatch
        }
    }

    private var activeTimer: some View {
        VStack(spacing: Design.Spacing.xxSmall) {
            activeControls
            if service.session.mode == .pomodoro {
                Text(String(format: text.sessionProgress, service.session.sessionNumber, service.session.configuration.totalSessions))
                    .font(Design.Typography.label.font).monospacedDigit()
                    .foregroundStyle(Design.Ink.secondary)
            }
        }
    }

    /// Cancel on the left, the primary action beside it, the reading on the right.
    /// Pause and resume is one commit on the accent plate whose glyph morphs.
    private var activeControls: some View {
        let session = service.session
        return HStack(spacing: Design.Spacing.large) {
            HStack(spacing: Design.Spacing.medium) {
                if !session.completed {
                    cancelButton
                    // Pause and resume is one action that changes its name and glyph: a commit
                    // that morphs, so VoiceOver reads the action ("Pause"), never a switch state.
                    let title = session.isPaused ? text.resume : l10n.s.actionPause
                    NotchCommitButton(title, symbol: session.isPaused ? "play.fill" : "pause.fill", kick: .morph,
                                      size: roundSide, symbolSize: 20, action: service.pauseOrResume)
                        .background(Design.Palette.accent, in: Circle())
                } else {
                    doneButton
                    if session.canStartNext {
                        NotchCommitButton(text.start + " " + text.phase(session.nextPhase), symbol: "play.fill",
                                          kick: .up, size: roundSide, symbolSize: 20, filled: true,
                                          tint: Design.Palette.accent) { service.startNext() }
                    }
                }
            }
            Spacer(minLength: 0)
            if session.isRunning {
                TimelineView(.periodic(from: Date(timeIntervalSinceNow: NotchTimerSupport.tickScheduleOffset(
                    for: session, at: service.now)), by: 1)) { _ in reading }
            } else {
                reading
            }
        }
        .frame(height: 96)
    }

    private var roundSide: CGFloat { Design.Control.transport }

    /// A destructive cancel: the fuse burns for its 2.5 s and Escape or a click undoes it.
    private var cancelButton: some View {
        // Same plate and size as Pause beside it, so the pair reads as two round buttons
        // and only style tells the primary one apart.
        NotchFuseButton(l10n.s.mediaCancel, symbol: "xmark", shape: .capsule, onCommit: service.cancel)
            .frame(width: roundSide, height: roundSide)
            .background(Design.Fill.control, in: Circle())
    }

    private var doneButton: some View {
        Button(action: service.cancel) {
            Image(systemName: "checkmark")
                .font(Design.Icon.transport.font)
                .foregroundStyle(Design.Ink.primary)
                .frame(width: roundSide, height: roundSide)
                .background(Design.Fill.control, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
        .accessibilityLabel(l10n.s.supportIntroDoneButton)
        .help(l10n.s.supportIntroDoneButton)
    }

    private var reading: some View {
        let value = NotchTimerSupport.clockText(for: service.session, at: service.now)
        let title = service.session.cycleFinished ? text.pomodoroFinished
            : service.session.completed ? text.finished : text.phase(service.session.phase)
        let countsDown = !service.session.countsUp
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.small) {
                Text(title).font(Design.Typography.title.font).foregroundStyle(Design.Ink.secondary)
                clock(value).modifier(NotchRollingDigits(value: value, countsDown: countsDown))
            }.fixedSize()
            VStack(alignment: .trailing, spacing: Design.Spacing.line) {
                Text(title).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(NotchDesign.SpecTime.scale(Design.Typography.label, preferred: 0.7))
                clock(value).modifier(NotchRollingDigits(value: value, countsDown: countsDown))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    /// The breaks and the sessions as readouts in the ruler's own language:
    /// the name small and dim, the value in white, the usual values behind
    /// a native menu. They spread across a wide island and run sideways past
    /// a narrow one.
    private var pomodoroSettings: some View {
        let readouts = NotchPomodoroOption.allCases.filter { $0 != .focus }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(readouts) { readout($0).frame(maxWidth: .infinity, alignment: .leading) }
            }
            ScrollView(.horizontal) {
                HStack(spacing: Design.Spacing.large) {
                    ForEach(readouts) { readout($0) }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func readout(_ option: NotchPomodoroOption) -> some View {
        let value = binding(option)
        let title = title(option)
        let current = value.wrappedValue
        return NotchMenuButton(title: title, items: option.range.map { choice in
            NotchMenuItem(title: display(option, choice), checked: choice == current) { value.wrappedValue = choice }
        }, cornerRadius: Design.Radius.control) {
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                Text(title)
                    .font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary)
                    .lineLimit(1).truncationMode(.tail)
                HStack(spacing: Design.Spacing.xxSmall) {
                    Text(display(option, current))
                        .font(Design.Typography.readout.font).monospacedDigit().foregroundStyle(Design.Ink.primary)
                    Image(systemName: "chevron.down").font(Design.Icon.strip.font)
                        .foregroundStyle(Design.Ink.secondary)
                }
            }
            .padding(.horizontal, Design.Spacing.xxSmall)
            .frame(height: NotchLayout.timerSettingsRowHeight)
            .contentShape(RoundedRectangle(cornerRadius: Design.Radius.control, style: .continuous))
        }
        .help(title)
        .accessibilityValue(display(option, current))
    }

    private var timerMinutes: Binding<Int> {
        Binding(get: { NotchTimerSupport.timerMinutes(savedMinutes) },
                set: { savedMinutes = NotchTimerSupport.timerMinutes($0) })
    }

    private func binding(_ option: NotchPomodoroOption) -> Binding<Int> {
        let stored: Binding<Int>
        switch option {
        case .focus: stored = $focusMinutes
        case .shortBreak: stored = $shortBreakMinutes
        case .longBreak: stored = $longBreakMinutes
        case .longBreakInterval: stored = $longBreakInterval
        case .totalSessions: stored = $totalSessions
        }
        let range = option.range
        return Binding(get: { min(range.upperBound, max(range.lowerBound, stored.wrappedValue)) },
                       set: { stored.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) })
    }

    private func title(_ option: NotchPomodoroOption) -> String {
        switch option {
        case .focus: return text.focus
        case .shortBreak: return text.shortBreak
        case .longBreak: return text.longBreak
        case .longBreakInterval: return text.longBreakInterval
        case .totalSessions: return text.totalSessions
        }
    }

    private func display(_ option: NotchPomodoroOption, _ value: Int) -> String {
        option.isDuration
            ? NotchTimerSupport.compactText(Double(value) * 60, locale: Locale(identifier: l10n.language.rawValue))
            : String(value)
    }

    /// A reading: the display style, monospaced so it never jitters as the seconds change.
    private func clock(_ value: String) -> some View {
        Text(value)
            .font(Design.Typography.display.font).monospacedDigit()
            .foregroundStyle(Design.Ink.primary)
            .lineLimit(1).minimumScaleFactor(0.5)
    }
}
