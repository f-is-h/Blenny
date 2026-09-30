// Independent resource-label fixture from macOS 27.0.1 build 26A434.
// MenuBarCore.loctable keys: menuBar.showOverflowItemsAccessibilityLabel and
// menuBar.hideOverflowItemsAccessibilityLabel. No Apple executable is included.
enum NativeOverflowLocaleFixture {
    struct Labels: Sendable {
        let locale: String
        let collapsed: String
        let expanded: String
    }

    static let all: [Labels] = [
        .init(locale: "ar", collapsed: "إظهار عناصر شريط القوائم المخفية", expanded: "إخفاء عناصر شريط القوائم"),
        .init(locale: "ca", collapsed: "Mostra els ítems ocults de la barra de menús", expanded: "Oculta els ítems de la barra de menús"),
        .init(locale: "cs", collapsed: "Zobrazit skryté položky v řádku nabídek", expanded: "Skrýt položky v řádku nabídek"),
        .init(locale: "da", collapsed: "Vis skjulte emner på menulinjen", expanded: "Skjul emner på menulinjen"),
        .init(locale: "de", collapsed: "Ausgeblendete Menüleistenobjekte einblenden", expanded: "Menüleistenobjekte ausblenden"),
        .init(locale: "el", collapsed: "Εμφάνιση κρυμμένων στοιχείων της γραμμής μενού", expanded: "Απόκρυψη στοιχείων της γραμμής μενού"),
        .init(locale: "en", collapsed: "Show Hidden Menu Bar Items", expanded: "Hide Menu Bar Items"),
        .init(locale: "en_AU", collapsed: "Show Hidden Menu Bar Items", expanded: "Hide Menu Bar Items"),
        .init(locale: "en_GB", collapsed: "Show Hidden Menu Bar Items", expanded: "Hide Menu Bar Items"),
        .init(locale: "es", collapsed: "Mostrar los ítems ocultos de la barra de menús", expanded: "Ocultar los ítems de la barra de menús"),
        .init(locale: "es_419", collapsed: "Mostrar elementos ocultos de la barra de menús", expanded: "Ocultar elementos de la barra de menús"),
        .init(locale: "fi", collapsed: "Näytä kätketyt valikkorivin kohteet", expanded: "Kätke valikkorivin kohteet"),
        .init(locale: "fr", collapsed: "Afficher les éléments masqués de la barre des menus", expanded: "Masquer les éléments de la barre des menus"),
        .init(locale: "fr_CA", collapsed: "Afficher les éléments de la barre des menus", expanded: "Masquer les éléments de la barre des menus"),
        .init(locale: "he", collapsed: "הצגת פריטים מוסתרים בשורת התפריטים", expanded: "הסתרת פריטים בשורת התפריטים"),
        .init(locale: "hi", collapsed: "छिपे हुए मेन्यू बार आइटम दिखाएँ", expanded: "मेन्यू बार आइटम छिपाएँ"),
        .init(locale: "hr", collapsed: "Prikaži skrivene stavke trake s izbornicima", expanded: "Sakrij stavke trake s izbornicima"),
        .init(locale: "hu", collapsed: "Elrejtett menüsorelemek megjelenítése", expanded: "Menüsor elemeinek elrejtése"),
        .init(locale: "id", collapsed: "Tampilkan Item Bar Menu Tersembunyi", expanded: "Sembunyikan Item Bar Menu"),
        .init(locale: "it", collapsed: "Mostra gli elementi nascosti della barra dei menu", expanded: "Nascondi gli elementi della barra dei menu"),
        .init(locale: "ja", collapsed: "非表示のメニューバー項目を表示", expanded: "メニューバー項目を非表示"),
        .init(locale: "ko", collapsed: "가려진 메뉴 막대 항목 보기", expanded: "메뉴 막대 항목 가리기"),
        .init(locale: "ms", collapsed: "Tunjukkan Item Bar Menu Tersembunyi", expanded: "Sembunyikan Item Bar Menu"),
        .init(locale: "nl", collapsed: "Toon verborgen menubalkonderdelen", expanded: "Verberg menubalkonderdelen"),
        .init(locale: "no", collapsed: "Vis skjulte objekter i menylinjen", expanded: "Skjul objekter i menylinjen"),
        .init(locale: "pl", collapsed: "Pokaż ukryte elementy paska menu", expanded: "Ukryj elementy paska menu"),
        .init(locale: "pt_BR", collapsed: "Mostrar Itens Ocultos da Barra de Menus", expanded: "Ocultar Itens da Barra de Menus"),
        .init(locale: "pt_PT", collapsed: "Mostrar elementos ocultos da barra de menus", expanded: "Ocultar elementos da barra de menus"),
        .init(locale: "ro", collapsed: "Afișați articolele ascunse ale barei de meniu", expanded: "Ascundeți articolele barei de meniu"),
        .init(locale: "ru", collapsed: "Показать скрытые элементы строки меню", expanded: "Скрыть элементы строки меню"),
        .init(locale: "sk", collapsed: "Zobraziť skryté položky v lište", expanded: "Skryť položky v lište"),
        .init(locale: "sl", collapsed: "Prikaži skrite elemente menijske vrstice", expanded: "Skrij elemente menijske vrstice"),
        .init(locale: "sv", collapsed: "Visa gömda menyradsobjekt", expanded: "Göm menyradsobjekt"),
        .init(locale: "th", collapsed: "แสดงรายการแถบเมนูที่ซ่อนอยู่", expanded: "ซ่อนรายการแถบเมนู"),
        .init(locale: "tr", collapsed: "Gizli Menü Çubuğu Öğelerini Göster", expanded: "Menü Çubuğu Öğelerini Gizle"),
        .init(locale: "uk", collapsed: "Показати приховані елементи смуги меню", expanded: "Сховати елементи смуги меню"),
        .init(locale: "vi", collapsed: "Hiển thị các mục bị ẩn trên thanh menu", expanded: "Ẩn các mục trên thanh menu"),
        .init(locale: "zh_CN", collapsed: "显示隐藏菜单栏项目", expanded: "隐藏菜单栏项目"),
        .init(locale: "zh_HK", collapsed: "顯示隱藏的選單列項目", expanded: "隱藏選單列項目"),
        .init(locale: "zh_TW", collapsed: "顯示隱藏的選單列項目", expanded: "隱藏選單列項目")
    ]
}
