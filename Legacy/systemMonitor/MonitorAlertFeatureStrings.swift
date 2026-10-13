// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Parked from Sources/Vorssaint/Core/FeatureStrings.swift with the system
// monitor's alerts. Restore by adding this file back and the accessor below
// into `extension FeatureStrings` in FeatureStrings.swift.

import Foundation

extension FeatureStrings {
    static func monitorAlerts(_ language: AppLanguage) -> MonitorAlertFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

struct MonitorAlertFeatureStrings {
    let section: String
    let caption: String
    let notificationsDenied: String
    let cpu: String
    let cpuTemperature: String
    let memory: String
    let disk: String
    let battery: String
    let cpuThreshold: String
    let cpuTemperatureThreshold: String
    let diskThreshold: String
    let batteryThreshold: String
    let cooldown: String
    let cooldown2: String
    let cooldown5: String
    let cooldown15: String
    let cooldown30: String
    let cooldown60: String
    let cpuTitle: String
    let cpuBodyFormat: String
    let cpuTemperatureTitle: String
    let cpuTemperatureBodyFormat: String
    let memoryTitle: String
    let memoryBody: String
    let diskTitle: String
    let diskBodyFormat: String
    let batteryTitle: String
    let batteryBodyFormat: String
    let batteryTemperature: String
    let batteryTemperatureThreshold: String
    let batteryTemperatureTitle: String
    let batteryTemperatureBodyFormat: String

    static let enUS = MonitorAlertFeatureStrings(
        section: "Alerts",
        caption: "Alerts fire when their selected limits are reached. CPU use and temperature alerts ignore spikes shorter than about 12 seconds. The repeat setting only limits repeats of the same alert.",
        notificationsDenied: "Notifications for Vorssaint are off in System Settings, so alerts cannot appear.",
        cpu: "High CPU",
        cpuTemperature: "High CPU temperature",
        memory: "Critical memory pressure",
        disk: "Low disk space",
        battery: "Low battery",
        cpuThreshold: "CPU above",
        cpuTemperatureThreshold: "Temperature above",
        diskThreshold: "Free space below",
        batteryThreshold: "Battery below",
        cooldown: "Repeat the same alert after",
        cooldown2: "2 minutes",
        cooldown5: "5 minutes",
        cooldown15: "15 minutes",
        cooldown30: "30 minutes",
        cooldown60: "1 hour",
        cpuTitle: "High CPU",
        cpuBodyFormat: "CPU stayed above %d%% for a few seconds.",
        cpuTemperatureTitle: "Hot CPU",
        cpuTemperatureBodyFormat: "CPU reached %@.",
        memoryTitle: "Critical memory",
        memoryBody: "Memory pressure reached the critical level.",
        diskTitle: "Low disk space",
        diskBodyFormat: "%@ has less than %d%% free.",
        batteryTitle: "Low battery",
        batteryBodyFormat: "Battery is at %d%%.",
        batteryTemperature: "High battery temperature",
        batteryTemperatureThreshold: "Temperature above",
        batteryTemperatureTitle: "Hot battery",
        batteryTemperatureBodyFormat: "Battery reached %@."
    )

    static let ptBR = MonitorAlertFeatureStrings(
        section: "Alertas",
        caption: "Os alertas disparam quando os limites escolhidos são atingidos. O uso da CPU e os alertas de temperatura ignoram picos com menos de 12 segundos. A opção de repetição só limita o mesmo alerta.",
        notificationsDenied: "As notificações do Vorssaint estão desativadas nos Ajustes do Sistema, então os alertas não aparecem.",
        cpu: "CPU alta",
        cpuTemperature: "Temperatura alta da CPU",
        memory: "Pressão de memória crítica",
        disk: "Pouco espaço em disco",
        battery: "Bateria baixa",
        cpuThreshold: "CPU acima de",
        cpuTemperatureThreshold: "Temperatura acima de",
        diskThreshold: "Espaço livre abaixo de",
        batteryThreshold: "Bateria abaixo de",
        cooldown: "Repetir o mesmo alerta depois de",
        cooldown2: "2 minutos",
        cooldown5: "5 minutos",
        cooldown15: "15 minutos",
        cooldown30: "30 minutos",
        cooldown60: "1 hora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "A CPU ficou acima de %d%% por alguns segundos.",
        cpuTemperatureTitle: "CPU quente",
        cpuTemperatureBodyFormat: "A CPU chegou a %@.",
        memoryTitle: "Memória crítica",
        memoryBody: "A pressão de memória chegou ao nível crítico.",
        diskTitle: "Pouco espaço em disco",
        diskBodyFormat: "%@ está com menos de %d%% livre.",
        batteryTitle: "Bateria baixa",
        batteryBodyFormat: "A bateria está em %d%%.",
        batteryTemperature: "Temperatura alta da bateria",
        batteryTemperatureThreshold: "Temperatura acima de",
        batteryTemperatureTitle: "Bateria quente",
        batteryTemperatureBodyFormat: "A bateria chegou a %@."
    )

    static let tr = MonitorAlertFeatureStrings(
        section: "Uyarılar",
        caption: "Uyarılar seçilen eşiklere ulaşıldığında gönderilir. CPU kullanımı ve sıcaklık uyarıları yaklaşık 12 saniyeden kısa sıçramaları yok sayar. Tekrarlama ayarı yalnızca aynı uyarının tekrarlanmasını sınırlar.",
        notificationsDenied: "Sistem Ayarları’nda Vorssaint bildirimleri kapalı, bu yüzden uyarılar görünemez.",
        cpu: "Yüksek CPU",
        cpuTemperature: "Yüksek CPU sıcaklığı",
        memory: "Kritik bellek basıncı",
        disk: "Düşük disk alanı",
        battery: "Düşük pil",
        cpuThreshold: "CPU şu değerin üstünde",
        cpuTemperatureThreshold: "Sıcaklık şu değerin üstünde",
        diskThreshold: "Boş alan şu değerin altında",
        batteryThreshold: "Pil şu değerin altında",
        cooldown: "Aynı uyarıyı şu süre sonra yinele",
        cooldown2: "2 dakika",
        cooldown5: "5 dakika",
        cooldown15: "15 dakika",
        cooldown30: "30 dakika",
        cooldown60: "1 saat",
        cpuTitle: "Yüksek CPU",
        cpuBodyFormat: "CPU birkaç saniye boyunca %d%% üzerinde kaldı.",
        cpuTemperatureTitle: "CPU sıcak",
        cpuTemperatureBodyFormat: "CPU %@ değerine ulaştı.",
        memoryTitle: "Kritik bellek",
        memoryBody: "Bellek basıncı kritik seviyeye ulaştı.",
        diskTitle: "Düşük disk alanı",
        diskBodyFormat: "%@ diskinde %d%% altında boş alan var.",
        batteryTitle: "Düşük pil",
        batteryBodyFormat: "Pil %d%% seviyesinde.",
        batteryTemperature: "Yüksek pil sıcaklığı",
        batteryTemperatureThreshold: "Sıcaklık şu değerin üstünde",
        batteryTemperatureTitle: "Pil sıcak",
        batteryTemperatureBodyFormat: "Pil %@ değerine ulaştı."
    )

    static let ru = MonitorAlertFeatureStrings(
        section: "Оповещения",
        caption: "Оповещения появляются при достижении выбранных порогов. Загрузка CPU и температурные оповещения игнорируют скачки короче примерно 12 секунд. Настройка повтора ограничивает только повтор одного и того же оповещения.",
        notificationsDenied: "Уведомления Vorssaint выключены в Системных настройках, поэтому оповещения не появятся.",
        cpu: "Высокая нагрузка CPU",
        cpuTemperature: "Высокая температура CPU",
        memory: "Критическое давление памяти",
        disk: "Мало места на диске",
        battery: "Низкий заряд батареи",
        cpuThreshold: "CPU выше",
        cpuTemperatureThreshold: "Температура выше",
        diskThreshold: "Свободного места меньше",
        batteryThreshold: "Батарея ниже",
        cooldown: "Повторить то же оповещение через",
        cooldown2: "2 минуты",
        cooldown5: "5 минут",
        cooldown15: "15 минут",
        cooldown30: "30 минут",
        cooldown60: "1 час",
        cpuTitle: "Высокая нагрузка CPU",
        cpuBodyFormat: "CPU держался выше %d%% несколько секунд.",
        cpuTemperatureTitle: "CPU перегрет",
        cpuTemperatureBodyFormat: "CPU достиг %@.",
        memoryTitle: "Критическая память",
        memoryBody: "Давление памяти достигло критического уровня.",
        diskTitle: "Мало места на диске",
        diskBodyFormat: "На %@ осталось меньше %d%% свободного места.",
        batteryTitle: "Низкий заряд батареи",
        batteryBodyFormat: "Заряд батареи: %d%%.",
        batteryTemperature: "Высокая температура батареи",
        batteryTemperatureThreshold: "Температура выше",
        batteryTemperatureTitle: "Батарея перегрета",
        batteryTemperatureBodyFormat: "Батарея достигла %@."
    )

    static let es = MonitorAlertFeatureStrings(
        section: "Alertas",
        caption: "Las alertas aparecen cuando se alcanzan los límites elegidos. El uso de CPU y las alertas de temperatura ignoran los picos de menos de unos 12 segundos. El ajuste de repetición solo limita la repetición de la misma alerta.",
        notificationsDenied: "Las notificaciones de Vorssaint están desactivadas en Ajustes del Sistema, así que las alertas no aparecen.",
        cpu: "CPU alta",
        cpuTemperature: "Temperatura de CPU alta",
        memory: "Presión de memoria crítica",
        disk: "Poco espacio en disco",
        battery: "Batería baja",
        cpuThreshold: "CPU por encima de",
        cpuTemperatureThreshold: "Temperatura por encima de",
        diskThreshold: "Espacio libre por debajo de",
        batteryThreshold: "Batería por debajo de",
        cooldown: "Repetir la misma alerta después de",
        cooldown2: "2 minutos",
        cooldown5: "5 minutos",
        cooldown15: "15 minutos",
        cooldown30: "30 minutos",
        cooldown60: "1 hora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "La CPU estuvo por encima de %d%% durante unos segundos.",
        cpuTemperatureTitle: "CPU caliente",
        cpuTemperatureBodyFormat: "La CPU llegó a %@.",
        memoryTitle: "Memoria crítica",
        memoryBody: "La presión de memoria llegó al nivel crítico.",
        diskTitle: "Poco espacio en disco",
        diskBodyFormat: "%@ tiene menos de %d%% libre.",
        batteryTitle: "Batería baja",
        batteryBodyFormat: "La batería está al %d%%.",
        batteryTemperature: "Temperatura de la batería alta",
        batteryTemperatureThreshold: "Temperatura por encima de",
        batteryTemperatureTitle: "Batería caliente",
        batteryTemperatureBodyFormat: "La batería llegó a %@."
    )

    static let sk = MonitorAlertFeatureStrings(
        section: "Hlásenia",
        caption: "Hlásenia sa spustia po dosiahnutí vybraných limitov. Hlásenia o vyťažení a teplote CPU ignorujú výkyvy kratšie ako približne 12 sekúnd. Nastavenie opakovania obmedzuje iba opakovanie toho istého hlásenia.",
        notificationsDenied: "Hlásenia pre Vorssaint sú vypnuté v Systémových nastaveniach, takže sa nemôžu zobraziť.",
        cpu: "Vysoké vyťaženie CPU",
        cpuTemperature: "Vysoká teplota CPU",
        memory: "Kritický tlak na pamäť",
        disk: "Málo miesta na disku",
        battery: "Nízka batéria",
        cpuThreshold: "CPU nad",
        cpuTemperatureThreshold: "Teplota nad",
        diskThreshold: "Voľné miesto pod",
        batteryThreshold: "Batéria pod",
        cooldown: "Zopakovať rovnaké hlásenie po",
        cooldown2: "2 minúty",
        cooldown5: "5 minút",
        cooldown15: "15 minút",
        cooldown30: "30 minút",
        cooldown60: "1 hodina",
        cpuTitle: "Vysoké vyťaženie CPU",
        cpuBodyFormat: "Využitie CPU bolo niekoľko sekúnd nad %d%%.",
        cpuTemperatureTitle: "Horúce CPU",
        cpuTemperatureBodyFormat: "CPU dosiahlo %@.",
        memoryTitle: "Kritická pamäť",
        memoryBody: "Tlak na pamäť dosiahol kritickú úroveň.",
        diskTitle: "Málo miesta na disku",
        diskBodyFormat: "%@ má menej ako %d%% voľného miesta.",
        batteryTitle: "Nízka batéria",
        batteryBodyFormat: "Batéria je na %d%%.",
        batteryTemperature: "Vysoká teplota batérie",
        batteryTemperatureThreshold: "Teplota nad",
        batteryTemperatureTitle: "Horúca batéria",
        batteryTemperatureBodyFormat: "Batéria dosiahla %@."
    )

    static let de = MonitorAlertFeatureStrings(
        section: "Warnungen",
        caption: "Warnungen erscheinen, wenn die gewählten Grenzwerte erreicht werden. CPU-Auslastung und Temperaturwarnungen ignorieren Spitzen, die kürzer als etwa 12 Sekunden dauern. Die Wiederholungseinstellung begrenzt nur die Wiederholung derselben Warnung.",
        notificationsDenied: "Mitteilungen für Vorssaint sind in den Systemeinstellungen aus, daher können keine Warnungen erscheinen.",
        cpu: "Hohe CPU",
        cpuTemperature: "Hohe CPU-Temperatur",
        memory: "Kritischer Speicherdruck",
        disk: "Wenig Speicherplatz",
        battery: "Niedriger Akkustand",
        cpuThreshold: "CPU über",
        cpuTemperatureThreshold: "Temperatur über",
        diskThreshold: "Freier Platz unter",
        batteryThreshold: "Akku unter",
        cooldown: "Dieselbe Warnung erneut nach",
        cooldown2: "2 Minuten",
        cooldown5: "5 Minuten",
        cooldown15: "15 Minuten",
        cooldown30: "30 Minuten",
        cooldown60: "1 Stunde",
        cpuTitle: "Hohe CPU",
        cpuBodyFormat: "Die CPU lag einige Sekunden über %d%%.",
        cpuTemperatureTitle: "Heiße CPU",
        cpuTemperatureBodyFormat: "Die CPU hat %@ erreicht.",
        memoryTitle: "Kritischer Speicher",
        memoryBody: "Der Speicherdruck hat den kritischen Wert erreicht.",
        diskTitle: "Wenig Speicherplatz",
        diskBodyFormat: "%@ hat weniger als %d%% frei.",
        batteryTitle: "Niedriger Akkustand",
        batteryBodyFormat: "Der Akku ist bei %d%%.",
        batteryTemperature: "Hohe Akkutemperatur",
        batteryTemperatureThreshold: "Temperatur über",
        batteryTemperatureTitle: "Heißer Akku",
        batteryTemperatureBodyFormat: "Der Akku hat %@ erreicht."
    )

    static let fr = MonitorAlertFeatureStrings(
        section: "Alertes",
        caption: "Les alertes apparaissent lorsque les seuils choisis sont atteints. L’utilisation du processeur et les alertes de température ignorent les pics de moins de 12 secondes environ. Le réglage de répétition limite uniquement la répétition de la même alerte.",
        notificationsDenied: "Les notifications de Vorssaint sont désactivées dans Réglages Système, les alertes ne peuvent donc pas apparaître.",
        cpu: "CPU élevé",
        cpuTemperature: "Température CPU élevée",
        memory: "Pression mémoire critique",
        disk: "Espace disque faible",
        battery: "Batterie faible",
        cpuThreshold: "CPU au-dessus de",
        cpuTemperatureThreshold: "Température au-dessus de",
        diskThreshold: "Espace libre sous",
        batteryThreshold: "Batterie sous",
        cooldown: "Répéter la même alerte après",
        cooldown2: "2 minutes",
        cooldown5: "5 minutes",
        cooldown15: "15 minutes",
        cooldown30: "30 minutes",
        cooldown60: "1 heure",
        cpuTitle: "CPU élevé",
        cpuBodyFormat: "Le CPU est resté au-dessus de %d%% pendant quelques secondes.",
        cpuTemperatureTitle: "CPU chaud",
        cpuTemperatureBodyFormat: "Le CPU a atteint %@.",
        memoryTitle: "Mémoire critique",
        memoryBody: "La pression mémoire a atteint le niveau critique.",
        diskTitle: "Espace disque faible",
        diskBodyFormat: "%@ a moins de %d%% libre.",
        batteryTitle: "Batterie faible",
        batteryBodyFormat: "La batterie est à %d%%.",
        batteryTemperature: "Température de la batterie élevée",
        batteryTemperatureThreshold: "Température au-dessus de",
        batteryTemperatureTitle: "Batterie chaude",
        batteryTemperatureBodyFormat: "La batterie a atteint %@."
    )

    static let it = MonitorAlertFeatureStrings(
        section: "Avvisi",
        caption: "Gli avvisi compaiono quando vengono raggiunte le soglie scelte. L’uso della CPU e gli avvisi di temperatura ignorano i picchi più brevi di circa 12 secondi. L’impostazione di ripetizione limita solo la ripetizione dello stesso avviso.",
        notificationsDenied: "Le notifiche di Vorssaint sono disattivate in Impostazioni di Sistema, quindi gli avvisi non compaiono.",
        cpu: "CPU alta",
        cpuTemperature: "Temperatura CPU alta",
        memory: "Pressione memoria critica",
        disk: "Poco spazio su disco",
        battery: "Batteria scarica",
        cpuThreshold: "CPU sopra",
        cpuTemperatureThreshold: "Temperatura sopra",
        diskThreshold: "Spazio libero sotto",
        batteryThreshold: "Batteria sotto",
        cooldown: "Ripeti lo stesso avviso dopo",
        cooldown2: "2 minuti",
        cooldown5: "5 minuti",
        cooldown15: "15 minuti",
        cooldown30: "30 minuti",
        cooldown60: "1 ora",
        cpuTitle: "CPU alta",
        cpuBodyFormat: "La CPU è rimasta sopra %d%% per alcuni secondi.",
        cpuTemperatureTitle: "CPU calda",
        cpuTemperatureBodyFormat: "La CPU ha raggiunto %@.",
        memoryTitle: "Memoria critica",
        memoryBody: "La pressione della memoria ha raggiunto il livello critico.",
        diskTitle: "Poco spazio su disco",
        diskBodyFormat: "%@ ha meno del %d%% libero.",
        batteryTitle: "Batteria scarica",
        batteryBodyFormat: "La batteria è al %d%%.",
        batteryTemperature: "Temperatura batteria alta",
        batteryTemperatureThreshold: "Temperatura sopra",
        batteryTemperatureTitle: "Batteria calda",
        batteryTemperatureBodyFormat: "La batteria ha raggiunto %@."
    )

    static let ja = MonitorAlertFeatureStrings(
        section: "アラート",
        caption: "選択したしきい値に達すると通知します。CPU 使用率と温度の通知は約 12 秒未満の短い急上昇を無視します。繰り返し設定は同じ通知の繰り返しだけを制限します。",
        notificationsDenied: "システム設定でVorssaintの通知がオフのため、アラートは表示されません。",
        cpu: "CPU 高負荷",
        cpuTemperature: "CPU 温度が高い",
        memory: "メモリ圧迫が深刻",
        disk: "ディスク空き容量不足",
        battery: "バッテリー残量低下",
        cpuThreshold: "CPU が次を超過",
        cpuTemperatureThreshold: "温度が次を超過",
        diskThreshold: "空き容量が次を下回る",
        batteryThreshold: "バッテリーが次を下回る",
        cooldown: "同じ通知を再度送るまで",
        cooldown2: "2 分",
        cooldown5: "5 分",
        cooldown15: "15 分",
        cooldown30: "30 分",
        cooldown60: "1 時間",
        cpuTitle: "CPU 高負荷",
        cpuBodyFormat: "CPU が数秒間 %d%% を超えました。",
        cpuTemperatureTitle: "CPU が高温",
        cpuTemperatureBodyFormat: "CPU が %@ に達しました。",
        memoryTitle: "メモリが深刻",
        memoryBody: "メモリ圧迫が深刻レベルに達しました。",
        diskTitle: "ディスク空き容量不足",
        diskBodyFormat: "%@ の空き容量が %d%% 未満です。",
        batteryTitle: "バッテリー残量低下",
        batteryBodyFormat: "バッテリー残量は %d%% です。",
        batteryTemperature: "バッテリー温度が高い",
        batteryTemperatureThreshold: "温度が次を超過",
        batteryTemperatureTitle: "バッテリーが高温",
        batteryTemperatureBodyFormat: "バッテリーが %@ に達しました。"
    )

    static let zhHans = MonitorAlertFeatureStrings(
        section: "提醒",
        caption: "达到所选阈值时会发出提醒。CPU 使用率和温度提醒会忽略短于约 12 秒的短暂峰值。重复设置仅限制同一提醒的重复频率。",
        notificationsDenied: "Vorssaint 的通知已在系统设置中关闭，警报无法显示。",
        cpu: "CPU 过高",
        cpuTemperature: "CPU 温度过高",
        memory: "内存压力严重",
        disk: "磁盘空间不足",
        battery: "电池电量低",
        cpuThreshold: "CPU 高于",
        cpuTemperatureThreshold: "温度高于",
        diskThreshold: "可用空间低于",
        batteryThreshold: "电量低于",
        cooldown: "再次发送同一提醒的间隔",
        cooldown2: "2 分钟",
        cooldown5: "5 分钟",
        cooldown15: "15 分钟",
        cooldown30: "30 分钟",
        cooldown60: "1 小时",
        cpuTitle: "CPU 过高",
        cpuBodyFormat: "CPU 已连续几秒高于 %d%%。",
        cpuTemperatureTitle: "CPU 过热",
        cpuTemperatureBodyFormat: "CPU 已达到 %@。",
        memoryTitle: "内存严重",
        memoryBody: "内存压力已达到严重级别。",
        diskTitle: "磁盘空间不足",
        diskBodyFormat: "%@ 的可用空间低于 %d%%。",
        batteryTitle: "电池电量低",
        batteryBodyFormat: "电池电量为 %d%%。",
        batteryTemperature: "电池温度过高",
        batteryTemperatureThreshold: "温度高于",
        batteryTemperatureTitle: "电池过热",
        batteryTemperatureBodyFormat: "电池已达到 %@。"
    )

    static let zhTW = MonitorAlertFeatureStrings(
        section: "提醒",
        caption: "達到所選門檻時會發出提醒。CPU 使用率和溫度提醒會忽略短於約 12 秒的短暫尖峰。重複設定只限制相同提醒的重複頻率。",
        notificationsDenied: "Vorssaint 的通知已在系統設定中關閉，警示無法顯示。",
        cpu: "CPU 使用率過高",
        cpuTemperature: "CPU 溫度過高",
        memory: "記憶體壓力過高",
        disk: "磁碟空間不足",
        battery: "電池電量偏低",
        cpuThreshold: "CPU 高於",
        cpuTemperatureThreshold: "溫度高於",
        diskThreshold: "可用空間低於",
        batteryThreshold: "電量低於",
        cooldown: "再次發送相同提醒的間隔",
        cooldown2: "2 分鐘",
        cooldown5: "5 分鐘",
        cooldown15: "15 分鐘",
        cooldown30: "30 分鐘",
        cooldown60: "1 小時",
        cpuTitle: "CPU 使用率過高",
        cpuBodyFormat: "CPU 已連續數秒高於 %d%%。",
        cpuTemperatureTitle: "CPU 過熱",
        cpuTemperatureBodyFormat: "CPU 已達到 %@。",
        memoryTitle: "記憶體壓力過高",
        memoryBody: "記憶體壓力已達到嚴重等級。",
        diskTitle: "磁碟空間不足",
        diskBodyFormat: "%@ 的可用空間低於 %d%%。",
        batteryTitle: "電池電量偏低",
        batteryBodyFormat: "電池電量為 %d%%。",
        batteryTemperature: "電池溫度過高",
        batteryTemperatureThreshold: "溫度高於",
        batteryTemperatureTitle: "電池過熱",
        batteryTemperatureBodyFormat: "電池已達到 %@。"
    )

    static let zhHK = MonitorAlertFeatureStrings(
        section: "提示",
        caption: "達到所選門檻時會發出提示。CPU 使用率和溫度提示會忽略短於約 12 秒的短暫尖峰。重複設定只限制相同提示的重複頻率。",
        notificationsDenied: "Vorssaint 的通知已在系統設定中關閉，警示無法顯示。",
        cpu: "CPU 使用率過高",
        cpuTemperature: "CPU 溫度過高",
        memory: "記憶體壓力過高",
        disk: "磁碟空間不足",
        battery: "電池電量偏低",
        cpuThreshold: "CPU 高於",
        cpuTemperatureThreshold: "溫度高於",
        diskThreshold: "可用空間低於",
        batteryThreshold: "電量低於",
        cooldown: "再次發出相同提示的間隔",
        cooldown2: "2 分鐘",
        cooldown5: "5 分鐘",
        cooldown15: "15 分鐘",
        cooldown30: "30 分鐘",
        cooldown60: "1 小時",
        cpuTitle: "CPU 使用率過高",
        cpuBodyFormat: "CPU 已連續數秒高於 %d%%。",
        cpuTemperatureTitle: "CPU 過熱",
        cpuTemperatureBodyFormat: "CPU 已達到 %@。",
        memoryTitle: "記憶體壓力過高",
        memoryBody: "記憶體壓力已達至嚴重水平。",
        diskTitle: "磁碟空間不足",
        diskBodyFormat: "%@ 的可用空間低於 %d%%。",
        batteryTitle: "電池電量偏低",
        batteryBodyFormat: "電池電量為 %d%%。",
        batteryTemperature: "電池溫度過高",
        batteryTemperatureThreshold: "溫度高於",
        batteryTemperatureTitle: "電池過熱",
        batteryTemperatureBodyFormat: "電池已達到 %@。"
    )
}


extension MonitorAlertFeatureStrings {
    static let ko = MonitorAlertFeatureStrings(
        section: "알림",
        caption: "선택한 기준에 도달하면 알림이 표시됩니다. CPU 사용량과 온도 알림은 기준을 약 12초 동안 계속 넘어야 하므로 짧은 급증은 무시됩니다. 반복 설정은 같은 알림의 반복만 제한합니다.",
        notificationsDenied: "시스템 설정에서 Vorssaint 알림이 꺼져 있어 경고를 표시할 수 없습니다.",
        cpu: "높은 CPU 사용량",
        cpuTemperature: "높은 CPU 온도",
        memory: "위험한 메모리 압력",
        disk: "부족한 디스크 공간",
        battery: "낮은 배터리",
        cpuThreshold: "CPU 사용량",
        cpuTemperatureThreshold: "온도",
        diskThreshold: "남은 공간",
        batteryThreshold: "배터리 잔량",
        cooldown: "같은 알림을 다시 보내기까지",
        cooldown2: "2분",
        cooldown5: "5분",
        cooldown15: "15분",
        cooldown30: "30분",
        cooldown60: "1시간",
        cpuTitle: "높은 CPU 사용량",
        cpuBodyFormat: "CPU 사용량이 몇 초 동안 %d%%를 넘었습니다.",
        cpuTemperatureTitle: "CPU 과열",
        cpuTemperatureBodyFormat: "CPU 온도가 %@에 도달했습니다.",
        memoryTitle: "위험한 메모리",
        memoryBody: "메모리 압력이 위험 수준에 도달했습니다.",
        diskTitle: "부족한 디스크 공간",
        diskBodyFormat: "%@의 여유 공간이 %d%% 미만입니다.",
        batteryTitle: "낮은 배터리",
        batteryBodyFormat: "배터리 잔량이 %d%%입니다.",
        batteryTemperature: "높은 배터리 온도",
        batteryTemperatureThreshold: "온도",
        batteryTemperatureTitle: "배터리 과열",
        batteryTemperatureBodyFormat: "배터리 온도가 %@에 도달했습니다."
    )
}


extension MonitorAlertFeatureStrings {
    static let uk = MonitorAlertFeatureStrings(
        section: "Сповіщення",
        caption: "Сповіщення спрацьовують, коли досягаються вибрані межі. Сповіщення про використання й температуру CPU ігнорують сплески коротші за 12 секунд. Налаштування повтору обмежує лише повтори того самого сповіщення.",
        notificationsDenied: "Сповіщення Vorssaint вимкнено в Системних параметрах, тому вони не можуть з’являтися.",
        cpu: "Високий CPU",
        cpuTemperature: "Висока температура CPU",
        memory: "Критичний тиск пам’яті",
        disk: "Мало місця на диску",
        battery: "Низький заряд акумулятора",
        cpuThreshold: "CPU вище",
        cpuTemperatureThreshold: "Температура вище",
        diskThreshold: "Вільного місця менше",
        batteryThreshold: "Заряд акумулятора нижче",
        cooldown: "Повторити те саме сповіщення через",
        cooldown2: "2 хвилини",
        cooldown5: "5 хвилин",
        cooldown15: "15 хвилин",
        cooldown30: "30 хвилин",
        cooldown60: "1 годину",
        cpuTitle: "Високий CPU",
        cpuBodyFormat: "CPU тримався вище %d%% кілька секунд.",
        cpuTemperatureTitle: "Гарячий CPU",
        cpuTemperatureBodyFormat: "CPU досяг %@.",
        memoryTitle: "Критична пам’ять",
        memoryBody: "Тиск пам’яті досяг критичного рівня.",
        diskTitle: "Мало місця на диску",
        diskBodyFormat: "На %@ залишилося менше %d%%.",
        batteryTitle: "Низький заряд акумулятора",
        batteryBodyFormat: "Заряд акумулятора становить %d%%.",
        batteryTemperature: "Висока температура акумулятора",
        batteryTemperatureThreshold: "Температура вище",
        batteryTemperatureTitle: "Гарячий акумулятор",
        batteryTemperatureBodyFormat: "Акумулятор нагрівся до %@."
    )
}

