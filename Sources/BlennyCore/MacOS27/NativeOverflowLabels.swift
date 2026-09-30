import Foundation

/// Exact MenuBarAgent labels observed in macOS 27.0.1 (26A434), covering all
/// 40 locale entries (37 distinct pairs) in MenuBarCore.loctable. No runtime
/// resource access or translated guesses. Unknown future labels fail closed.
enum MacOS27NativeOverflowLabels {
    private static let pairs: [(collapsed: String, expanded: String)] = [
        ("Afficher les éléments de la barre des menus", "Masquer les éléments de la barre des menus"),
        ("Afficher les éléments masqués de la barre des menus", "Masquer les éléments de la barre des menus"),
        ("Afișați articolele ascunse ale barei de meniu", "Ascundeți articolele barei de meniu"),
        ("Ausgeblendete Menüleistenobjekte einblenden", "Menüleistenobjekte ausblenden"),
        ("Elrejtett menüsorelemek megjelenítése", "Menüsor elemeinek elrejtése"),
        ("Gizli Menü Çubuğu Öğelerini Göster", "Menü Çubuğu Öğelerini Gizle"),
        ("Hiển thị các mục bị ẩn trên thanh menu", "Ẩn các mục trên thanh menu"),
        ("Mostra els ítems ocults de la barra de menús", "Oculta els ítems de la barra de menús"),
        ("Mostra gli elementi nascosti della barra dei menu", "Nascondi gli elementi della barra dei menu"),
        ("Mostrar Itens Ocultos da Barra de Menus", "Ocultar Itens da Barra de Menus"),
        ("Mostrar elementos ocultos da barra de menus", "Ocultar elementos da barra de menus"),
        ("Mostrar elementos ocultos de la barra de menús", "Ocultar elementos de la barra de menús"),
        ("Mostrar los ítems ocultos de la barra de menús", "Ocultar los ítems de la barra de menús"),
        ("Näytä kätketyt valikkorivin kohteet", "Kätke valikkorivin kohteet"),
        ("Pokaż ukryte elementy paska menu", "Ukryj elementy paska menu"),
        ("Prikaži skrite elemente menijske vrstice", "Skrij elemente menijske vrstice"),
        ("Prikaži skrivene stavke trake s izbornicima", "Sakrij stavke trake s izbornicima"),
        ("Show Hidden Menu Bar Items", "Hide Menu Bar Items"),
        ("Tampilkan Item Bar Menu Tersembunyi", "Sembunyikan Item Bar Menu"),
        ("Toon verborgen menubalkonderdelen", "Verberg menubalkonderdelen"),
        ("Tunjukkan Item Bar Menu Tersembunyi", "Sembunyikan Item Bar Menu"),
        ("Vis skjulte emner på menulinjen", "Skjul emner på menulinjen"),
        ("Vis skjulte objekter i menylinjen", "Skjul objekter i menylinjen"),
        ("Visa gömda menyradsobjekt", "Göm menyradsobjekt"),
        ("Zobrazit skryté položky v řádku nabídek", "Skrýt položky v řádku nabídek"),
        ("Zobraziť skryté položky v lište", "Skryť položky v lište"),
        ("Εμφάνιση κρυμμένων στοιχείων της γραμμής μενού", "Απόκρυψη στοιχείων της γραμμής μενού"),
        ("Показати приховані елементи смуги меню", "Сховати елементи смуги меню"),
        ("Показать скрытые элементы строки меню", "Скрыть элементы строки меню"),
        ("הצגת פריטים מוסתרים בשורת התפריטים", "הסתרת פריטים בשורת התפריטים"),
        ("إظهار عناصر شريط القوائم المخفية", "إخفاء عناصر شريط القوائم"),
        ("छिपे हुए मेन्यू बार आइटम दिखाएँ", "मेन्यू बार आइटम छिपाएँ"),
        ("แสดงรายการแถบเมนูที่ซ่อนอยู่", "ซ่อนรายการแถบเมนู"),
        ("显示隐藏菜单栏项目", "隐藏菜单栏项目"),
        ("非表示のメニューバー項目を表示", "メニューバー項目を非表示"),
        ("顯示隱藏的選單列項目", "隱藏選單列項目"),
        ("가려진 메뉴 막대 항목 보기", "메뉴 막대 항목 가리기")
    ]

    static let collapsed = Set(pairs.compactMap {
        MenuBarItemIdentityResolver.normalize($0.collapsed)
    })
    static let expanded = Set(pairs.compactMap {
        MenuBarItemIdentityResolver.normalize($0.expanded)
    })
}
