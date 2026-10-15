// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

private typealias Design = NotchDesign

/// The AI page: cards the person picked, paired across the strip.
struct NotchAgentsView: View {
    let size: CGSize
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchAgentsPeriod) private var period = AgentPeriod.today.rawValue
    @AppStorage(DefaultsKey.notchAgentsLimitDisplay) private var display = NotchAgentLimitDisplay.remaining.rawValue
    @AppStorage(DefaultsKey.notchAgentsCardOrder) private var cardOrder = ""
    @AppStorage(DefaultsKey.notchAgentsHiddenCards) private var hiddenCards = ""
    @AppStorage(DefaultsKey.notchAgentsClaude) private var claude = true
    @AppStorage(DefaultsKey.notchAgentsCodex) private var codex = true
    @AppStorage(DefaultsKey.notchAgentsOpenCode) private var opencode = true
    @AppStorage(DefaultsKey.notchAgentsCopilot) private var copilot = true

    private var text: NotchAgentStrings { FeatureStrings.notchAgents(l10n.language) }
    private var chosenPeriod: AgentPeriod { AgentPeriod(rawValue: period) ?? .today }

    /// Only agents that left something on this Mac get cards.
    private var providers: [AgentProvider] {
        [claude ? AgentProvider.claude : nil, codex ? .codex : nil, opencode ? .opencode : nil, copilot ? .copilot : nil].compactMap { $0 }
            .filter(usage.snapshot.seen.contains)
    }

    private var rows: [[NotchAgentTile]] {
        // The strings are read here so a change in Settings redraws the page.
        _ = (cardOrder, hiddenCards)
        return NotchAgentSupport.rows(NotchAgentSupport.tiles(cards: NotchAgentSupport.cards(), providers: providers),
                                      width: size.width)
    }

    var body: some View {
        Group {
            if !usage.snapshot.loaded {
                VStack(spacing: Design.Spacing.medium) {
                    ProgressView().controlSize(.small)
                    Text(text.loading).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if providers.isEmpty {
                NotchEmptyView(symbol: "sparkles", message: text.empty)
            } else if rows.isEmpty {
                NotchEmptyView(symbol: "square.grid.2x2", message: text.noCards)
            } else {
                let rows = rows
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    if NotchAgentSupport.contentHeight(rows) > size.height + 0.5 {
                        ScrollView { grid(rows, now: context.date) }
                            .scrollIndicators(.never)
                            .notchScrollEdgeFade()
                    } else {
                        grid(rows, now: context.date)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .environment(\.locale, l10n.language.formattingLocale())
        .onAppear { usage.pageDidAppear() }
    }

    private func grid(_ rows: [[NotchAgentTile]], now: Date) -> some View {
        VStack(spacing: NotchAgentSupport.spacing) {
            ForEach(rows, id: \.first?.id) { row in
                HStack(spacing: NotchAgentSupport.spacing) {
                    ForEach(row) { tile in card(tile, now: now) }
                }
                .frame(height: NotchAgentSupport.height(of: row))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder private func card(_ tile: NotchAgentTile, now: Date) -> some View {
        let snapshot = usage.snapshot
        let shown = chosenPeriod
        switch tile.card {
        case .limits:
            if let provider = tile.provider {
                NotchAgentLimitsCard(provider: provider, snapshot: snapshot, now: now,
                                     display: NotchAgentLimitDisplay(rawValue: display) ?? .remaining, text: text)
            }
        case .spend:
            NotchAgentSpendCard(snapshot: snapshot, providers: providers, period: $period, text: text)
        case .live:
            NotchAgentLiveCard(snapshot: snapshot, providers: providers, text: text)
        case .trend:
            NotchAgentTrendCard(snapshot: snapshot, providers: providers, period: shown, text: text)
        case .models:
            NotchAgentShareCard(title: text.modelsCard, symbol: NotchAgentCard.models.symbol,
                                shares: snapshot.usage(shown).models, byCost: snapshot.usage(shown).fullyPriced, text: text)
        case .projects:
            NotchAgentShareCard(title: text.projectsCard, symbol: NotchAgentCard.projects.symbol,
                                shares: snapshot.usage(shown).projects, byCost: snapshot.usage(shown).fullyPriced, text: text)
        case .activity:
            NotchAgentActivityCard(snapshot: snapshot, text: text)
        case .resets:
            NotchAgentResetsCard(now: now, text: text)
        }
    }
}

/// A small plate for a plan name, a count or a multiple. The plate is neutral: an agent's colour stays on its mark.
private struct NotchAgentChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Design.Typography.caption.font)
            .monospacedDigit()
            .foregroundStyle(Design.Ink.secondary)
            .lineLimit(1)
            .padding(.horizontal, Design.Spacing.xxSmall + 1)
            .padding(.vertical, Design.Spacing.line)
            .background(Design.Fill.control, in: Capsule(style: .continuous))
    }
}

// MARK: Limits

private struct NotchAgentLimitsCard: View {
    let provider: AgentProvider
    let snapshot: AgentUsageSnapshot
    let now: Date
    let display: NotchAgentLimitDisplay
    let text: NotchAgentStrings
    @Environment(\.locale) private var locale

    /// A reading the Claude app saved a while ago: still the latest known,
    /// shown quieter until the app checks again.
    private var stale: Bool {
        guard let limits = snapshot.limits[provider], limits.source == .claudeApp else { return false }
        return now.timeIntervalSince(limits.observedAt) >= AgentClaudeAppUsage.freshness
    }

    /// Two rows fit: the session and whichever longer window binds first.
    private var windows: [AgentLimitWindow] {
        let all = (snapshot.limits[provider]?.windows ?? []).map { AgentLimitSupport.current($0, at: now) }
        let session = all.first { $0.kind == .session }
        let longer = all.filter { $0.kind != .session }.max { $0.usedPercent < $1.usedPercent }
        return [session, longer].compactMap { $0 }
    }

    var body: some View {
        let windows = windows
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xxSmall) {
                NotchAgentCardHeader(title: provider.displayName, symbol: provider.symbol, tint: provider.tint,
                                     provider: provider) {
                    HStack(spacing: Design.Spacing.xxSmall) {
                        if let plan = snapshot.plans[provider] { NotchAgentChip(text: plan.name) }
                        if !snapshot.working(provider).isEmpty { NotchAgentPulse(tint: Design.Ink.primary, size: 5) }
                    }
                }
                if windows.isEmpty {
                    estimate
                } else {
                    VStack(spacing: Design.Spacing.xxSmall) {
                        ForEach(windows) { row($0) }
                    }
                    .opacity(stale ? Design.Opacity.secondary : Design.Opacity.primary)
                    if windows.count == 1 || stale { caption }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// How old a reading is, once it is old enough to have missed use elsewhere.
    @ViewBuilder private var caption: some View {
        if let observed = snapshot.limits[provider]?.observedAt, now.timeIntervalSince(observed) > 600 {
            Text(text.updated(observed.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)
                .locale(locale))))
                .font(Design.Typography.caption.font)
                .foregroundStyle(Design.Ink.secondary)
                .lineLimit(1)
        }
    }

    /// A usage-based forecast would read as a promise, so a row says only
    /// what is spent and when the window renews.
    private func row(_ window: AgentLimitWindow) -> some View {
        let pace = AgentLimitSupport.pace(for: window, now: now)
        let tint = agentLimitTint(provider, usedFraction: window.usedFraction)
        let remaining = display == .remaining
        let fraction = remaining ? window.remainingFraction : window.usedFraction
        return VStack(alignment: .leading, spacing: Design.Spacing.line) {
            HStack(spacing: Design.Spacing.xxSmall) {
                Text(label(window))
                    .font(Design.Typography.caption.font)
                    .foregroundStyle(Design.Ink.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
                Group {
                    if let resets = window.resetsAt {
                        Label(countdown(to: resets), systemImage: "arrow.clockwise")
                            .labelStyle(NotchAgentInlineLabel())
                            .monospacedDigit()
                            .foregroundStyle(Design.Ink.secondary)
                    }
                }
                .font(Design.Typography.caption.font)
                .lineLimit(1)
                .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.caption, preferred: 0.8))
                Spacer(minLength: Design.Spacing.line)
                if agentLimitIsNear(usedFraction: window.usedFraction) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Design.Typography.caption.font)
                        .foregroundStyle(tint)
                        .accessibilityLabel(text.usedShare(AgentFormat.percent(window.usedFraction)))
                }
                Text(remaining ? text.left(AgentFormat.percent(fraction)) : text.usedShare(AgentFormat.percent(fraction)))
                    .font(Design.Typography.readout.font)
                    .monospacedDigit()
                    .foregroundStyle(Design.Ink.primary)
                    .contentTransition(.numericText())
            }
            NotchAgentMeter(value: fraction, pace: pace.map { remaining ? 1 - $0.elapsed : $0.elapsed },
                            tint: tint)
        }
        .help(help(window))
    }

    /// What the window covers: its length, or the model it is kept for.
    private func label(_ window: AgentLimitWindow) -> String {
        switch window.kind {
        case .session: return text.session
        case .weekly: return window.scope.map { "\(text.weekly) · \($0)" } ?? text.weekly
        case .other:
            guard let minutes = window.minutes else { return window.scope ?? text.readoutLimit }
            return AgentFormat.duration(TimeInterval(minutes) * 60, locale: locale, units: 1)
        }
    }

    /// How long until the window renews: days and hours, or hours and
    /// minutes, never seconds on a card that redraws every few. The day and
    /// time are in the tooltip.
    private func countdown(to date: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        return AgentFormat.duration(max(60, seconds), locale: locale, units: seconds >= 3600 ? 2 : 1)
    }

    private func help(_ window: AgentLimitWindow) -> String {
        var parts = [label(window), text.usedShare(AgentFormat.percent(window.usedFraction)),
                     text.left(AgentFormat.percent(window.remainingFraction))]
        if let resets = window.resetsAt {
            parts.append(resets.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))
        }
        if let observed = snapshot.limits[provider]?.observedAt, now.timeIntervalSince(observed) > 600 {
            parts.append(text.updated(observed.formatted(.relative(presentation: .named).locale(locale))))
        }
        return parts.joined(separator: " · ")
    }

    /// Without a recent reading from the Claude app, the session still ends
    /// five hours after its first request, so the window itself is known.
    @ViewBuilder private var estimate: some View {
        if provider == .claude, let block = snapshot.claudeBlock {
            let length = block.end.timeIntervalSince(block.start)
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                HStack(spacing: Design.Spacing.xxSmall) {
                    Text(text.session)
                        .font(Design.Typography.caption.font)
                        .foregroundStyle(Design.Ink.primary)
                    Label(countdown(to: block.end), systemImage: "arrow.clockwise")
                        .labelStyle(NotchAgentInlineLabel())
                        .font(Design.Typography.caption.font)
                        .monospacedDigit()
                        .foregroundStyle(Design.Ink.secondary)
                    Spacer(minLength: Design.Spacing.line)
                    Text(AgentFormat.cost(block.totals.cost))
                        .font(Design.Typography.readout.font)
                        .monospacedDigit()
                }
                NotchAgentMeter(value: length > 0 ? now.timeIntervalSince(block.start) / length : 0,
                                dimmed: true)
            }
            .help(text.estimated)
            setUpLimits
        } else if provider == .claude {
            Text(text.noSession).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary)
            setUpLimits
        } else if provider == .opencode {
            let todayUsage = snapshot.usage(.today).byProvider[.opencode]
            if let todayUsage, todayUsage.tokens.total > 0 || todayUsage.requests > 0 || todayUsage.cost > 0 {
                // A cost with unpriced models in it is only a floor, so the figure is the tokens instead,
                // as the trend card does.
                let priced = todayUsage.unpriced == 0
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    HStack(spacing: Design.Spacing.xxSmall) {
                        Text(text.period(.today))
                            .font(Design.Typography.caption.font)
                            .foregroundStyle(Design.Ink.primary)
                        Spacer(minLength: Design.Spacing.line)
                        Text(priced ? AgentFormat.cost(todayUsage.cost) : AgentFormat.tokens(todayUsage.tokens.total))
                            .font(Design.Typography.readout.font)
                            .monospacedDigit()
                    }
                    .help(priced ? text.valueNote : text.unpriced)
                    HStack(spacing: Design.Spacing.xxSmall) {
                        if priced {
                            Text(AgentFormat.tokens(todayUsage.tokens.total))
                                .font(Design.Typography.caption.font)
                                .monospacedDigit()
                                .foregroundStyle(Design.Ink.secondary)
                        }
                        if let rate = todayUsage.tokens.cacheHitRate, rate > 0 {
                            Text((priced ? "· " : "") + text.cached(AgentFormat.percent(rate)))
                                .font(Design.Typography.caption.font)
                                .foregroundStyle(Design.Ink.secondary)
                        }
                        Spacer()
                        lastUsed
                    }
                }
            } else {
                Text(text.noSession).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary)
                lastUsed
            }
        } else {
            Text(text.waitingForLimits).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary).lineLimit(2)
            lastUsed
        }
    }

    /// Claude's plan limits come from the Claude app; the settings say how.
    private var setUpLimits: some View {
        Button {
            NotchService.shared.openSettings(showing: .agents)
        } label: {
            Label(text.claudeLimitsHint, systemImage: "arrow.up.forward")
                .labelStyle(NotchAgentInlineLabel())
                .font(Design.Typography.caption.font)
                .foregroundStyle(Design.Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.caption, preferred: 0.85))
                .padding(.horizontal, Design.Spacing.xxSmall)
                .agentHitTarget(drawnHeight: 14)
        }
        .buttonStyle(NotchPressStyle(shape: .rounded(Design.Radius.control), lifts: false))
    }

    @ViewBuilder private var lastUsed: some View {
        if let last = snapshot.lastActivity[provider] {
            Text(last.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(locale)))
                .font(Design.Typography.caption.font)
                .foregroundStyle(Design.Ink.secondary)
        }
    }
}

/// A glyph and its words, closer together than a stock label.
private struct NotchAgentInlineLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Design.Spacing.line) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

// MARK: Spending

private struct NotchAgentSpendCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    @Binding var period: String
    let text: NotchAgentStrings

    private var chosen: AgentPeriod { AgentPeriod(rawValue: period) ?? .today }

    var body: some View {
        let usage = snapshot.usage(chosen)
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.line) {
                NotchAgentCardHeader(title: text.spendCard, symbol: NotchAgentCard.spend.symbol) { periodMenu }
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.xSmall) {
                    // Some models without a price make the cost only a floor; the figure is then the tokens.
                    Text(usage.fullyPriced ? AgentFormat.cost(usage.total.cost)
                         : text.tokens(AgentFormat.tokens(usage.total.tokens.total)))
                        .font(Design.Typography.display.font)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.display, preferred: 0.5))
                    if usage.fullyPriced {
                        Text(text.apiValue)
                            .font(Design.Typography.caption.font)
                            .foregroundStyle(Design.Ink.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if chosen == .month { multiples(usage) }
                }
                .help(usage.fullyPriced ? text.valueNote : text.unpriced)
                split(usage)
                    .padding(.vertical, Design.Spacing.line)
                Text(footer(usage))
                    .font(Design.Typography.caption.font)
                    .foregroundStyle(Design.Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.caption, preferred: 0.85))
                    .help(text.saved(AgentFormat.cost(usage.total.savings)))
            }
        }
    }

    private var periodMenu: some View {
        NotchPullDown(title: text.period(chosen), current: text.period(chosen), items: AgentPeriod.allCases.map { option in
            NotchMenuItem(title: text.period(option), checked: option == chosen) { period = option.rawValue }
        })
    }

    /// Thirty days of API value against a plan's monthly price.
    @ViewBuilder private func multiples(_ usage: AgentPeriodUsage) -> some View {
        HStack(spacing: Design.Spacing.line) {
            ForEach(providers) { provider in
                if let plan = snapshot.plans[provider], let price = plan.monthlyPrice, price > 0,
                   let spent = usage.byProvider[provider]?.cost, spent > 0 {
                    let multiple = (spent / price).formatted(.number.precision(.fractionLength(spent / price < 10 ? 1 : 0))) + "×"
                    NotchAgentChip(text: multiple)
                        .help(text.planMultiple(multiple, plan: "\(provider.displayName) \(plan.name)"))
                }
            }
        }
    }

    @ViewBuilder private func split(_ usage: AgentPeriodUsage) -> some View {
        let byCost = usage.fullyPriced
        let parts = providers.map { usage.byProvider[$0]?.weight(byCost: byCost) ?? 0 }
        let total = parts.reduce(0, +)
        let shown = parts.filter { $0 > 0 }.count
        GeometryReader { proxy in
            let gap = Design.Spacing.line
            let sliver = Design.Control.meter
            // Every agent keeps a visible sliver; the rest shares what is left.
            let room = max(0, proxy.size.width - gap * CGFloat(max(0, shown - 1)) - sliver * CGFloat(shown))
            HStack(spacing: gap) {
                if total <= 0 {
                    Capsule().fill(Design.Fill.track)
                } else {
                    ForEach(providers.indices, id: \.self) { index in
                        if parts[index] > 0 {
                            Capsule(style: .continuous).fill(Design.Ink.primary.opacity(NotchAgentBars.slotOpacity(index, active: true)))
                                .frame(width: sliver + room * parts[index] / total)
                        }
                    }
                }
            }
        }
        .frame(height: Design.Control.meter)
        .accessibilityHidden(true)
    }

    private func footer(_ usage: AgentPeriodUsage) -> String {
        var parts = usage.fullyPriced ? [text.tokens(AgentFormat.tokens(usage.total.tokens.total))] : []
        if let rate = usage.total.tokens.cacheHitRate, rate > 0 { parts.append(text.cached(AgentFormat.percent(rate))) }
        return parts.joined(separator: " · ")
    }
}

// MARK: Now

private struct NotchAgentLiveCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    let text: NotchAgentStrings
    @Environment(\.locale) private var locale

    var body: some View {
        let live = snapshot.live.filter { providers.contains($0.provider) }
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xxSmall) {
                NotchAgentCardHeader(title: text.liveCard, symbol: NotchAgentCard.live.symbol,
                                     tint: Design.Ink.secondary) {
                    HStack(spacing: Design.Spacing.xxSmall) {
                        if live.count > 2 { NotchAgentChip(text: "+\(live.count - 2)") }
                        if let first = live.first { NotchAgentPulse(tint: Design.Ink.primary, size: 5) }
                    }
                }
                if live.isEmpty {
                    VStack(alignment: .leading, spacing: Design.Spacing.xxSmall) {
                        ForEach(providers) { idleRow($0) }
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: Design.Spacing.xxSmall) {
                            ForEach(live.prefix(2)) { row($0, now: context.date) }
                        }
                    }
                }
            }
        }
    }

    private func row(_ session: AgentLiveSession, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Design.Spacing.xxSmall) {
                NotchAgentGlyph(provider: session.provider, size: 9)
                Text(session.project.isEmpty ? session.provider.displayName : session.project)
                    .font(Design.Typography.stripPrimary.font)
                    .foregroundStyle(Design.Ink.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Design.Spacing.xxSmall)
                Text(AgentFormat.clock(now.timeIntervalSince(session.started)))
                    .font(Design.Typography.readout.font)
                    .monospacedDigit()
                    .foregroundStyle(Design.Ink.primary)
            }
            // Tokens the agent wrote, as its own window counts them; every
            // call also reads the whole context again, which the tooltip and
            // the cost include.
            Text([AgentPricing.displayName(session.model),
                  session.tokens.output > 0 ? text.written(AgentFormat.tokens(session.tokens.output)) : "",
                  session.cost > 0 ? AgentFormat.cost(session.cost) : ""]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(Design.Typography.caption.font)
                .foregroundStyle(Design.Ink.secondary)
                .lineLimit(1)
        }
        .help(text.tokens(AgentFormat.tokens(session.tokens.total)) + " · "
              + text.cached(AgentFormat.percent(session.tokens.cacheHitRate ?? 0)))
    }

    private func idleRow(_ provider: AgentProvider) -> some View {
        HStack(spacing: Design.Spacing.xxSmall) {
            NotchAgentGlyph(provider: provider, size: 9, working: false)
            Text(provider.displayName).font(Design.Typography.label.font).foregroundStyle(Design.Ink.primary)
            Spacer(minLength: Design.Spacing.xxSmall)
            Text(snapshot.lastActivity[provider].map {
                $0.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(locale))
            } ?? text.idle)
                .font(Design.Typography.caption.font)
                .foregroundStyle(Design.Ink.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: Trend

private struct NotchAgentTrendCard: View {
    let snapshot: AgentUsageSnapshot
    let providers: [AgentProvider]
    let period: AgentPeriod
    let text: NotchAgentStrings
    @State private var hovered: Date?
    @Environment(\.locale) private var locale

    private var buckets: [AgentBucket] {
        period == .today ? snapshot.hours : Array(snapshot.days.suffix(period.days))
    }

    var body: some View {
        let byCost = snapshot.usage(period).fullyPriced
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xSmall) {
                NotchAgentCardHeader(title: text.trendCard, symbol: NotchAgentCard.trend.symbol) {
                    Text(caption(byCost: byCost))
                        .font(Design.Typography.caption.font)
                        .monospacedDigit()
                        .foregroundStyle(Design.Ink.secondary)
                        .lineLimit(1)
                }
                NotchAgentBars(buckets: buckets, providers: providers, byCost: byCost, hovered: $hovered)
                axis
            }
        }
    }

    private func caption(byCost: Bool) -> String {
        if let hovered, let bucket = buckets.first(where: { $0.start == hovered }) {
            // A pointed-at bar reads its tokens beside its cost.
            let tokens = byCost ? " · " + value(bucket.total, byCost: false) : ""
            return label(bucket.start, long: true) + " · " + value(bucket.total, byCost: byCost) + tokens
        }
        return text.period(period) + " · " + value(snapshot.usage(period).total, byCost: byCost)
    }

    private func value(_ totals: AgentTotals, byCost: Bool) -> String {
        byCost ? AgentFormat.cost(totals.cost) : text.tokens(AgentFormat.tokens(totals.tokens.total))
    }

    private func label(_ date: Date, long: Bool) -> String {
        if period == .today { return date.formatted(.dateTime.hour().locale(locale)) }
        if period == .week, !long { return date.formatted(.dateTime.weekday(.narrow).locale(locale)) }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// Every bar a letter over a week; the ends and the middle otherwise.
    private var axis: some View {
        let marks: [Int] = period == .week ? Array(buckets.indices)
            : buckets.isEmpty ? [] : [0, buckets.count / 2, buckets.count - 1]
        return HStack(spacing: 0) {
            if period == .week {
                ForEach(marks, id: \.self) { index in
                    Text(label(buckets[index].start, long: false)).frame(maxWidth: .infinity)
                }
            } else {
                ForEach(Array(marks.enumerated()), id: \.offset) { position, index in
                    if position > 0 { Spacer(minLength: Design.Spacing.xxSmall) }
                    Text(label(buckets[index].start, long: false))
                }
            }
        }
        .font(Design.Typography.caption.font)
        .foregroundStyle(Design.Ink.secondary)
        .lineLimit(1)
        .frame(height: 12)
    }
}

// MARK: Models and projects

private struct NotchAgentShareCard: View {
    let title: String
    let symbol: String
    let shares: [AgentShare]
    let byCost: Bool
    let text: NotchAgentStrings

    var body: some View {
        let shown = Array(shares.prefix(3))
        let peak = max(shown.map { $0.totals.weight(byCost: byCost) }.max() ?? 0, .leastNonzeroMagnitude)
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xSmall) {
                NotchAgentCardHeader(title: title, symbol: symbol)
                if shown.isEmpty {
                    Text(text.noActivity).font(Design.Typography.label.font).foregroundStyle(Design.Ink.secondary)
                } else {
                    VStack(spacing: Design.Spacing.line) {
                        ForEach(shown) { share in row(share, peak: peak) }
                    }
                }
            }
        }
    }

    private func row(_ share: AgentShare, peak: Double) -> some View {
        let weight = share.totals.weight(byCost: byCost)
        let tint = Design.Ink.primary
        let barWidth = Design.Agents.shareBarWidth
        return HStack(spacing: Design.Spacing.xSmall) {
            Text(share.name)
                .font(Design.Typography.label.font)
                .foregroundStyle(Design.Ink.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Capsule(style: .continuous)
                .fill(tint)
                .frame(width: max(Design.Control.meter, barWidth * weight / peak), height: Design.Control.meter)
                .frame(width: barWidth, alignment: .leading)
            Text(byCost ? AgentFormat.cost(share.totals.cost) : AgentFormat.tokens(share.totals.tokens.total))
                .font(Design.Typography.caption.font)
                .monospacedDigit()
                .foregroundStyle(Design.Ink.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .frame(height: 16)
        .help([share.name, text.tokens(AgentFormat.tokens(share.totals.tokens.total)),
               AgentFormat.cost(share.totals.cost)].joined(separator: " · "))
    }
}

// MARK: Activity

private struct NotchAgentActivityCard: View {
    let snapshot: AgentUsageSnapshot
    let text: NotchAgentStrings
    @State private var hovered: Date?
    @Environment(\.locale) private var locale

    /// Days in a row with any use, counting today only once it has some.
    private var streak: Int {
        var count = 0
        for day in snapshot.days.reversed() {
            if day.total.requests > 0 { count += 1 }
            else if count > 0 || day.id != snapshot.days.last?.id { break }
        }
        return count
    }

    var body: some View {
        let byCost = snapshot.days.allSatisfy { $0.total.unpriced == 0 }
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xSmall) {
                NotchAgentCardHeader(title: text.activityCard, symbol: NotchAgentCard.activity.symbol) {
                    if streak > 1 {
                        Label("\(streak)", systemImage: "flame.fill")
                            .labelStyle(NotchAgentInlineLabel())
                            .font(Design.Typography.caption.font)
                            .monospacedDigit()
                            .foregroundStyle(Design.Ink.secondary)
                            .help(text.streak)
                            .accessibilityLabel(text.streak)
                            .accessibilityValue("\(streak)")
                    }
                }
                GeometryReader { proxy in
                    let map = NotchAgentHeatmap.width(height: proxy.size.height, days: snapshot.days)
                    HStack(alignment: .top, spacing: Design.Spacing.medium) {
                        NotchAgentHeatmap(days: snapshot.days, byCost: byCost, hovered: $hovered)
                            .frame(width: map, height: proxy.size.height)
                        figures(byCost: byCost)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    /// The total for the whole map, its active days and its busiest day; a
    /// hovered day takes the place of the busiest one.
    private func figures(byCost: Bool) -> some View {
        let active = snapshot.days.filter { $0.total.requests > 0 }
        let busiest = active.max { $0.total.weight(byCost: byCost) < $1.total.weight(byCost: byCost) }
        let pointed = hovered.flatMap { date in snapshot.days.first { $0.start == date } }
        return VStack(alignment: .leading, spacing: Design.Spacing.line) {
            Text(value(snapshot.days.reduce(into: AgentTotals()) { $0 += $1.total }, byCost: byCost))
                .font(Design.Typography.display.font)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.display, preferred: 0.5))
            Text(AgentFormat.span(days: snapshot.days.count, locale: locale))
                .font(Design.Typography.caption.font).foregroundStyle(Design.Ink.secondary).lineLimit(1)
            Spacer(minLength: Design.Spacing.xxSmall)
            figure(text.activeDays, "\(active.count)")
            if let day = pointed ?? busiest {
                figure(pointed == nil ? text.busiestDay : day.start.formatted(.dateTime.weekday(.wide).locale(locale)),
                       day.start.formatted(.dateTime.day().month(.abbreviated).locale(locale)) + " · " + value(day.total, byCost: byCost))
            }
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        HStack(spacing: Design.Spacing.xSmall) {
            Text(label).foregroundStyle(Design.Ink.secondary).lineLimit(1)
            Spacer(minLength: Design.Spacing.xxSmall)
            Text(value).monospacedDigit().foregroundStyle(Design.Ink.primary).lineLimit(1)
        }
        .font(Design.Typography.caption.font)
        .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.caption, preferred: 0.85))
    }

    private func value(_ totals: AgentTotals, byCost: Bool) -> String {
        byCost ? AgentFormat.cost(totals.cost) : AgentFormat.tokens(totals.tokens.total)
    }
}

// MARK: Resets

/// Codex's banked resets: how many the account holds, when the next one
/// expires, and a use that is a fuse. Pressing Use reset does not spend it:
/// the button reads Undo in the same place while it burns, so a double click
/// can never spend one, and it commits only when the burn ends.
private struct NotchAgentResetsCard: View {
    let now: Date
    let text: NotchAgentStrings
    @ObservedObject private var resets = AgentCodexResetService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.locale) private var locale

    private let tint = AgentProvider.codex.tint

    /// What a use did stays on the card for a minute.
    private var finished: AgentCodexResetService.Finished? {
        resets.finished.flatMap { now.timeIntervalSince($0.date) < 60 ? $0 : nil }
    }

    var body: some View {
        NotchAgentCardChrome {
            VStack(alignment: .leading, spacing: Design.Spacing.xxSmall) {
                NotchAgentCardHeader(title: text.resetsCard, symbol: NotchAgentCard.resets.symbol, tint: tint,
                                     provider: .codex) {
                    if let summary = resets.summary, summary.available > 0 {
                        NotchAgentChip(text: summary.available.formatted(.number.locale(locale)))
                    } else if resets.checking {
                        ProgressView().controlSize(.mini)
                    }
                }
                content
            }
        }
        .help(text.resetsHelp)
        .onAppear { resets.refreshIfStale() }
    }

    @ViewBuilder private var content: some View {
        if resets.redeeming {
            HStack(spacing: Design.Spacing.xxSmall) {
                ProgressView().controlSize(.mini)
                line(text.resetting)
            }
        } else if let finished {
            if finished.outcome == nil, let summary = resets.summary, summary.available > 0 {
                // Trying again repeats the same use, which never spends a second reset.
                VStack(alignment: .leading, spacing: 0) {
                    outcome(nil)
                    Spacer(minLength: Design.Spacing.xxSmall)
                    useButton
                }
            } else {
                outcome(finished.outcome)
            }
        } else if resets.summary == nil, let failure = resets.failure {
            action(message(failure)) {
                pill(FeatureStrings.notchMusicExtras(l10n.language).retry) {
                    resets.refresh(searchingShell: failure == .missing)
                }
            }
        } else if let summary = resets.summary {
            if summary.available > 0 {
                // A reset a day from expiring is worth using soon.
                let soon = summary.nextExpiry.map { $0.timeIntervalSince(now) < 86_400 } ?? false
                action(summary.nextExpiry.map(expiry) ?? "", tint: soon ? Design.Palette.warning : nil) { useButton }
            } else {
                line(text.resetsNone)
            }
        }
    }

    private var useButton: some View {
        NotchFuseButton(text.useReset, symbol: "arrow.counterclockwise", showsTitle: true) {
            resets.redeem()
        }
    }

    /// A line above the card's buttons, which keep to its bottom edge.
    private func action<Buttons: View>(_ message: String, tint: Color? = nil,
                                       @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.isEmpty {
                Text(message)
                    .font(Design.Typography.label.font)
                    .foregroundStyle(tint ?? Design.Ink.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.label, preferred: 0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Design.Spacing.xxSmall)
            HStack(spacing: Design.Spacing.xSmall) { buttons() }
        }
    }

    private func expiry(_ date: Date) -> String {
        text.resetsExpiry(date.formatted(.relative(presentation: .named).locale(locale)))
    }

    @ViewBuilder private func outcome(_ outcome: AgentCodexServer.Outcome?) -> some View {
        switch outcome {
        case .reset?:
            line(text.resetDone, symbol: "checkmark.circle.fill", tint: Design.Palette.positive)
        case .nothingToReset?:
            line(text.resetNotNeeded, symbol: "info.circle.fill", tint: Design.Ink.secondary)
        case .alreadyRedeemed?:
            line(text.resetTaken, symbol: "info.circle.fill", tint: Design.Ink.secondary)
        case .noCredit?:
            line(text.resetsNone)
        case nil:
            line(text.resetFailed, symbol: "exclamationmark.circle.fill", tint: Design.Palette.warning)
        }
    }

    private func message(_ failure: AgentCodexServer.Failure) -> String {
        switch failure {
        case .missing: return text.resetsNeedCodex
        case .needsSignIn: return text.resetsSignIn
        case .outdated: return text.resetsUpdate
        case .unreachable, .refused: return text.resetsCheckFailed
        }
    }

    private func line(_ message: String, symbol: String? = nil, tint: Color = Design.Ink.secondary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.xxSmall) {
            if let symbol { Image(systemName: symbol).foregroundStyle(tint) }
            Text(message).foregroundStyle(symbol == nil ? Design.Ink.secondary : Design.Ink.primary)
        }
        .font(Design.Typography.label.font)
        .lineLimit(2)
        .minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.label, preferred: 0.85))
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A plain tap pill: the plate is Fill.control, the press and wash are the tap class's.
    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // A narrow island shrinks a long label before cutting it.
            Text(title).lineLimit(1).minimumScaleFactor(Design.Agents.minimumScale(Design.Typography.label, preferred: 0.8))
                .font(Design.Typography.label.font)
                .foregroundStyle(Design.Ink.primary)
                .padding(.horizontal, Design.Spacing.medium)
                .frame(minHeight: Design.Control.rowHeight)
                .background(Design.Fill.control, in: Capsule(style: .continuous))
        }
        .buttonStyle(NotchPressStyle(shape: .capsule))
    }
}
