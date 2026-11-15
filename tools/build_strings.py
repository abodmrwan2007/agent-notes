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
    # Study tools panel
    "Scientific Calculator": "الآلة الحاسبة العلمية",
    "Graphing Calculator": "راسم الدوال",
    "Periodic Table": "الجدول الدوري",
    "Focus Timer": "مؤقت التركيز",
    "Trigonometry, logarithms, powers and factorials, computed on this device.":
        "دوال مثلثية ولوغاريتمات وقوى ومضروب، تُحسب على هذا الجهاز.",
    "Plot up to three functions of x. Drag to move, pinch to zoom.":
        "ارسم حتى ثلاث دوال في x. اسحب للتحريك وقرّب بإصبعين.",
    "All 118 elements with symbols, masses and groups.": "العناصر الـ118 كلها مع الرموز والكتل والمجموعات.",
    "Work and break sessions that keep counting in the background.":
        "جلسات عمل واستراحة يستمر عدّها في الخلفية.",
    "Step-by-step Math Solver": "حل المسائل خطوة بخطوة",
    "Needs a symbolic engine or a verified AI explanation.": "يحتاج إلى محرك رمزي أو شرح بالذكاء الاصطناعي مُتحقَّق منه.",
    "Handwriting Calculator": "آلة حاسبة بخط اليد",
    "Needs handwriting recognition, which is not chosen yet.": "تحتاج إلى التعرّف على خط اليد، ولم يُختر مزوّده بعد.",
    "Translation Tool": "أداة الترجمة",
    "Needs a translation provider.": "تحتاج إلى مزوّد ترجمة.",
    "Study Games": "ألعاب دراسية",
    "Needs reviewed study content.": "تحتاج إلى محتوى دراسي مُراجَع.",
    "Tools": "الأدوات",
    "Removed": "المُزالة",
    "Add Back": "إعادة",
    "Not available yet": "غير متاحة بعد",
    "Remove from Panel": "إزالة من اللوحة",
    "Favorites Only": "المفضلة فقط",
    "No favorite tools yet. Swipe a tool to the right to add it.":
        "لا توجد أدوات مفضلة بعد. اسحب أداة إلى اليمين لإضافتها.",
    "All tools were removed. Add them back below.": "أُزيلت كل الأدوات. أعدها من الأسفل.",
    # Calculator
    "Enter an expression.": "أدخل عبارة حسابية.",
    "This character is not understood: %@": "رمز غير مفهوم: %@",
    "The expression is incomplete.": "العبارة غير مكتملة.",
    "Unexpected symbol: %@": "رمز في غير موضعه: %@",
    "A closing parenthesis is missing.": "ينقص قوس إغلاق.",
    "Unknown name: %@": "اسم غير معروف: %@",
    "Wrong number of values for %@.": "عدد القيم غير صحيح للدالة %@.",
    "Division by zero.": "قسمة على صفر.",
    "Not defined for this value: %@": "غير معرّفة عند هذه القيمة: %@",
    "The result is too large.": "الناتج أكبر من أن يُعرض.",
    "Angle unit": "وحدة الزاوية",
    "Degrees": "درجات",
    "Radians": "راديان",
    "Expression": "العبارة",
    "History": "السجل",
    "Results you calculate appear here.": "تظهر هنا النتائج التي تحسبها.",
    # Graph
    "Function of x": "دالة في x",
    "Functions": "الدوال",
    "Use x as the variable, for example x^2, 1/x or 2sin(x). Angles are in radians.":
        "استخدم x متغيرًا، مثل x^2 أو 1/x أو 2sin(x). الزوايا بالراديان.",
    "View": "العرض",
    "Zoom In": "تكبير",
    "Zoom Out": "تصغير",
    "Reset View": "إعادة ضبط العرض",
    "Graph": "الرسم البياني",
    # Periodic table
    "Alkali metal": "فلز قلوي",
    "Alkaline earth metal": "فلز قلوي ترابي",
    "Transition metal": "فلز انتقالي",
    "Post-transition metal": "فلز بعد انتقالي",
    "Metalloid": "شبه فلز",
    "Nonmetal": "لافلز",
    "Halogen": "هالوجين",
    "Noble gas": "غاز نبيل",
    "Lanthanide": "لانثانيد",
    "Actinide": "أكتينيد",
    "Development data set. It has not yet been validated against IUPAC values and must not be used as a reference.":
        "بيانات تطويرية لم تُدقَّق بعد مقابل قيم IUPAC، ولا يجوز اعتمادها مرجعًا.",
    "Name, symbol or number": "الاسم أو الرمز أو الرقم",
    "Atomic number": "العدد الذري",
    "Symbol": "الرمز",
    "Atomic mass": "الكتلة الذرية",
    "Period": "الدورة",
    "Group": "المجموعة",
    "Category": "التصنيف",
    "Brackets show the mass number of a long-lived isotope; this element has no standard atomic weight.":
        "القوسان يبيّنان العدد الكتلي لنظير طويل العمر؛ ليس لهذا العنصر وزن ذري قياسي.",
    "Done": "تم",
    # Focus timer
    "Focus": "تركيز",
    "Break": "استراحة",
    "Pause": "إيقاف مؤقت",
    "Start": "ابدأ",
    "Resume": "متابعة",
    "Reset": "إعادة ضبط",
    "Completed focus sessions: %lld": "جلسات التركيز المكتملة: %lld",
    "Focus: %lld min": "التركيز: %lld دقيقة",
    "Break: %lld min": "الاستراحة: %lld دقيقة",
    "Session length": "مدة الجلسة",
    "Lengths can be changed while the timer is stopped.": "يمكن تغيير المدد والمؤقت متوقف.",
    "Notify me when a session ends": "نبّهني عند انتهاء الجلسة",
    "Notifications are turned off for this app in the system Settings.":
        "الإشعارات معطّلة لهذا التطبيق في إعدادات النظام.",
    "Only the end of the current session is announced. The timer itself keeps running without notifications.":
        "يُعلَن عن نهاية الجلسة الحالية فقط. المؤقت نفسه يستمر في العمل دون إشعارات.",
    "Focus session finished": "انتهت جلسة التركيز",
    "Break finished": "انتهت الاستراحة",
    "Time for a break.": "حان وقت الاستراحة.",
    "Time to focus again.": "حان وقت العودة إلى التركيز.",
    # Page objects
    "Objects": "العناصر",
    "Insert": "إدراج",
    "Text Box": "مربع نص",
    "Sticky Note": "ملاحظة لاصقة",
    "Shape": "شكل",
    "Image from Photos": "صورة من الصور",
    "Rectangle": "مستطيل",
    "Ellipse": "شكل بيضاوي",
    "Line": "خط",
    "Arrow": "سهم",
    "Edit Text": "تعديل النص",
    "Bring to Front": "إحضار إلى الأمام",
    "Send to Back": "إرسال إلى الخلف",
    "Rotate": "تدوير",
    "Lock": "قفل",
    "Unlock": "فتح القفل",
    "Delete": "حذف",
    "Text": "نص",
    "Tap an object to select it. Use Insert to add text, notes, shapes and images.":
        "اضغط على عنصر لتحديده. استخدم «إدراج» لإضافة نص وملاحظات وأشكال وصور.",
    "The objects on this page could not be read, so they cannot be changed.":
        "تعذّرت قراءة عناصر هذه الصفحة، لذلك لا يمكن تعديلها.",
    "This picture could not be read.": "تعذّرت قراءة هذه الصورة.",
    # Search and PDF text
    "Search": "البحث",
    "Search all notes": "ابحث في كل الملاحظات",
    "Searches titles, the text of imported PDFs, and typed text. Handwriting is not searchable yet.":
        "يبحث في العناوين ونصوص ملفات PDF المستوردة والنصوص المكتوبة. البحث في خط اليد غير متاح بعد.",
    "Search your notes": "ابحث في ملاحظاتك",
    "Arabic and English, with or without diacritics.": "بالعربية والإنجليزية، مع التشكيل أو بدونه.",
    "PDF text": "نص PDF",
    "Typed text": "نص مكتوب",
    "Select Text": "تحديد النص",
    "Copy": "نسخ",
    "Copied": "تم النسخ",
    "Where Else?": "أين ذُكر أيضًا؟",
    "No selectable text here. Scanned pages need OCR, which is not available yet.":
        "لا يوجد نص قابل للتحديد هنا. الصفحات الممسوحة ضوئيًا تحتاج إلى التعرّف الضوئي على النص، وهو غير متاح بعد.",
    "Drag across the text of a PDF page to select it.": "اسحب فوق نص صفحة PDF لتحديده.",
    # Shapes and smoothing
    "Straighten shapes when holding the pen at the end": "تقويم الأشكال عند تثبيت القلم في نهاية الخط",
    "Stroke smoothing": "تنعيم الخط",
    "Off": "إيقاف",
    "Strong": "قوي",
    "Shapes and smoothing": "الأشكال والتنعيم",
    "Draw a line, circle, ellipse or rectangle and keep the pen still for half a second before lifting it. Both features apply when the stroke is finished, not while you write. Undo removes the corrected stroke.":
        "ارسم خطًا أو دائرة أو شكلًا بيضاويًا أو مستطيلًا وثبّت القلم نصف ثانية قبل رفعه. تُطبَّق الميزتان عند انتهاء الخط لا أثناء الكتابة. التراجع يزيل الخط المُصحَّح.",
    # Tags and image import
    "Tags…": "الوسوم…",
    "Tags": "الوسوم",
    "New tag": "وسم جديد",
    "Add": "إضافة",
    "Imported images": "صور مستوردة",
    "None of the selected images could be read.": "تعذّرت قراءة كل الصور المحددة.",
    # Planner, backgrounds, scribble
    "Planner": "مخطِّط",
    "Background Image…": "صورة خلفية…",
    "Remove Background Image": "إزالة صورة الخلفية",
    "Scribble over ink to erase it": "الخربشة فوق الحبر تمسحه",
    "To erase, scribble back and forth at least five times across the strokes. Undo brings them back.":
        "للمسح، خربش ذهابًا وإيابًا خمس مرات على الأقل فوق الخطوط. التراجع يعيدها.",
    "Erased %lld strokes": "مُسح %lld من الخطوط",
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
