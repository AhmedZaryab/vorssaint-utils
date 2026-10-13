// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The one-line description under a redesigned Settings page's title, for
/// pages whose own string catalog has no room for it.
struct SettingsPageStrings {
    let energyDescription: String
    let mouseDescription: String
    let switcherDescription: String
    let dockTitle: String
    let dockDescription: String
    let switcherLayoutWindows: String
    let switcherLayoutWindowsCaption: String
    let switcherLayoutIcons: String
    let switcherLayoutSimple: String
}

extension FeatureStrings {
    static func settingsPages(_ language: AppLanguage) -> SettingsPageStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension SettingsPageStrings {
    static let uk = SettingsPageStrings(
        energyDescription: "Не давайте Mac заснути, керуйте екранами та заощаджуйте заряд акумулятора.",
        mouseDescription: "Дайте колесу, боковим кнопкам і трекпеду нові функції.",
        switcherDescription: "Перемикайте програми й вікна на свій лад.",
        dockTitle: "Dock",
        dockDescription: "Переглядайте вікна програми з її значка в Dock і вибирайте, що робить клацання по ньому.",
        switcherLayoutWindows: "Мініатюри вікон",
        switcherLayoutWindowsCaption: "По одній мініатюрі для кожного вікна, включно зі згорнутими.",
        switcherLayoutIcons: "Великі значки",
        switcherLayoutSimple: "Простий список"
    )

    static let enUS = SettingsPageStrings(
        energyDescription: "Keep the Mac awake, control your displays and save battery.",
        mouseDescription: "Give the wheel, the side buttons and the trackpad new jobs.",
        switcherDescription: "Switch between apps and windows your way.",
        dockTitle: "Dock",
        dockDescription: "See an app’s windows from its Dock icon, and choose what a click on it does.",
        switcherLayoutWindows: "Window previews",
        switcherLayoutWindowsCaption: "One preview per window, minimized ones included.",
        switcherLayoutIcons: "Large icons",
        switcherLayoutSimple: "Simple list"
    )

    static let ptBR = SettingsPageStrings(
        energyDescription: "Mantenha o Mac acordado, controle suas telas e economize bateria.",
        mouseDescription: "Dê novas funções à rodinha, aos botões laterais e ao trackpad.",
        switcherDescription: "Troque de app e de janela do seu jeito.",
        dockTitle: "Dock",
        dockDescription: "Veja as janelas de um app pelo ícone no Dock e escolha o que um clique nele faz.",
        switcherLayoutWindows: "Previews das janelas",
        switcherLayoutWindowsCaption: "Um preview por janela, incluindo as minimizadas.",
        switcherLayoutIcons: "Ícones grandes",
        switcherLayoutSimple: "Lista simples"
    )

    static let tr = SettingsPageStrings(
        energyDescription: "Mac’i uyanık tutun, ekranlarınızı yönetin ve pil tasarrufu yapın.",
        mouseDescription: "Tekerleğe, yan tuşlara ve izleme dörtgenine yeni görevler verin.",
        switcherDescription: "Uygulamalar ve pencereler arasında kendi tarzınızda geçin.",
        dockTitle: "Dock",
        dockDescription: "Bir uygulamanın pencerelerini Dock simgesinden görün ve simgeye tıklamanın ne yapacağını seçin.",
        switcherLayoutWindows: "Pencere önizlemeleri",
        switcherLayoutWindowsCaption: "Her pencere için bir önizleme, simge durumundakiler dahil.",
        switcherLayoutIcons: "Büyük simgeler",
        switcherLayoutSimple: "Basit liste"
    )

    static let ru = SettingsPageStrings(
        energyDescription: "Не давайте Mac уснуть, управляйте экранами и берегите батарею.",
        mouseDescription: "Дайте колёсику, боковым кнопкам и трекпаду новые задачи.",
        switcherDescription: "Переключайтесь между приложениями и окнами по-своему.",
        dockTitle: "Dock",
        dockDescription: "Смотрите окна приложения по его значку в Dock и выбирайте, что делает щелчок по нему.",
        switcherLayoutWindows: "Миниатюры окон",
        switcherLayoutWindowsCaption: "По миниатюре на каждое окно, включая свёрнутые.",
        switcherLayoutIcons: "Крупные значки",
        switcherLayoutSimple: "Простой список"
    )

    static let es = SettingsPageStrings(
        energyDescription: "Mantén el Mac despierto, controla tus pantallas y ahorra batería.",
        mouseDescription: "Dale nuevas funciones a la rueda, a los botones laterales y al trackpad.",
        switcherDescription: "Cambia de app y de ventana a tu manera.",
        dockTitle: "Dock",
        dockDescription: "Mira las ventanas de una app desde su icono en el Dock y elige qué hace un clic en él.",
        switcherLayoutWindows: "Vistas previas de ventanas",
        switcherLayoutWindowsCaption: "Una vista previa por ventana, incluidas las minimizadas.",
        switcherLayoutIcons: "Iconos grandes",
        switcherLayoutSimple: "Lista simple"
    )

    static let sk = SettingsPageStrings(
        energyDescription: "Udržujte Mac v bdelom stave, ovládajte svoje displeje a šetrite batériu.",
        mouseDescription: "Priraďte koliesku, bočným tlačidlám a trackpadu nové úlohy.",
        switcherDescription: "Prepínajte medzi aplikáciami a oknami po svojom.",
        dockTitle: "Dock",
        dockDescription: "Zobrazte okná aplikácie z jej ikony v Docku a vyberte, čo urobí kliknutie na ňu.",
        switcherLayoutWindows: "Náhľady okien",
        switcherLayoutWindowsCaption: "Jeden náhľad na okno, vrátane minimalizovaných.",
        switcherLayoutIcons: "Veľké ikony",
        switcherLayoutSimple: "Jednoduchý zoznam"
    )

    static let de = SettingsPageStrings(
        energyDescription: "Halte den Mac wach, steuere deine Bildschirme und spare Batterie.",
        mouseDescription: "Gib dem Scrollrad, den Seitentasten und dem Trackpad neue Aufgaben.",
        switcherDescription: "Wechsle auf deine Art zwischen Apps und Fenstern.",
        dockTitle: "Dock",
        dockDescription: "Sieh die Fenster einer App über ihr Dock-Symbol und lege fest, was ein Klick darauf bewirkt.",
        switcherLayoutWindows: "Fenstervorschauen",
        switcherLayoutWindowsCaption: "Eine Vorschau pro Fenster, auch für minimierte.",
        switcherLayoutIcons: "Große Symbole",
        switcherLayoutSimple: "Einfache Liste"
    )

    static let fr = SettingsPageStrings(
        energyDescription: "Gardez le Mac éveillé, réglez vos écrans et économisez la batterie.",
        mouseDescription: "Donnez de nouveaux rôles à la molette, aux boutons latéraux et au trackpad.",
        switcherDescription: "Passez d’une app ou d’une fenêtre à l’autre à votre façon.",
        dockTitle: "Dock",
        dockDescription: "Voyez les fenêtres d’une app depuis son icône dans le Dock et choisissez l’effet d’un clic dessus.",
        switcherLayoutWindows: "Aperçus des fenêtres",
        switcherLayoutWindowsCaption: "Un aperçu par fenêtre, fenêtres réduites comprises.",
        switcherLayoutIcons: "Grandes icônes",
        switcherLayoutSimple: "Liste simple"
    )

    static let it = SettingsPageStrings(
        energyDescription: "Tieni il Mac sveglio, controlla i tuoi schermi e risparmia batteria.",
        mouseDescription: "Assegna nuovi compiti alla rotellina, ai tasti laterali e al trackpad.",
        switcherDescription: "Passa da un’app o una finestra all’altra a modo tuo.",
        dockTitle: "Dock",
        dockDescription: "Guarda le finestre di un’app dalla sua icona nel Dock e scegli cosa fa un clic su di essa.",
        switcherLayoutWindows: "Anteprime delle finestre",
        switcherLayoutWindowsCaption: "Un’anteprima per finestra, comprese quelle contratte.",
        switcherLayoutIcons: "Icone grandi",
        switcherLayoutSimple: "Elenco semplice"
    )

    static let ja = SettingsPageStrings(
        energyDescription: "Mac をスリープさせず、ディスプレイを調整し、バッテリーを節約します。",
        mouseDescription: "ホイール、サイドボタン、トラックパッドに新しい役割を。",
        switcherDescription: "アプリやウインドウを自分のやり方で切り替え。",
        dockTitle: "Dock",
        dockDescription: "Dock のアイコンからアプリのウインドウを確認し、クリックしたときの動作を選べます。",
        switcherLayoutWindows: "ウインドウのプレビュー",
        switcherLayoutWindowsCaption: "ウインドウごとにプレビューを表示。しまったウインドウも含みます。",
        switcherLayoutIcons: "大きなアイコン",
        switcherLayoutSimple: "シンプルなリスト"
    )

    static let ko = SettingsPageStrings(
        energyDescription: "Mac을 깨어 있게 하고, 화면을 조절하고, 배터리를 아끼세요.",
        mouseDescription: "휠, 사이드 버튼, 트랙패드에 새 역할을 맡기세요.",
        switcherDescription: "나만의 방식으로 앱과 윈도우를 전환하세요.",
        dockTitle: "Dock",
        dockDescription: "Dock 아이콘에서 앱의 윈도우를 확인하고, 아이콘을 클릭했을 때의 동작을 고르세요.",
        switcherLayoutWindows: "윈도우 미리보기",
        switcherLayoutWindowsCaption: "윈도우마다 미리보기 하나, 축소된 윈도우도 포함합니다.",
        switcherLayoutIcons: "큰 아이콘",
        switcherLayoutSimple: "간단한 목록"
    )

    static let zhHans = SettingsPageStrings(
        energyDescription: "让 Mac 保持唤醒、调节显示器并节省电量。",
        mouseDescription: "让滚轮、侧键和触控板承担新的任务。",
        switcherDescription: "按你的方式切换 App 和窗口。",
        dockTitle: "程序坞",
        dockDescription: "从程序坞图标查看 App 的窗口，并选择点按图标时的操作。",
        switcherLayoutWindows: "窗口预览",
        switcherLayoutWindowsCaption: "每个窗口一张预览，包括已最小化的窗口。",
        switcherLayoutIcons: "大图标",
        switcherLayoutSimple: "简单列表"
    )

    static let zhTW = SettingsPageStrings(
        energyDescription: "讓 Mac 保持喚醒、調整顯示器並節省電量。",
        mouseDescription: "讓滾輪、側鍵和觸控板承擔新的任務。",
        switcherDescription: "用你的方式切換 App 和視窗。",
        dockTitle: "Dock",
        dockDescription: "從 Dock 圖示查看 App 的視窗，並選擇點按圖示時的動作。",
        switcherLayoutWindows: "視窗預覽",
        switcherLayoutWindowsCaption: "每個視窗一張預覽，包括已縮到最小的視窗。",
        switcherLayoutIcons: "大圖示",
        switcherLayoutSimple: "簡單列表"
    )

    static let zhHK = SettingsPageStrings(
        energyDescription: "讓 Mac 保持喚醒、調整顯示器並節省電量。",
        mouseDescription: "讓滾輪、側鍵和觸控板承擔新的任務。",
        switcherDescription: "用你的方式切換 App 和視窗。",
        dockTitle: "Dock",
        dockDescription: "從 Dock 圖示查看 App 的視窗，並選擇點按圖示時的動作。",
        switcherLayoutWindows: "視窗預覽",
        switcherLayoutWindowsCaption: "每個視窗一張預覽，包括已縮到最小的視窗。",
        switcherLayoutIcons: "大圖示",
        switcherLayoutSimple: "簡單列表"
    )
}
