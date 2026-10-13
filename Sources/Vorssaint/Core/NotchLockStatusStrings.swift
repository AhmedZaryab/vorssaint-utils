// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct NotchLockStatusStrings {
    let show: String
    let hint: String
    let battery: String
    let keepAwake: String
}

extension FeatureStrings {
    /// Pt-BR and Spanish are translated; the other languages read English until translated.
    static func notchLockStatus(_ language: AppLanguage) -> NotchLockStatusStrings {
        switch language {
        case .ptBR: return NotchLockStatusStrings(
            show: "Bateria e Manter Ativo na Tela Bloqueada",
            hint: "Mostra a carga da bateria e uma sessão de Manter Ativo sob o relógio. Quem puder ver sua tela também poderá lê-los.",
            battery: "Bateria", keepAwake: "Manter Ativo")
        case .es: return NotchLockStatusStrings(
            show: "Batería y Mantener activo en la pantalla de bloqueo",
            hint: "Muestra la carga de la batería y una sesión de Mantener activo bajo el reloj. Cualquiera que vea tu pantalla podrá leerlos.",
            battery: "Batería", keepAwake: "Mantener activo")
        default: return NotchLockStatusStrings(
            show: "Battery and Keep Awake on the Lock Screen",
            hint: "Shows the battery charge and a running Keep Awake session under the clock. Anyone who can see your screen can read them.",
            battery: "Battery", keepAwake: "Keep Awake")
        }
    }
}
