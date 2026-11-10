"""Generates App/Resources/Localizable.xcstrings (English source, Arabic translations).

Run from the repository root:  python tools/build_strings.py
Add a line to AR whenever a user-facing English string is added to the Swift code.
`python tools/check_strings.py` verifies that every string used in code has an entry here.
"""
import json
import pathlib

AR = {
    # App shell
    "Storage unavailable": "التخزين غير متاح",
    "The notes library could not be opened on this device.": "تعذّر فتح مكتبة الملاحظات على هذا الجهاز.",
    "Library": "المكتبة",
    "All Notes": "كل الملاحظات",
    "Recents": "الأخيرة",
    "Favorites": "المفضلة",
    "Trash": "سلة المحذوفات",
    "Folders": "المجلدات",
    "Workspace": "مساحة العمل",
    "Study": "الدراسة",
    "Atlas": "الأطلس",
    "Community": "المجتمع",
    "Settings": "الإعدادات",
    "Not available in this build.": "غير متاح في هذه النسخة.",
    "Planned for milestone %@.": "مخطط له في المرحلة %@.",
    "Flashcards, quizzes, focus timer, scientific calculators and the periodic table will live here.":
        "ستكون هنا البطاقات التعليمية والاختبارات ومؤقت التركيز والآلات الحاسبة العلمية والجدول الدوري.",
    "The interactive anatomy atlas starts with a heart module. It needs reviewed 3D assets that do not exist yet.":
        "يبدأ أطلس التشريح التفاعلي بوحدة القلب، ويحتاج إلى نماذج ثلاثية الأبعاد مُراجَعة غير متوفرة بعد.",
    "Opt-in sharing stays disabled until reporting, blocking and moderation services exist.":
        "تبقى المشاركة الاختيارية معطّلة إلى أن تتوفر خدمات الإبلاغ والحظر والإشراف.",
    # Folders
    "New Folder": "مجلد جديد",
    "New Subfolder": "مجلد فرعي جديد",
    "Rename Folder": "إعادة تسمية المجلد",
    "Rename": "إعادة تسمية",
    "Delete Folder": "حذف المجلد",
    "Delete this folder?": "حذف هذا المجلد؟",
    "Subfolders are removed. Notes inside are kept and moved to All Notes.":
        "تُحذف المجلدات الفرعية، وتبقى الملاحظات وتُنقل إلى «كل الملاحظات».",
    # Shared
    "Name": "الاسم",
    "Save": "حفظ",
    "Cancel": "إلغاء",
    "OK": "موافق",
    "Something went wrong": "حدث خطأ",
    # Templates
    "Blank": "فارغ",
    "Ruled": "مسطّر",
    "Grid": "مربعات",
    "Dot Grid": "نقاط",
    "Cornell": "كورنيل",
    # Library
    "Search titles": "ابحث في العناوين",
    "Delete permanently?": "حذف نهائي؟",
    "Delete Permanently": "حذف نهائي",
    "This notebook and its handwriting will be removed from this device. This cannot be undone.":
        "سيُحذف هذا الدفتر وما فيه من كتابة من هذا الجهاز. لا يمكن التراجع عن ذلك.",
    "Empty the trash?": "إفراغ سلة المحذوفات؟",
    "Empty Trash": "إفراغ السلة",
    "All notebooks in the trash will be removed from this device. This cannot be undone.":
        "ستُحذف كل الدفاتر الموجودة في السلة من هذا الجهاز. لا يمكن التراجع عن ذلك.",
    "Trash is empty": "السلة فارغة",
    "Notebooks you delete stay here until you remove them permanently.":
        "تبقى الدفاتر المحذوفة هنا إلى أن تحذفها نهائيًا.",
    "No favorites yet": "لا توجد مفضلات بعد",
    "Touch and hold a notebook and choose Favorite.": "اضغط مطولًا على دفتر واختر «مفضلة».",
    "Nothing opened yet": "لم يُفتح شيء بعد",
    "Notebooks you open will appear here.": "ستظهر هنا الدفاتر التي تفتحها.",
    "No notebooks here": "لا توجد دفاتر هنا",
    "Create a notebook or import a PDF to start writing.": "أنشئ دفترًا أو استورد ملف PDF لتبدأ الكتابة.",
    "New Notebook": "دفتر جديد",
    "Import PDF": "استيراد PDF",
    "Import": "استيراد",
    "Sort by": "ترتيب حسب",
    "Date Modified": "تاريخ التعديل",
    "Date Created": "تاريخ الإنشاء",
    "Title": "العنوان",
    "Restore": "استعادة",
    "Open": "فتح",
    "Rename Notebook": "إعادة تسمية الدفتر",
    "Remove Favorite": "إزالة من المفضلة",
    "Favorite": "مفضلة",
    "Duplicate": "تكرار",
    "All Notes (no folder)": "كل الملاحظات (بلا مجلد)",
    "Move to": "نقل إلى",
    "Move to Trash": "نقل إلى السلة",
    "%lld pages": "%lld صفحة",
    "Untitled notebook": "دفتر بلا عنوان",
    "Importing…": "جارٍ الاستيراد…",
    "Duplicating…": "جارٍ التكرار…",
    "copy": "نسخة",
    # Import errors
    "This file could not be read as a PDF.": "تعذّرت قراءة هذا الملف كملف PDF.",
    "Password-protected PDFs are not supported yet.": "ملفات PDF المحمية بكلمة مرور غير مدعومة بعد.",
    "This PDF has no pages.": "هذا الملف لا يحتوي على صفحات.",
    "This file is not a valid notebook package.": "هذا الملف ليس حزمة دفتر صالحة.",
    # Settings
    "Draw with finger": "الرسم بالإصبع",
    "Writing": "الكتابة",
    "When off, only Apple Pencil draws and one finger scrolls. When on, one finger draws and two fingers scroll.":
        "عند الإيقاف يرسم قلم Apple Pencil فقط ويُمرَّر بإصبع واحد. عند التشغيل يرسم إصبع واحد ويُمرَّر بإصبعين.",
    "New notebooks": "الدفاتر الجديدة",
    "Default template": "القالب الافتراضي",
    "Version": "الإصدار",
    "Document format": "تنسيق المستند",
    "About": "حول",
    "Notes are stored only on this device in this build. Sync, AI features, subscriptions and the atlas are not implemented yet.":
        "تُحفظ الملاحظات على هذا الجهاز فقط في هذه النسخة. المزامنة وميزات الذكاء الاصطناعي والاشتراكات والأطلس غير منفَّذة بعد.",
    # Tools
    "Pen": "قلم حبر",
    "Pencil": "قلم رصاص",
    "Highlighter": "قلم تظليل",
    "Eraser": "ممحاة",
    "Lasso": "تحديد حر",
    "Undo": "تراجع",
    "Redo": "إعادة",
    "Color": "لون",
    "Custom color": "لون مخصص",
    "Thickness": "السماكة",
    "Eraser mode": "وضع الممحاة",
    "Whole stroke": "الخط كاملًا",
    "Partial": "جزئي",
    "Circle strokes to select them, then drag to move.": "ارسم دائرة حول الخطوط لتحديدها ثم اسحب لتحريكها.",
    # Editor
    "This notebook could not be opened": "تعذّر فتح هذا الدفتر",
    "Back to Library": "العودة إلى المكتبة",
    "Exporting…": "جارٍ التصدير…",
    "Delete this page?": "حذف هذه الصفحة؟",
    "Delete Page": "حذف الصفحة",
    "The page and its handwriting will be removed. This cannot be undone, and it clears the undo history.":
        "ستُحذف الصفحة وما فيها من كتابة. لا يمكن التراجع عن ذلك، وسيُمسح سجل التراجع.",
    "Page thumbnails": "مصغّرات الصفحات",
    "Page %lld of %lld": "صفحة %1$lld من %2$lld",
    "Page %lld": "صفحة %lld",
    "Add Page": "إضافة صفحة",
    "Page actions": "إجراءات الصفحة",
    "PDF with annotations (flattened)": "PDF مع التعليقات (مسطّح)",
    "Editable notebook package": "حزمة دفتر قابلة للتعديل",
    "Export": "تصدير",
    "Change Template": "تغيير القالب",
    "Remove Bookmark": "إزالة الإشارة المرجعية",
    "Bookmark Page": "إشارة مرجعية للصفحة",
    "Duplicate Page": "تكرار الصفحة",
    "Your latest strokes could not be saved.": "تعذّر حفظ آخر ما كتبته.",
    "The handwriting on one page could not be read. That page is shown read-only to protect the saved file.":
        "تعذّرت قراءة الكتابة في إحدى الصفحات. تُعرض تلك الصفحة للقراءة فقط حمايةً للملف المحفوظ.",
    "The notebook could not be saved.": "تعذّر حفظ الدفتر.",
}


def build() -> dict:
    strings = {}
    for key, value in sorted(AR.items()):
        strings[key] = {
            "localizations": {
                "ar": {"stringUnit": {"state": "translated", "value": value}}
            }
        }
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


if __name__ == "__main__":
    out = pathlib.Path(__file__).resolve().parent.parent / "App" / "Resources" / "Localizable.xcstrings"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(AR)} strings to {out}")
