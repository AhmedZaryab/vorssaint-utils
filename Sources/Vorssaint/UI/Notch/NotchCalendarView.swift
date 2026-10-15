// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import EventKit


struct NotchCalendarView: View {
    let size: CGSize
    @Environment(\.notchSettingsPreview) private var preview
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchCalendarCountdown) private var countdownForEvery = false
    /// The day the month grid or the week strip is built around.
    @State private var focus = Date()
    @State private var selectedDay: Date?
    /// The strip's month grid, in place of the strip and the cards.
    @State private var showingMonth = false
    private var text: NotchCalendarStrings { FeatureStrings.notchCalendar(l10n.language) }
    /// A month grid needs six rows beside an agenda; anything shorter shows
    /// the week as a strip above a vertical agenda.
    private var showsMonth: Bool { size.height >= 300 && size.width >= 420 }

    var body: some View {
        Group {
            if permissions.calendarAccess == .fullAccess {
                TimelineView(.everyMinute) { context in
                    Group {
                        if showsMonth {
                            HStack(alignment: .top, spacing: NotchDesign.Spacing.large) {
                                ScrollView { monthView(now: context.date) }
                                    .scrollIndicators(.automatic)
                                    .frame(width: 196)
                                Rectangle().fill(NotchDesign.Fill.control).frame(width: NotchDesign.Stroke.hairline)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: NotchDesign.Spacing.section) {
                                    agendaHeader
                                    agenda(now: context.date)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        } else if showingMonth {
                            monthGrid(now: context.date)
                        } else {
                            VStack(spacing: NotchLayout.rowSpacing) {
                                weekStrip(now: context.date)
                                agenda(now: context.date)
                            }
                        }
                    }
                    .onChange(of: Calendar.current.startOfDay(for: context.date)) { _, _ in
                        if selectedDay == nil { focus = context.date }
                    }
                }
            } else {
                permissionCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Day and month names follow the app's language; the order of the
        // date and the 12/24-hour clock follow the user's region.
        .environment(\.locale, l10n.language.formattingLocale())
        .onAppear { if ownsMonth { calendar.showMonth(focus) } }
        .onChange(of: focus) { previous, date in
            // A month read already covers every week of that month, so
            // moving the strip within it keeps the loaded events.
            if !Calendar.current.isDate(previous, equalTo: date, toGranularity: .month) { calendar.showMonth(date) }
        }
        // Escape returns from the month grid to the strip before the island closes.
        .onChange(of: showingMonth && !showsMonth) { _, showing in
            guard !preview else { return }
            NotchService.shared.setPageLayer(.calendar, close: showing ? { showingMonth = false } : nil)
        }
        .onDisappear {
            if ownsMonth { calendar.showMonth(nil) }
            if !preview { NotchService.shared.setPageLayer(.calendar, close: nil); calendar.revealing = nil }
        }
    }

    /// The month the service reads belongs to the island's own page; a preview
    /// in Settings borrows it only while the island shows another page.
    private var ownsMonth: Bool {
        !preview || !(NotchService.shared.expanded && NotchService.shared.selected == .calendar)
    }

    private func monthView(now: Date) -> some View {
        NotchCalendarMonthView(month: focus, selectedDay: selectedDay, now: now,
                               events: calendar.events, text: text, select: select, move: moveMonth) {
            today(now: now)
        } open: {
            openCalendar()
        }
    }

    private func weekStrip(now: Date) -> some View {
        NotchCalendarWeekStrip(width: size.width, focus: focus, selectedDay: selectedDay, now: now,
                               events: calendar.events, text: text, select: select) { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset * 7, to: focus) else { return }
            selectedDay = Calendar.current.startOfDay(for: date)
            focus = date
        } today: {
            today(now: now)
        } week: {
            selectedDay = nil
            focus = now
        } month: {
            showingMonth = true
        } open: {
            openCalendar()
        }
    }

    /// Picking a day, or Today, lands back on the strip with that day.
    private func monthGrid(now: Date) -> some View {
        NotchCalendarMonthGrid(month: focus, selectedDay: selectedDay, now: now, height: size.height,
                               events: calendar.events, text: text, select: { date in
            select(date)
            showingMonth = false
        }, move: moveMonth, today: {
            today(now: now)
            showingMonth = false
        }, open: { openCalendar() }, week: {
            showingMonth = false
        })
    }

    private func moveMonth(_ offset: Int) {
        guard let start = Calendar.current.dateInterval(of: .month, for: focus)?.start,
              let date = Calendar.current.date(byAdding: .month, value: offset, to: start) else { return }
        selectedDay = date
        focus = date
    }

    private func select(_ date: Date) {
        selectedDay = date
        focus = date
    }

    private func today(now: Date) {
        selectedDay = Calendar.current.startOfDay(for: now)
        focus = now
    }

    private var agendaHeader: some View {
        HStack(spacing: NotchDesign.Spacing.xSmall) {
            Group {
                if let selectedDay {
                    Text(selectedDay, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                } else {
                    Text(text.week)
                }
            }
            .font(NotchDesign.Typography.title.font)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            if selectedDay != nil {
                NotchIconButton(symbol: "calendar.badge.clock", title: text.week) {
                    selectedDay = nil
                    focus = Date()
                }
            }
        }
        .frame(minHeight: NotchDesign.Control.iconButton)
    }

    private struct DayGroup {
        let day: Date
        let events: [NotchCalendarEvent]
    }

    private func groups(now: Date) -> [DayGroup] {
        let days = selectedDay.map { [$0] } ?? (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now))
        }
        let events = selectedDay == nil ? NotchCalendarSupport.upcoming(calendar.events, now: now) : calendar.events
        return days.map { DayGroup(day: $0, events: NotchCalendarSupport.events(events, on: $0)) }
            .filter { !$0.events.isEmpty }
    }

    /// Scrolls once to the countdown's event opened from the closed island,
    /// after the reload that opening the page starts has finished.
    private func agenda(now: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView { appointmentList(now: now) }
                .scrollIndicators(.automatic)
                .id(selectedDay)
                .onChange(of: calendar.loading ? nil : calendar.revealing, initial: true) { _, target in
                    guard !preview, let target else { return }
                    DispatchQueue.main.async {
                        guard !calendar.loading, calendar.revealing == target else { return }
                        calendar.revealing = nil
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
        }
    }

    @ViewBuilder private func appointmentList(now: Date) -> some View {
        let groups = groups(now: now)
        let next = NotchCalendarSupport.next(calendar.events, now: now)
        if calendar.loading {
            ProgressView().controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 72)
        } else if groups.isEmpty {
            emptyAgenda.frame(maxWidth: .infinity, minHeight: 72)
        } else {
            LazyVStack(alignment: .leading, spacing: NotchDesign.Spacing.section) {
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: NotchDesign.Spacing.xSmall) {
                        if selectedDay == nil { dayLabel(group.day, now: now) }
                        ForEach(group.events) { event in
                            NotchCalendarEventRow(event: event, day: group.day, now: now,
                                                  isNext: event.id == next?.id, text: text,
                                                  countdown: countdownChoice(event, now: now),
                                                  choose: { calendar.setCountdown($0, for: event) }) {
                                openCalendar(showing: event)
                            }
                            .id(event.id)
                        }
                    }
                }
            }
            .padding(.bottom, NotchDesign.Spacing.line)
        }
    }

    /// Whether a timed event yet to start counts down on its own, or nil when
    /// its menu has nothing to offer: the countdown for every event covers it.
    private func countdownChoice(_ event: NotchCalendarEvent, now: Date) -> Bool? {
        guard !countdownForEvery, !event.allDay, event.start > now, !event.countdownKey.isEmpty else { return nil }
        return calendar.isChosen(event)
    }

    private func dayLabel(_ day: Date, now: Date) -> some View {
        NotchCalendarDayLabel(day: day, now: now, text: text)
    }

    private var emptyAgenda: some View {
        HStack(spacing: NotchDesign.Spacing.medium) {
            glyphPlate("calendar.badge.checkmark")
            Text(selectedDay == nil ? text.empty : text.emptyDay)
                .font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, NotchDesign.Spacing.medium)
    }

    /// An empty page's glyph in its plate.
    private func glyphPlate(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(NotchDesign.Icon.hero.font)
            .foregroundStyle(NotchDesign.Ink.secondary)
            .frame(width: NotchDesign.Control.heroGlyph, height: NotchDesign.Control.heroGlyph)
            .background(NotchDesign.Fill.card, in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
            .accessibilityHidden(true)
    }

    private var permissionCard: some View {
        let blocked = permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
        return VStack(spacing: NotchDesign.Spacing.medium) {
            glyphPlate("calendar.badge.clock")
            Text(blocked ? text.denied : text.permission)
                .font(NotchDesign.Typography.body.font).foregroundStyle(NotchDesign.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: NotchDesign.Spacing.small) {
                if blocked {
                    NotchCalendarPill(title: text.settings, prominent: true) { permissions.openCalendarSettings() }
                } else {
                    NotchCalendarPill(title: text.allow, prominent: true) {
                        NotchService.shared.open(.calendar)
                        permissions.requestCalendar()
                    }
                    .disabled(permissions.requestingCalendar)
                }
                if permissions.requestingCalendar { ProgressView().controlSize(.small) }
            }
            if permissions.calendarRequestFailed {
                Text(text.requestFailed).font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Palette.critical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, NotchDesign.Spacing.medium)
    }

    /// Calendar itself gets the link: another app claiming the `ical` scheme
    /// would not know EventKit's identifiers.
    private func openCalendar(showing event: NotchCalendarEvent? = nil) {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        if let url = event.flatMap({ NotchCalendarSupport.eventURL($0) }) {
            NSWorkspace.shared.open([url], withApplicationAt: application, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: application, configuration: configuration)
        }
    }
}

private struct NotchCalendarDayLabel: View {
    let day: Date
    let now: Date
    let text: NotchCalendarStrings

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.xxSmall) {
            if Calendar.current.isDate(day, inSameDayAs: now) {
                Text(text.today).foregroundStyle(NotchDesign.Ink.primary)
            } else {
                Text(day, format: .dateTime.weekday(.abbreviated))
            }
            Text(day, format: .dateTime.day().month(.abbreviated))
        }
        .font(NotchDesign.Typography.label.font)
        .foregroundStyle(NotchDesign.Ink.secondary)
        .lineLimit(1)
    }
}

/// One event, as Calendar lists it: the calendar's colour as a bar down the
/// leading edge, the clock in a monospaced column, then the title and where.
private struct NotchCalendarEventRow: View {
    let event: NotchCalendarEvent
    let day: Date
    let now: Date
    let isNext: Bool
    let text: NotchCalendarStrings
    /// Whether the event counts down on its own; nil when it cannot.
    let countdown: Bool?
    let choose: (Bool) -> Void
    let open: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private var ongoing: Bool { !event.allDay && event.start <= now && event.end > now }
    private var ended: Bool { event.end <= now }
    /// A timed event inside one day keeps its start and end in the clock column.
    private var sameDay: Bool {
        let calendar = Calendar.current
        return !event.allDay && calendar.isDate(event.start, inSameDayAs: day)
            && calendar.isDate(event.end.addingTimeInterval(-1), inSameDayAs: day)
    }

    var body: some View {
        Button(action: open) { card }
            .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.card), lifts: false))
            .help(text.openCalendar)
            .accessibilityHint(text.openCalendar)
            .modifier(NotchCountdownChoice(chosen: countdown, text: text, choose: choose))
    }

    private var card: some View {
        HStack(alignment: .top, spacing: NotchDesign.Spacing.small) {
            Capsule(style: .continuous).fill(event.color.color)
                .frame(width: 3)
                .accessibilityHidden(true)
            if sameDay || event.allDay { clockColumn }
            details
        }
        .opacity(ended ? NotchDesign.Opacity.secondary : 1)
        .padding(NotchDesign.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ongoing ? NotchDesign.Fill.control : NotchDesign.Fill.card,
                    in: RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous))
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: NotchDesign.Radius.card, style: .continuous)
                    .strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
            }
        }
    }

    private var clockColumn: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
            if event.allDay {
                Text(text.allDay)
                    .font(NotchDesign.Typography.label.font).foregroundStyle(NotchDesign.Ink.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(event.start, format: .dateTime.hour().minute())
                    .font(NotchDesign.Typography.label.font).foregroundStyle(NotchDesign.Ink.primary)
                Text(event.end, format: .dateTime.hour().minute())
                    .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .frame(width: 56, alignment: .leading)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
            if ongoing || isNext {
                Text(ongoing ? text.ongoing : text.next)
                    .font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(ongoing ? NotchDesign.Palette.accent : NotchDesign.Ink.secondary)
                    .lineLimit(1)
            }
            Text(event.title.isEmpty ? text.untitled : event.title)
                .font(NotchDesign.Typography.title.font).foregroundStyle(NotchDesign.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !event.allDay && !sameDay {
                (Text(event.start, format: .dateTime.day().month(.abbreviated).hour().minute())
                    + Text(" \u{2192} ") + Text(event.end, format: .dateTime.day().month(.abbreviated).hour().minute()))
                    .font(NotchDesign.Typography.callout.font).monospacedDigit()
                    .foregroundStyle(NotchDesign.Ink.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: NotchDesign.Spacing.xxSmall) {
                Text(event.calendar).lineLimit(1)
                // The mark of an event chosen to count down on its own.
                if countdown == true {
                    Image(systemName: "timer")
                        .accessibilityLabel(text.countdown)
                }
            }
            .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary)
            if !event.location.isEmpty {
                Label(event.location, systemImage: "mappin")
                    .font(NotchDesign.Typography.caption.font).foregroundStyle(NotchDesign.Ink.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A timed event yet to start offers its own countdown from its menu, and
/// to VoiceOver as an action, while the countdown for every event is off.
private struct NotchCountdownChoice: ViewModifier {
    let chosen: Bool?
    let text: NotchCalendarStrings
    let choose: (Bool) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if let chosen {
            let title = chosen ? text.removeCountdown : text.addCountdown
            content
                .contextMenu { Button(title) { choose(!chosen) } }
                .accessibilityAction(named: Text(title)) { choose(!chosen) }
        } else {
            content
        }
    }
}

extension NotchCalendarColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}
