// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI


/// The numeral of a day cell in the three grids. Today is a white disc with a
/// black numeral (Fill.inverse, Ink.onInverse), the chosen day a Fill.selected
/// disc, and a chosen today keeps its disc and gains a ring. Moving the choice
/// settles on Motion.snappy; Reduce Motion cross-fades.
private struct NotchCalendarDayMark: ViewModifier {
    let isToday: Bool
    let selected: Bool
    let inMonth: Bool
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var ink: Color {
        isToday ? NotchDesign.Ink.onInverse : inMonth || selected ? NotchDesign.Ink.primary : NotchDesign.Ink.tertiary
    }

    func body(content: Content) -> some View {
        content
            .font(NotchDesign.Typography.label.font.weight(isToday || selected ? .semibold : .medium).monospacedDigit())
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background {
                Circle().fill(isToday ? NotchDesign.Fill.inverse : selected ? NotchDesign.Fill.selected : .clear)
            }
            .overlay {
                Circle()
                    .strokeBorder(selected ? (isToday ? NotchDesign.Ink.secondary
                                              : contrast == .increased ? NotchDesign.Stroke.increasedContrast : .clear) : .clear,
                                  lineWidth: isToday ? 1.5 : NotchDesign.Stroke.increasedContrastWidth)
                    .padding(isToday ? -3 : 0)
            }
            .animation(reduceMotion ? NotchDesign.Motion.fade : NotchDesign.Motion.snappy.animation, value: selected)
    }
}

/// Up to three event colours under a day, content colour as small dots.
private struct NotchCalendarDots: View {
    let events: [NotchCalendarEvent]
    static let side: CGFloat = 4

    var body: some View {
        let colors = events.reduce(into: [NotchCalendarColor]()) { result, event in
            if result.count < 3 && !result.contains(event.color) { result.append(event.color) }
        }
        HStack(spacing: NotchDesign.Spacing.line) {
            ForEach(colors, id: \.key) { color in
                Circle().fill(color.color).frame(width: Self.side, height: Self.side)
            }
        }
        .frame(height: Self.side)
        .accessibilityHidden(true)
    }
}

extension NotchDesign {
    /// The calendar, timer and watch pages: one value no token carries.
    enum SpecTime {
        /// A `minimumScaleFactor` that never lets a style shrink under the 10 pt floor.
        static func scale(_ style: TypeStyle, preferred: CGFloat) -> CGFloat {
            max(preferred, 10 / style.nsFont.pointSize)
        }
    }
}

extension NotchCalendarColor {
    /// A stable identity for the deduplicated dots; the colour itself is the key.
    var key: String { "\(red)-\(green)-\(blue)" }
}

/// Week and Month as one segmented control, the same two segments in the same
/// place on both views: the chosen segment wears the selected fill.
struct NotchCalendarViewSwitch: View {
    let monthSelected: Bool
    let text: NotchCalendarStrings
    let week: () -> Void
    let month: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 0) {
            segment("calendar.badge.clock", text.week, selected: !monthSelected, action: week)
            segment("calendar", text.month, selected: monthSelected, action: month)
        }
        .background(NotchDesign.Fill.control, in: RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous)
                    .strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ symbol: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(NotchDesign.Icon.button.font)
                .foregroundStyle(selected ? NotchDesign.Ink.primary : NotchDesign.Ink.secondary)
                .frame(width: NotchDesign.Control.iconButton, height: NotchDesign.Control.iconButton)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous)
                            .fill(NotchDesign.Fill.selected)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: NotchDesign.Radius.control, style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A word on a capsule: the page's step. Prominent is the one accent action.
struct NotchCalendarPill: View {
    let title: String
    var prominent = false
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NotchDesign.Typography.label.font)
                .foregroundStyle(NotchDesign.Ink.primary)
                .lineLimit(1)
                .padding(.horizontal, NotchDesign.Spacing.medium)
                .frame(height: NotchDesign.Control.rowHeight)
                .background(prominent ? NotchDesign.Palette.accent : NotchDesign.Fill.control, in: Capsule(style: .continuous))
                .overlay {
                    if contrast == .increased {
                        Capsule(style: .continuous)
                            .strokeBorder(NotchDesign.Stroke.increasedContrast, lineWidth: NotchDesign.Stroke.increasedContrastWidth)
                    }
                }
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
    }
}

struct NotchCalendarMonthView: View {
    let month: Date
    let selectedDay: Date?
    let now: Date
    let events: [NotchCalendarEvent]
    let text: NotchCalendarStrings
    let select: (Date) -> Void
    let move: (Int) -> Void
    let today: () -> Void
    let open: () -> Void
    @Environment(\.locale) private var locale
    @AppStorage(DefaultsKey.notchCalendarWeekNumbers) private var weekNumbers = false
    private var columns: [GridItem] { NotchCalendarWeekNumber.columns(numbered: weekNumbers) }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchDesign.Spacing.section) {
            HStack(spacing: NotchDesign.Spacing.line) {
                VStack(alignment: .leading, spacing: NotchDesign.Spacing.line) {
                    Text(month, format: .dateTime.month(.wide))
                        .font(NotchDesign.Typography.pageTitle.font).lineLimit(1)
                        .minimumScaleFactor(max(0.8, NotchDesign.Typography.pageTitle.minimumScale))
                    Text(month, format: .dateTime.year())
                        .font(NotchDesign.Typography.label.font).foregroundStyle(NotchDesign.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NotchIconButton(symbol: "chevron.left", title: text.previousMonth) { move(-1) }
                NotchIconButton(symbol: "chevron.right", title: text.nextMonth) { move(1) }
            }
            LazyVGrid(columns: columns, spacing: NotchDesign.Spacing.xxSmall) {
                if weekNumbers { Color.clear.frame(height: 18).accessibilityHidden(true) }
                ForEach(0..<7, id: \.self) { column in
                    let index = (Calendar.current.firstWeekday - 1 + column) % 7
                    Text(weekdaySymbols[index])
                        .font(NotchDesign.Typography.caption.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .frame(maxWidth: .infinity).frame(height: 18)
                        .accessibilityHidden(true)
                }
                ForEach(NotchCalendarSupport.monthDays(containing: month), id: \.self) { date in
                    if weekNumbers, NotchCalendarSupport.startsWeek(date) {
                        NotchCalendarWeekNumber(date: date, text: text, digit: 24, spacing: 2, height: 30)
                    }
                    dayButton(date)
                }
            }
            HStack {
                NotchCalendarPill(title: text.today, action: today)
                Spacer(minLength: NotchDesign.Spacing.xSmall)
                NotchIconButton(symbol: "arrow.up.forward.app", title: text.openCalendar, action: open)
            }
        }
        .foregroundStyle(NotchDesign.Ink.primary)
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.veryShortStandaloneWeekdaySymbols
    }

    private func dayButton(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let selected = selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let dayEvents = NotchCalendarSupport.events(events, on: date)
        return Button { select(date) } label: {
            VStack(spacing: NotchDesign.Spacing.line) {
                // The number alone: a formatted day carries the language's suffix,
                // as 28日 or 28일, which the circle cuts off.
                Text(calendar.component(.day, from: date), format: .number)
                    .modifier(NotchCalendarDayMark(isToday: isToday, selected: selected, inMonth: inMonth, size: 24))
                NotchCalendarDots(events: dayEvents)
            }
            .frame(maxWidth: .infinity).frame(height: 30)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
        .frame(height: 30)
        .help(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue([isToday ? text.today : "", dayEvents.isEmpty ? "" : text.hasEvents]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One week as a row of days, for islands too short to hold the month grid.
struct NotchCalendarWeekStrip: View {
    static let height: CGFloat = 52
    let width: CGFloat
    let focus: Date
    let selectedDay: Date?
    let now: Date
    let events: [NotchCalendarEvent]
    let text: NotchCalendarStrings
    let select: (Date) -> Void
    let move: (Int) -> Void
    let today: () -> Void
    let week: () -> Void
    let month: () -> Void
    let open: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: NotchDesign.Spacing.xSmall) {
            NotchIconButton(symbol: "chevron.left", title: text.previousWeek) { move(-1) }
            ForEach(NotchCalendarSupport.weekDays(containing: focus), id: \.self) { date in
                dayButton(date)
            }
            NotchIconButton(symbol: "chevron.right", title: text.nextWeek) { move(1) }
            // The same order as the month grid's header: Today, Week and Month,
            // Open. The narrowest island drops Today and Open and keeps every
            // day tappable: a second tap on the selected day still returns to
            // the coming week, and every appointment card opens Calendar.
            if width >= 400 {
                NotchCalendarPill(title: text.today, action: today)
            }
            NotchCalendarViewSwitch(monthSelected: false, text: text, week: week, month: month)
            if width >= 340 {
                NotchIconButton(symbol: "arrow.up.forward.app", title: text.openCalendar, action: open)
            }
        }
        .frame(height: Self.height)
        .foregroundStyle(NotchDesign.Ink.primary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(focus, format: .dateTime.month(.wide).year()))
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.veryShortStandaloneWeekdaySymbols
    }

    private func dayButton(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let selected = selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let dayEvents = NotchCalendarSupport.events(events, on: date)
        // A second tap on the selected day returns to the coming week.
        return Button { selected ? week() : select(date) } label: {
            VStack(spacing: NotchDesign.Spacing.line) {
                Text(weekdaySymbols[calendar.component(.weekday, from: date) - 1])
                    .font(NotchDesign.Typography.caption.font)
                    .foregroundStyle(NotchDesign.Ink.secondary)
                Text(calendar.component(.day, from: date), format: .number)
                    .modifier(NotchCalendarDayMark(isToday: isToday, selected: selected, inMonth: true, size: 26))
                NotchCalendarDots(events: dayEvents)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control)))
        .help(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue([isToday ? text.today : "", dayEvents.isEmpty ? "" : text.hasEvents]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The month in an island too short for the grid beside the agenda: one
/// header row with the title, the navigation, Today and Calendar, then rows
/// sized to what is left. Choosing a day returns to the week on that day.
struct NotchCalendarMonthGrid: View {
    let month: Date
    let selectedDay: Date?
    let now: Date
    let height: CGFloat
    let events: [NotchCalendarEvent]
    let text: NotchCalendarStrings
    let select: (Date) -> Void
    let move: (Int) -> Void
    let today: () -> Void
    let open: () -> Void
    let week: () -> Void
    @Environment(\.locale) private var locale
    @AppStorage(DefaultsKey.notchCalendarWeekNumbers) private var weekNumbers = false
    private var columns: [GridItem] { NotchCalendarWeekNumber.columns(numbered: weekNumbers) }

    private var rowHeight: CGFloat { NotchLayout.calendarMonthRowHeight(height: height) }
    private var circle: CGFloat { min(24, rowHeight - NotchCalendarDots.side) }

    var body: some View {
        VStack(spacing: NotchLayout.calendarMonthSpacing) {
            HStack(spacing: NotchDesign.Spacing.xSmall) {
                NotchIconButton(symbol: "chevron.left", title: text.previousMonth) { move(-1) }
                Text(month, format: .dateTime.month(.wide).year())
                    .font(NotchDesign.Typography.title.font).lineLimit(1)
                    .minimumScaleFactor(max(0.8, NotchDesign.Typography.title.minimumScale))
                    .frame(maxWidth: .infinity, alignment: .leading)
                NotchIconButton(symbol: "chevron.right", title: text.nextMonth) { move(1) }
                // The fixed order on both views: Today, Week and Month, Open.
                NotchCalendarPill(title: text.today, action: today)
                NotchCalendarViewSwitch(monthSelected: true, text: text, week: week, month: {})
                NotchIconButton(symbol: "arrow.up.forward.app", title: text.openCalendar, action: open)
            }
            .frame(height: NotchLayout.calendarMonthHeaderHeight)
            LazyVGrid(columns: columns, spacing: 0) {
                if weekNumbers {
                    Color.clear.frame(height: NotchLayout.calendarMonthWeekdayHeight).accessibilityHidden(true)
                }
                ForEach(0..<7, id: \.self) { column in
                    let index = (Calendar.current.firstWeekday - 1 + column) % 7
                    Text(weekdaySymbols[index])
                        .font(NotchDesign.Typography.caption.font)
                        .foregroundStyle(NotchDesign.Ink.secondary)
                        .frame(maxWidth: .infinity).frame(height: NotchLayout.calendarMonthWeekdayHeight)
                        .accessibilityHidden(true)
                }
                ForEach(NotchCalendarSupport.monthDays(containing: month), id: \.self) { date in
                    if weekNumbers, NotchCalendarSupport.startsWeek(date) {
                        NotchCalendarWeekNumber(date: date, text: text, digit: circle, spacing: 0, height: rowHeight)
                    }
                    dayButton(date)
                }
            }
        }
        .foregroundStyle(NotchDesign.Ink.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.veryShortStandaloneWeekdaySymbols
    }

    private func dayButton(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let selected = selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let dayEvents = NotchCalendarSupport.events(events, on: date)
        return Button { select(date) } label: {
            VStack(spacing: 0) {
                Text(calendar.component(.day, from: date), format: .number)
                    .modifier(NotchCalendarDayMark(isToday: isToday, selected: selected, inMonth: inMonth, size: circle))
                    .minimumScaleFactor(max(0.7, NotchDesign.Typography.label.minimumScale))
                NotchCalendarDots(events: dayEvents)
            }
            .frame(maxWidth: .infinity).frame(height: rowHeight)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(NotchDesign.Radius.control), lifts: false))
        .frame(height: rowHeight)
        .help(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue([isToday ? text.today : "", dayEvents.isEmpty ? "" : text.hasEvents]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The number of the week a row of the month grid holds, in a narrow column
/// ahead of its days. It is laid out like a day, above the room a day keeps
/// for its event dots, so both sit on one line. No day's label names its
/// week, so VoiceOver reads the number as a week ahead of the row's days.
struct NotchCalendarWeekNumber: View {
    static let width: CGFloat = 18
    let date: Date
    let text: NotchCalendarStrings
    let digit: CGFloat
    let spacing: CGFloat
    let height: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    static func columns(numbered: Bool) -> [GridItem] {
        (numbered ? [GridItem(.fixed(width), spacing: 0)] : [])
            + Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    var body: some View {
        VStack(spacing: spacing) {
            Text(NotchCalendarSupport.weekNumber(of: date), format: .number)
                .font(NotchDesign.Typography.caption.font.monospacedDigit())
                .foregroundStyle(contrast == .increased ? NotchDesign.Ink.secondary : NotchDesign.Ink.tertiary)
                .frame(height: digit)
                .accessibilityLabel(NotchCalendarSupport.weekNumberLabel(of: date, text: text))
            Color.clear.frame(height: NotchCalendarDots.side)
        }
        .frame(width: Self.width, height: height)
    }
}
