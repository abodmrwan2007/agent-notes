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
    "Searches titles, the text of imported PDFs, and typed text. Handwriting is not searchable yet. Locked notebooks are not searched.":
        "يبحث في العناوين ونصوص ملفات PDF المستوردة والنصوص المكتوبة. البحث في خط اليد غير متاح بعد، ولا يُبحث في الدفاتر المقفلة.",
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
    # Stickers
    "Sticker…": "ملصق…",
    "Stickers": "الملصقات",
    "My Stickers": "ملصقاتي",
    "Add from Photos": "إضافة من الصور",
    "Add your own pictures to use them as stickers. Cut-outs with transparent backgrounds work best.":
        "أضف صورك لتستخدمها ملصقات. الصور المقصوصة بخلفية شفافة تبدو أفضل.",
    "Remove from My Stickers": "إزالة من ملصقاتي",
    "Remove this sticker?": "إزالة هذا الملصق؟",
    "Notebooks that already use it keep their copy.": "الدفاتر التي تستخدمه تحتفظ بنسختها.",
    "Star": "نجمة",
    "Heart": "قلب",
    "Check mark": "علامة صح",
    "Warning": "تنبيه",
    "Question": "سؤال",
    "Idea": "فكرة",
    "Capsule": "كبسولة",
    "DNA": "حمض نووي",
    "Flask": "دورق",
    "Heartbeat": "نبض القلب",
    "Bone": "عظمة",
    "Important": "مهم",
    "Exam": "امتحان",
    "Review": "مراجعة",
    # Side panel, brushes, ruler, reading mode
    "Panel": "اللوحة",
    "Tools and Stickers": "الأدوات والملصقات",
    "Insert into Page": "إدراج في الصفحة",
    "Brushes": "الفُرَش",
    "Fountain Pen": "قلم حبر سائل",
    "Monoline": "خط موحّد",
    "Watercolor": "ألوان مائية",
    "Crayon": "شمع ملوّن",
    "Ruler": "المسطرة",
    "Reading Mode": "وضع القراءة",
    # Covers, lock, interface colour
    "Cover": "الغلاف",
    "First Page": "الصفحة الأولى",
    "Navy": "كحلي",
    "Ocean": "محيطي",
    "Coral": "مرجاني",
    "Forest": "أخضر غامق",
    "Sand": "رملي",
    "Plum": "بنفسجي غامق",
    "Locked": "مقفل",
    "Lock…": "قفل…",
    "Remove Lock": "إزالة القفل",
    "Lock this notebook": "قفل هذا الدفتر",
    "Remove the lock from this notebook": "إزالة القفل عن هذا الدفتر",
    "Open the locked notebook": "فتح الدفتر المقفل",
    "Set a passcode on this iPad to lock notebooks.": "اضبط رمز دخول لهذا الآيباد لتتمكن من قفل الدفاتر.",
    "The notebook could not be unlocked.": "تعذّر فتح قفل الدفتر.",
    "Appearance": "المظهر",
    "Interface color": "لون الواجهة",
    "Cyan": "سماوي",
    "Blue": "أزرق",
    "Teal": "فيروزي",
    "Purple": "بنفسجي",
    "Green": "أخضر",
    # Stickers (Twemoji), sticky note styles
    "Medical": "طبية",
    "Banners": "شرائط",
    "Medical and study stickers: Twemoji by Twitter, Inc and other contributors, licensed under CC BY 4.0. Banners are original artwork made for this app.":
        "الملصقات الطبية والدراسية: Twemoji من Twitter, Inc والمساهمين، بترخيص CC BY 4.0. الشرائط رسومات أصلية صُمّمت لهذا التطبيق.",
    "Plain": "عادية",
    "Lined": "مسطّرة",
    "Grid Paper": "مربعات",
    "Taped": "بشريط لاصق",
    "Pinned": "بدبوس",
    # Labelled diagrams
    "Labelled Diagrams": "رسوم توضيحية مُعنونة",
    "Labels": "التسميات",
    "English": "إنجليزي",
    "Arabic": "عربي",
    "Blank (quiz)": "فارغة (اختبر نفسك)",
    "Simplified study drawings made for this app, not to scale. Choose Blank to test yourself: write the names in the empty boxes.":
        "رسوم دراسية مبسّطة صُمّمت لهذا التطبيق، وليست بمقياس حقيقي. اختر «فارغة» لتختبر نفسك: اكتب الأسماء في المربعات الفارغة.",
    "Labelled medical diagrams": "رسوم طبية مُعنونة",
    "Tools ▸ Stickers ▸ Labelled Diagrams: heart, lungs, brain, neuron, eye and cell, with English, Arabic or blank labels to test yourself.":
        "الأدوات ◂ الملصقات ◂ رسوم توضيحية مُعنونة: القلب والرئتان والدماغ والخلية العصبية والعين والخلية، بتسميات إنجليزية أو عربية أو فارغة لتختبر نفسك.",
    "Record lectures": "سجّل المحاضرات",
    "Tap Record at the top while you write. In Tools ▸ Audio, turn on Tap writing to hear it, then tap your notes to hear that moment.":
        "اضغط «تسجيل» في الأعلى أثناء الكتابة. ومن الأدوات ◂ الصوت فعّل «اضغط على الكتابة لتسمعها»، ثم اضغط على ملاحظاتك لتسمع تلك اللحظة.",
    # Top bar
    "Read": "قراءة",
    "Write": "كتابة",
    # What's New and acknowledgements
    "What's New": "الجديد",
    "Help": "مساعدة",
    "Acknowledgements": "شكر وتراخيص",
    "Used unmodified as medical and study stickers.": "مستخدمة دون تعديل كملصقات طبية ودراسية.",
    "Library index database (not used in the Swift Playgrounds build).": "قاعدة بيانات فهرس المكتبة (غير مستخدمة في نسخة Swift Playgrounds).",
    "You can open this again from Settings.": "يمكنك فتح هذه الشاشة مجددًا من الإعدادات.",
    "Tools beside your page": "الأدوات بجانب صفحتك",
    "Open a notebook and tap Tools at the top. The calculator, graphing, periodic table, timer and stickers stay open next to the page.":
        "افتح دفترًا واضغط «الأدوات» في الأعلى. تبقى الحاسبة وراسم الدوال والجدول الدوري والمؤقت والملصقات مفتوحة بجانب الصفحة.",
    "Medical stickers": "ملصقات طبية",
    "Insert ▸ Sticker…, or the Stickers tab in Tools: heart, lungs, brain, stethoscope, DNA and more.":
        "إدراج ◂ ملصق…، أو تبويب الملصقات في الأدوات: قلب، رئتان، دماغ، سماعة طبيب، حمض نووي والمزيد.",
    "Sticky notes in five styles": "ملاحظات لاصقة بخمسة أنماط",
    "Insert ▸ Sticky Note: plain, lined, grid, taped or pinned, in seven colours.":
        "إدراج ◂ ملاحظة لاصقة: عادية أو مسطّرة أو مربعات أو بشريط لاصق أو بدبوس، بسبعة ألوان.",
    "Search everything": "ابحث في كل شيء",
    "Search in the sidebar finds words in titles, PDFs and typed text, in Arabic and English.":
        "«البحث» في الشريط الجانبي يجد الكلمات في العناوين وملفات PDF والنصوص المكتوبة، بالعربية والإنجليزية.",
    "Select and copy PDF text": "حدّد نص PDF وانسخه",
    "Choose the Select Text tool and drag across a PDF, then Copy or Where Else?":
        "اختر أداة «تحديد النص» واسحب فوق ملف PDF، ثم «نسخ» أو «أين ذُكر أيضًا؟».",
    "Brushes and ruler": "الفُرَش والمسطرة",
    "The brush button holds fountain pen, monoline, watercolor and crayon. The ruler button shows a ruler on the page.":
        "زر الفُرَش فيه قلم الحبر السائل والخط الموحّد والألوان المائية والشمع الملوّن. وزر المسطرة يُظهر مسطرة على الصفحة.",
    "Perfect shapes": "أشكال متقنة",
    "Draw a line, circle or rectangle and keep the pen still for half a second before lifting it.":
        "ارسم خطًا أو دائرة أو مستطيلًا وثبّت القلم نصف ثانية قبل رفعه.",
    "Scribble to erase": "المسح بالخربشة",
    "Scribble back and forth over ink to erase it. Undo brings it back.":
        "خربش ذهابًا وإيابًا فوق الحبر لتمسحه. التراجع يعيده.",
    "Reading mode": "وضع القراءة",
    "Tap Read at the top to hide the tools while you study.": "اضغط «قراءة» في الأعلى لإخفاء الأدوات أثناء المذاكرة.",
    "Lock, covers and tags": "القفل والأغلفة والوسوم",
    "Touch and hold a notebook in the library for Lock…, Cover and Tags…":
        "اضغط مطولًا على دفتر في المكتبة لتجد «قفل…» و«الغلاف» و«الوسوم…».",
    "Study tools": "أدوات الدراسة",
    # Lecture audio
    "Record": "تسجيل",
    "Stop %@": "إيقاف %@",
    "Stop Recording": "إيقاف التسجيل",
    "Recording": "تسجيل",
    "Audio": "الصوت",
    "Recordings": "التسجيلات",
    "Recording saved": "حُفظ التسجيل",
    "Play": "تشغيل",
    "Tap writing to hear it": "اضغط على الكتابة لتسمعها",
    "Tap a word you wrote during a recording to play the lecture from that moment. Writing is paused while this is on.":
        "اضغط على كلمة كتبتها أثناء تسجيل لتشغيل المحاضرة من تلك اللحظة. الكتابة متوقفة ما دام هذا الخيار مفعّلًا.",
    "Tap Record at the top while you write. Recordings are saved inside this notebook.":
        "اضغط «تسجيل» في الأعلى أثناء الكتابة. تُحفظ التسجيلات داخل هذا الدفتر.",
    "Delete this recording?": "حذف هذا التسجيل؟",
    "The audio is removed from this notebook. Your writing stays.": "يُحذف الصوت من هذا الدفتر وتبقى كتابتك.",
    "This was not written during a recording.": "لم يُكتب هذا أثناء تسجيل.",
    "This recording could not be played.": "تعذّر تشغيل هذا التسجيل.",
    "Recording could not start.": "تعذّر بدء التسجيل.",
    "Microphone access is off for this app. Turn it on in Settings ▸ Privacy ▸ Microphone.":
        "الوصول إلى الميكروفون متوقف لهذا التطبيق. فعّله من الإعدادات ◂ الخصوصية ◂ الميكروفون.",
    "Recording stopped because another app or a call used the audio. What was recorded is saved.":
        "توقف التسجيل لأن تطبيقًا آخر أو مكالمة استخدم الصوت. ما سُجّل محفوظ.",
    "Study in the sidebar: scientific calculator, graphing, periodic table and focus timer.":
        "«الدراسة» في الشريط الجانبي: آلة حاسبة علمية، راسم دوال، جدول دوري، ومؤقت تركيز.",
    # Text tools, scanning, export, templates
    "Narrow Ruled": "مسطّر ضيّق",
    "Small Grid": "شبكة صغيرة",
    "Music Staff": "مدرج موسيقي",
    "Isometric Dots": "نقاط متساوية القياس",
    "Checklist": "قائمة مهام",
    "No text was found on this page.": "لم يُعثر على نص في هذه الصفحة.",
    "Put on Page": "ضعه في الصفحة",
    "Look Up": "ابحث في القاموس",
    "Stop": "إيقاف",
    "Read Aloud": "اقرأ بصوت عالٍ",
    "Translate": "ترجم",
    "Reading the page…": "يقرأ الصفحة…",
    "Recognized Text": "النص المتعرَّف عليه",
    "Check the text: recognition can misread handwriting. Edit it here before putting it on the page.":
        "راجع النص: قد يخطئ التعرّف في قراءة خط اليد. عدّله هنا قبل وضعه في الصفحة.",
    "Text Tools": "أدوات النص",
    "Scan Document": "مسح مستند",
    "Pages as Images (PNG)": "الصفحات كصور (PNG)",
    "Print…": "طباعة…",
    "Recognize Handwriting": "تعرّف على خط اليد",
    "Recognize All Text on Page": "تعرّف على كل نص الصفحة",
    "Translate & Look Up": "ترجمة وقاموس",
    "Remove Background": "إزالة الخلفية",
    "No subject was found in this picture.": "لم يُعثر على عنصر بارز في هذه الصورة.",
    "The background could not be removed.": "تعذّرت إزالة الخلفية.",
    "Playback speed": "سرعة التشغيل",
    "Handwriting to text, translate, scan": "خط اليد إلى نص، ترجمة، مسح",
    "Page actions (•••) ▸ Recognize Handwriting turns your writing into text you can translate, look up, hear or put on the page. Insert ▸ Scan Document, Export ▸ Pages as Images or Print, five new papers, audio speed in Tools ▸ Audio, and Remove Background for pictures.":
        "إجراءات الصفحة (•••) ◂ «تعرّف على خط اليد» يحوّل كتابتك إلى نص تترجمه أو تبحث عنه في القاموس أو تسمعه أو تضعه في الصفحة. وأيضًا: إدراج ◂ مسح مستند، تصدير ◂ الصفحات كصور أو طباعة، خمس أوراق جديدة، سرعة الصوت في الأدوات ◂ الصوت، وإزالة خلفية الصور.",
    # Heart atlas
    "The heart model could not be loaded": "تعذّر تحميل مجسّم القلب",
    "Loading the heart model…": "يُحمّل مجسّم القلب…",
    "Heart": "القلب",
    "Show only this": "اعرض هذا فقط",
    "Hide": "إخفاء",
    "Drag to turn, pinch to zoom, tap a part to name it.": "اسحب للتدوير، وقرّب بإصبعين للتكبير، واضغط على جزء لترى اسمه.",
    "See-through walls": "جدران شفّافة",
    "Show all": "عرض الكل",
    "Reset view": "إعادة المنظر",
    "Show": "إظهار",
    "Chambers": "الحجرات",
    "Valves and papillary muscles": "الصمامات والعضلات الحليمية",
    "Great vessels": "الأوعية الكبيرة",
    "Coronary vessels": "الأوعية التاجية",
    "3D data: BodyParts3D, © The Database Center for Life Science, licensed under CC Attribution-Share Alike 2.1 Japan. Reduced and coloured for this app. A study model, not reviewed by an anatomist. The muscle wall of both ventricles is one piece.":
        "بيانات ثلاثية الأبعاد: BodyParts3D، © The Database Center for Life Science، بترخيص CC Attribution-Share Alike 2.1 Japan. مُصغّرة وملوّنة لهذا التطبيق. مجسّم للدراسة لم يراجعه مختص تشريح. الجدار العضلي للبطينين قطعة واحدة.",
    "The 3D heart in Atlas is made from these models: parts selected, merged, reduced and coloured. The changed model is shared under the same license.":
        "القلب ثلاثي الأبعاد في الأطلس مصنوع من هذه المجسّمات: اختيرت أجزاؤه ودُمجت وصُغّرت ولُوّنت، ويُشارك المجسّم المعدّل بالترخيص نفسه.",
    "3D heart atlas": "أطلس القلب ثلاثي الأبعاد",
    "Atlas in the sidebar: turn and zoom a 3D heart, tap a part to see its name in Arabic and English, hide parts or make the walls see-through to look at the valves.":
        "«الأطلس» في الشريط الجانبي: دوّر قلبًا ثلاثي الأبعاد وكبّره، واضغط على جزء لترى اسمه بالعربية والإنجليزية، وأخفِ أجزاء أو اجعل الجدران شفّافة لترى الصمامات.",
    # AI study assistant
    "AI": "الذكاء الاصطناعي",
    "Explain": "اشرح",
    "This page": "هذه الصفحة",
    "Whole notebook": "الدفتر كاملًا",
    "Pages": "الصفحات",
    "Answer language": "لغة الإجابة",
    "Summarize": "لخّص",
    "Flashcards & quiz": "بطاقات واختبار",
    "Ask about these pages": "اسأل عن هذه الصفحات",
    "Ask": "اسأل",
    "Tip: select text on a PDF page with the Select Text tool, then tap Explain.":
        "تلميح: حدّد نصًا في صفحة PDF بأداة «تحديد النص» ثم اضغط «اشرح».",
    "Reading your pages…": "يقرأ صفحاتك…",
    "AI needs your Claude API key": "الذكاء الاصطناعي يحتاج مفتاح Claude API الخاص بك",
    "Open Settings ▸ AI Assistant and paste a key from console.anthropic.com. Each request is billed to that account.":
        "افتح الإعدادات ◂ مساعد الذكاء الاصطناعي والصق مفتاحًا من console.anthropic.com. كل طلب يُحسب على ذلك الحساب.",
    "The answer was cut off because it was very long.": "انقطعت الإجابة لأنها طويلة جدًا.",
    "Flashcards": "البطاقات",
    "Quiz": "الاختبار",
    "New conversation": "محادثة جديدة",
    "Added": "أُضيف",
    "Add to notebook": "أضف إلى الدفتر",
    "Requests left today: %lld": "الطلبات المتبقية اليوم: %lld",
    "Your pages are sent to Anthropic (Claude) to answer. Check important medical facts against your textbook.":
        "تُرسل صفحاتك إلى Anthropic ‏(Claude) للإجابة. راجع المعلومات الطبية المهمة في كتابك.",
    "Tap a card to see the answer.": "اضغط على البطاقة لترى الإجابة.",
    "The answer could not be read. Try again.": "تعذّرت قراءة الإجابة. حاول مرة أخرى.",
    "Add your Claude API key in Settings ▸ AI Assistant first.":
        "أضف مفتاح Claude API أولًا من الإعدادات ◂ مساعد الذكاء الاصطناعي.",
    "You have used today's %lld AI requests. Change the daily limit in Settings ▸ AI Assistant.":
        "استخدمت طلبات اليوم وعددها %lld. غيّر الحد اليومي من الإعدادات ◂ مساعد الذكاء الاصطناعي.",
    "These pages are empty. Write or import something first.": "هذه الصفحات فارغة. اكتب أو استورد شيئًا أولًا.",
    "No connection to the AI service. Check the internet and try again.":
        "لا يوجد اتصال بخدمة الذكاء الاصطناعي. تحقق من الإنترنت وحاول مرة أخرى.",
    "The API key was not accepted. Check it in Settings ▸ AI Assistant.":
        "لم يُقبل مفتاح API. راجعه في الإعدادات ◂ مساعد الذكاء الاصطناعي.",
    "Too many requests, or your account's spending limit was reached. Wait a minute, or check your limits at console.anthropic.com.":
        "طلبات كثيرة، أو وصل حسابك إلى حد الصرف. انتظر دقيقة، أو راجع حدودك في console.anthropic.com.",
    "The AI service is busy right now. Try again in a minute.": "خدمة الذكاء الاصطناعي مشغولة الآن. حاول بعد دقيقة.",
    "The request was rejected (it may be too large: try one page).": "رُفض الطلب (قد يكون كبيرًا: جرّب صفحة واحدة).",
    "The AI declined this request.": "رفض الذكاء الاصطناعي هذا الطلب.",
    "A key is saved on this iPad.": "يوجد مفتاح محفوظ على هذا الآيباد.",
    "Remove key": "إزالة المفتاح",
    "The key was removed from this iPad.": "أُزيل المفتاح من هذا الآيباد.",
    "Paste your API key": "الصق مفتاح API",
    "Save key": "حفظ المفتاح",
    "Saved. Open a notebook, tap Tools, then the AI tab.": "حُفظ. افتح دفترًا، واضغط «الأدوات» ثم تبويب «الذكاء الاصطناعي».",
    "The key could not be saved.": "تعذّر حفظ المفتاح.",
    "Claude API key": "مفتاح Claude API",
    "Create a key at console.anthropic.com (API Keys) and set a monthly spending limit there. The key is kept in this iPad's Keychain only. Never share it or put it in a file.":
        "أنشئ مفتاحًا في console.anthropic.com ‏(API Keys) وضع هناك حدًا شهريًا للصرف. يُحفظ المفتاح في سلسلة مفاتيح هذا الآيباد فقط. لا تشاركه ولا تضعه في ملف.",
    "Model": "النموذج",
    "Daily limit: %lld requests": "الحد اليومي: %lld طلب",
    "Used today": "المستخدم اليوم",
    "Model and limit": "النموذج والحد",
    "Opus is the most capable and the most expensive; Haiku is much cheaper. A one-page summary costs roughly a few cents with Opus, less than a cent with Haiku.":
        "Opus الأقوى والأغلى، وHaiku أرخص بكثير. تلخيص صفحة واحدة يكلّف تقريبًا بضعة سنتات مع Opus، وأقل من سنت مع Haiku.",
    "Summaries, flashcards and quizzes, explanations and questions send a picture and the text of the chosen pages to Anthropic. Answers can be wrong: check important medical facts against your textbook.":
        "التلخيص والبطاقات والاختبارات والشرح والأسئلة ترسل صورة ونص الصفحات المختارة إلى Anthropic. قد تخطئ الإجابات: راجع المعلومات الطبية المهمة في كتابك.",
    "Privacy and accuracy": "الخصوصية والدقة",
    "AI Assistant": "مساعد الذكاء الاصطناعي",
    "Notes are stored only on this device in this build. The AI assistant sends only the pages you choose. Sync and subscriptions are not implemented yet.":
        "تُحفظ الملاحظات على هذا الجهاز فقط في هذا الإصدار. مساعد الذكاء الاصطناعي يرسل الصفحات التي تختارها فقط. المزامنة والاشتراكات غير منفّذة بعد.",
    "AI study assistant": "مساعد دراسة بالذكاء الاصطناعي",
    "Tools ▸ AI: summarize a page or the notebook, make flashcards and a quiz, ask questions, or select PDF text and tap Explain. Add your Claude API key in Settings ▸ AI Assistant first.":
        "الأدوات ◂ الذكاء الاصطناعي: لخّص صفحة أو الدفتر، واصنع بطاقات واختبارًا، واسأل، أو حدّد نصًا في PDF واضغط «اشرح». أضف مفتاح Claude API أولًا من الإعدادات ◂ مساعد الذكاء الاصطناعي.",
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
