/**
 * Bilingual strings for the ADHA Baniyas microsite. Arabic is the default and the site opens RTL.
 * Approval provenance for the Arabic is recorded string by string in
 * docs/arabic-approval-register.md - read it before changing any Arabic here.
 * A code module rather than Custom Labels because Translation Workbench and end-user languages
 * are off org-wide; PICKLISTS below stands in for the missing ADHA_Unit__c-ar translations.
 * DIGITS: Latin throughout, even inside Arabic prose - Plot_UID__c and the CAD "Plan" base image
 * use Latin digits, and localising them would break reconciliation against the drawing.
 */

export const DEFAULT_LANG = 'ar';
export const RTL_LANGS = ['ar'];

export function isRtl(lang) {
    return RTL_LANGS.indexOf(lang) >= 0;
}

export function dirOf(lang) {
    return isRtl(lang) ? 'rtl' : 'ltr';
}

const STRINGS = {
    ar: {
        /* ---------- journey: shared ---------- */
        // No langToggle key: the switch shows both languages at once, each written in its own
        // language, so neither name is ever translated.
        authority: 'هيئة أبوظبي للإسكان',
        project: 'غرب بني ياس',
        sessionEnded: 'انتهت الجلسة',
        signInAgain: 'تسجيل الدخول مرة أخرى',
        lockSupersededTitle: 'تم تسجيل الدخول من جهاز آخر',
        lockIdleTitle: 'تم تسجيل الخروج',
        lockSuperseded: 'تم تسجيل الخروج من هذه النافذة لأن بطاقة الهوية الإماراتية الخاصة بك استُخدمت لتسجيل الدخول من جهاز آخر. لا يمكن استخدام أكثر من جلسة واحدة في الوقت نفسه.',
        lockIdle:
            'تم تسجيل خروجك بعد 5 دقائق من عدم النشاط. ولن تتأثر فترة الحجز البالغة 7 أيام.',
        lockSignedOutTitle: 'تم تسجيل الخروج',
        lockSignedOut: 'تم تسجيل الخروج. ولن تتأثر مدة الحجز البالغة 7 أيام.',

        /* ---------- sign out ----------
           Three bodies: before the undertaking the villa is only soft-held and signing out gives
           it up; after, it is reserved and nothing is lost. THE ARABIC HERE IS NOT ADHA'S. */
        signOut: 'تسجيل الخروج',
        signOutTitle: 'هل تريد تسجيل الخروج؟',
        signOutBodyPlain:
            'ستحتاج إلى بطاقة الهوية الإماراتية ورمز تحقق جديد لتسجيل الدخول مرة أخرى.',
        signOutBodyHeld: 'المسكن {0} محجوز مؤقتاً لبضع دقائق فقط. سيؤدي تسجيل الخروج إلى إلغاء هذا الحجز المؤقت، وقد يحجزه متعامل آخر. ستحتاج إلى بطاقة الهوية الإماراتية ورمز تحقق جديد لتسجيل الدخول مرة أخرى.',
        signOutBodyReserved:
            'يبقى المسكن {0} محجوزاً باسمك ولن تتأثر مدة الحجز البالغة 7 أيام. ستحتاج إلى بطاقة الهوية الإماراتية ورمز تحقق جديد لتسجيل الدخول مرة أخرى.',
        confirmSignOut: 'نعم، تسجيل الخروج',

        /* ---------- exploration mode ----------
           ADHA's approved wording, 27 Aug 2026, copied exactly, "next Wednesday" included - the
           change request register carries the date that phrase expires. */
        noticeTitle: 'تنويه مهم',
        noticeFullP1:
            'المرحلة الحالية مخصصة للاطلاع على المشروع والتعرّف على تفاصيل الوحدات السكنية المتاحة، وليس للحجز.',
        noticeFullP2:
            'سيتم فتح مرحلة الاختيار والحجز يوم الأربعاء القادم، على مراحل، وفقًا لنوع الخدمة، الملاءة المالية، والتقارب الأسري، وسيتم إشعاركم بموعد الحجز المخصص لكم برسالة نصية قصيرة.',
        noticeFullP3:
            'كما نؤكد أن الوحدات المعروضة لكم تتوافق مع استحقاقكم ولا يمكن تغييرها. وننصحكم خلال مرحلة الاطلاع بتحديد أكثر من خيار استعدادًا للحجز.',
        noticeMore: 'المزيد',
        noticeLess: 'إخفاء',
        noticeShort:
            'المرحلة الحالية للاطلاع فقط وليست للحجز. سيتم فتح مرحلة الاختيار والحجز يوم الأربعاء القادم على مراحل، وسيتم إشعاركم بموعد الحجز برسالة نصية قصيرة. الوحدات المعروضة حسب الاستحقاق ولا يمكن تغييرها، وننصح بتحديد أكثر من خيار استعدادًا للحجز.',

        /* ---------- journey: welcome ---------- */
        welcomeLede: 'اختر مسكنك في مشروع غرب بني ياس واحجزه.',
        whatYouNeed: 'ما ستحتاج إليه؟',
        whatYouNeedBody: 'تمت دعوتك لاختيار مسكنك في مشروع غرب بني ياس. سجّل الدخول باستخدام بطاقة الهوية الإماراتية للإطلاع على المساكن التي يحق لك الاختيار من بينها.',
        step1: 'التحقق من بطاقة الهوية الإماراتية',
        step2: 'مراجعة الإقرار والموافقة عليه',
        step3: 'استكشف المشروع السكني واختر المسكن',
        welcomeNotice:
            'لديك 7 أيام من تاريخ تسجيل الدخول لأول مرة لإتمام الحجز. وتبدأ هذه المهلة فور تسجيل دخولك، لذا يرجى تسجيل الدخول فقط عندما تكون مستعداً للبدء بإجراءات الحجز.',
        begin: 'ابدأ',

        /* ---------- arrival: the six renders beside the form ----------
           Aria-labels for the slideshow dots, sentence case, so they cannot reuse the title-case
           room keys from the map block. THE ARABIC HERE IS NOT ADHA'S - confirm before go-live. */

        slideHeritage: 'واجهة أندلسية',
        slideLiving: 'غرفة معيشة مزدوجة الارتفاع',
        slideModern: 'واجهة عصرية',
        slideDining: 'منطقة الطعام',
        slideBedroom: 'غرفة النوم الرئيسية',
        slideStreet: 'المشهد العام للشارع',
        /* ---------- journey: identity ---------- */
        back: 'رجوع',
        changeEmiratesId: 'تغيير رقم الهوية الإماراتية',
        retry: 'إعادة المحاولة',
        stepOneOfFour: 'الخطوة 1 من 4',
        stepTwoOfFour: 'الخطوة 2 من 4',
        verifyIdentity: 'التحقق من هويتك',
        loginLede:
            'أدخل رقم الهوية الإماراتية المرتبط بطلب الإسكان الخاص بك. سنرسل رمز تحقق إلى رقم الهاتف المتحرك المسجّل لدى الهيئة.',
        emiratesId: 'الهوية الإماراتية',
        sendCode: 'إرسال رمز التحقق',
        enterCode: 'أدخل رمز التحقق',
        sentTo: 'تم الإرسال إلى {0}',
        verificationCode: 'رمز التحقق',
        verifyContinue: 'تحقق ومتابعة',
        resendCode: 'إعادة إرسال الرمز',
        resendIn: 'إعادة الإرسال خلال {0} ثانية',

        /* ---------- journey: declaration ---------- */
        generalDeclaration: 'الإقرار العام',
        applicationNo: 'طلب رقم {0}',
        daysLeft: 'تبقى {0} أيام',
        oneDayLeft: 'تبقى يوم واحد',
        declarationPlaceholder:
            'نص مؤقت - لم تقدّم هيئة أبوظبي للإسكان الإقرار المعتمد بعد. غير مخصص للاستخدام الفعلي.',
        declarationRead: 'لقد قرأت الإقرار كاملاً.',
        declarationScroll: 'مرّر إلى نهاية النص للمتابعة.',
        acceptContinue: 'الموافقة والمتابعة',

        /* ---------- journey: reservation ---------- */
        stepFourOfFour: 'الخطوة 4 من 4',
        financeTitle: 'المبلغ الإضافي',
        financeLede: 'يتجاوز سعر هذا المسكن مبلغ القرض المعتمد من الهيئة. اختر طريقة السداد المناسب لك.',
        fPrice: 'سعر المسكن',
        fApproved: 'المبلغ المعتمد من الهيئة',
        fExtra: 'المبلغ الإضافي المستحق',
        fMethod: 'طريقة السداد',
        pmUpfront: 'سداد كامل المبلغ دفعة واحدة',
        pmPlan: 'السداد على أقساط شهرية',
        pmPartialPlan: 'سداد جزء الآن والباقي على أقساط',
        pmPartialPlanTopUp: 'سداد جزء من المبلغ الآن، والباقي على أقساط، مع تمويل إضافي',
        pmTopUp: 'تمويل إضافي من بنك شريك',
        noteRefund: 'في حال عدم الموافقة على قرض الإسكان، ستوجّه الهيئة برد المبالغ التي قمت بسدادها.',
        noteCapped: 'لا يقبل الحساب سوى المبلغ الإضافي الموضّح أعلاه، ويُعاد إليك أي مبلغ يزيد عنه.',
        noteTopUpDeclined: 'في حال رفض البنك الشريك خطاب العرض النهائي، ستطلب منك الهيئة إيداع الفرق نقدًا أو الانتقال إلى خطة سداد، على أن يتم سداد المبلغ الإضافي خلال مدة أقصاها ثلاثة (3) أشهر من تاريخ تأكيد الاختيار.',
        continueLabel: 'متابعة',
        undertakingTitle: 'تعهد القرض',
        undertakingLede: 'يرجى قراءة التعهد الوارد أدناه بالكامل والموافقة عليه لإتمام حجز المسكن {0}.',
        signContinue: 'أوافق وأؤكد الحجز',
        loadingUndertaking: 'جارٍ تحميل نص التعهد...',
        loadingJourney: 'جارٍ استعادة جلستك...',
        doneTitle: 'تم تأكيد حجزك',
        doneLede: 'تم حجز المسكن {0}.',
        donePendingTitle: 'وقّع الإقرار والتعهد لتأكيد حجزك',
        donePendingLede: 'المسكن {0} محجوز لك مؤقتاً. ويُعد حجزك مؤكداً بعد توقيع التعهد.',
        refLabel: 'الرقم المرجعي',
        factAmend: 'التعديل حتى',
        factDue: 'المبلغ مستحق',
        deadlineReservation: 'يمكنك تعديل حجزك حتى',
        deadlinePayment: 'موعد استحقاق المبلغ الإضافي: خلال مدة أقصاها ثلاثة (3) أشهر من تاريخ تأكيد الاختيار.',
        signingToFollow: 'الخطوة الأخيرة هي توقيع وثيقة التعهد إلكترونياً. يتم التوقيع هنا مباشرة، ولا يُرسل إليك أي بريد إلكتروني.',
        signHeading: 'وقع الإقرار والتعهد',
        signBody: 'ستُفتح صفحة التوقيع الآمنة، وتعود إلى هنا فور الانتهاء. الوثيقة باللغتين العربية والإنجليزية.',
        signCta: 'المتابعة إلى التوقيع',
        signOpening: 'جارٍ تجهيز وثيقتك…',
        signChecking: 'جارٍ التحقق من توقيعك…',
        signedHeading: 'تم توقيع تعهدك',
        signedBody: 'اكتمل حجزك. نسخة موقّعة محفوظة مع حجزك.',
        downloadUndertaking: 'تنزيل نسخة التعهد',
        downloadSigned: 'تنزيل النسخة الموقّعة',
        downloadWorking: 'جارٍ التحضير…',
        downloadFailed: 'تعذّر تنزيل الملف الآن. يرجى المحاولة مرة أخرى.',
        signNotFinished: 'لم يكتمل التوقيع بعد. يمكنك المتابعة والتوقيع الآن.',
        signDeclined: 'تم رفض التوقيع. يرجى التواصل مع الهيئة.',
        MSG_SIGNING_FAILED: 'تعذّر فتح صفحة التوقيع. حجزك محفوظ. يرجى المحاولة مرة أخرى، وإن تكرر ذلك تواصل مع هيئة أبوظبي للإسكان.',
        changeVilla: 'تغيير المسكن',
        // The collapsed confirmation. Short enough to sit on one line beside the reference and
        // the day count, on a phone, in both languages.
        reservedShort: 'المسكن {0} محجوز لك',
        // The hold clock. Latin digits, like every other number on the site.
        heldForYou: 'أكّد حجزك خلال {0}',
        holdEndingSoon: 'تبقّت دقيقتان على حجزك المؤقت.',
        holdLapsed: 'انتهت مهلة الحجز المؤقت. لا يزال بإمكانك تأكيد الحجز إذا لم يحجزها شخص آخر.',
        chooseAnother: 'اختر مسكن آخر',
        details: 'التفاصيل',
        backToMap: 'العودة إلى الخريطة',
        changeVillaWarn: 'سيتم إلغاء حجز المسكن {0}، وستحتاج إلى قراءة التعهد والموافقة عليه من جديد. ولن تبدأ مهلة الحجز البالغة 7 أيام من جديد.',
        changeVillaFinal: 'هذه فرصتك الأخيرة من أصل {0} فرص متاحة.',
        confirmChange: 'نعم، تغيير المسكن',
        cancel: 'إلغاء',
        checkingVilla: 'جارٍ التحقق من المسكن...',
        unitUnavailable: 'هذا المسكن غير متاح',
        unitAlreadyYours: 'هذا المسكن محجوز لك بالفعل',
        imageFailed: 'تعذّر تحميل صورة المخطط الرئيسي.',
        searchNotRendered: 'المسكن المطلوب غير معروض حالياً في المخطط.',
        searchJumped: 'تم الانتقال إلى القطعة {0}.',
        // One answer for every failed search - taken, out of category, filtered out or a typo.
        // Never says the villa does not exist: most of the time it does.
        searchUnavailable: 'المسكن {0} غير متاح.',
        nothingEligibleTitle: 'لا توجد مساكن متاحة لطلبك حالياً',
        nothingEligibleBody: 'لا توجد حالياً مساكن متاحة تتوافق مع الفئة ونوع الخدمة المحددين في طلبك. يرجى التواصل مع هيئة أبوظبي للإسكان.',

        /* ---------- journey: idle ---------- */
        stillThere: 'هل ما زلت هنا؟',
        idleWarning: 'سيتم تسجيل خروجك خلال {0} ثانية. ولن تتأثر مهلة الحجز البالغة 7 أيام.',
        staySignedIn: 'البقاء متصلاً',

        /* ---------- messages, resolved from Apex codes ---------- */
        MSG_ENTER_EID: 'يرجى إدخال رقم الهوية الإماراتية.',
        MSG_EID_UNVERIFIED: 'تعذّر التحقق من رقم الهوية الإماراتية. يرجى التأكد من الرقم والمحاولة مرة أخرى.',
        MSG_ENTER_OTP: 'يرجى إدخال الرمز المرسل إلى هاتفك المتحرك.',
        MSG_CODE_RESENT: 'تم إرسال رمز جديد.',
        MSG_GENERIC: 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
        MSG_START: 'إذا كان رقم الهوية الإماراتية مسجلاً لهذا المشروع، فقد تم إرسال رمز تحقق إلى رقم الهاتف المتحرك المسجّل لدى الهيئة.',
        MSG_SESSION_EXPIRED: 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.',
        MSG_OTP_INVALID: 'رمز التحقق غير صحيح.',
        MSG_OTP_MAX_ATTEMPTS: 'لقد استنفذت الحد الأقصى لمحاولات التحقق.',
        MSG_OTP_MAX_RESEND: 'لقد استنفذت الحد الأقصى لعدد مرات إعادة الإرسال.',
        MSG_OTP_TOO_SOON: 'يرجى الانتظار قبل طلب رمز تحقق جديد.',

        /* ---------- reservation ---------- */
        // "try again" and "choose another villa" are different instructions; conflating them would
        // send a customer away from a villa they could still have had.
        MSG_UNIT_TAKEN: 'تم حجز هذا المسكن للتو من قبل متعامل آخر. يرجى اختيار مسكن آخر.',
        MSG_ALREADY_HELD: 'لديك مسكن محجوز بالفعل. يمكنك تغيير اختيارك، واختيار مسكن آخر.',
        MSG_NOT_ELIGIBLE: 'هذا المسكن غير متاح لنوع طلبك.',
        MSG_WINDOW_CLOSED: 'انتهت مهلة الاختيار البالغة 7 أيام.',
        MSG_ATTEMPTS_SPENT: 'لقد استخدمت فرصتي الاختيار المتاحتين لك.',
        MSG_CHANGES_SPENT: 'لقد استخدمت جميع محاولات تغيير المسكن المتاح لك.',
        MSG_PAYMENT_METHOD: 'يرجى اختيار طريقة سداد المبلغ الإضافي.',
        MSG_RESERVATIONS_CLOSED: 'لم تبدأ عملية الحجز بعد. يمكنك الآن استكشاف المشروع السكني واختيار مسكنك عند فتح باب الحجز.',

        /* ---------- map: chrome ---------- */
        searchPlaceholder: 'الرقم أو المعرّف (WB4_03-405)',
        searchAria: 'البحث بالرقم أو المعرّف',
        search: 'بحث',
        filters: 'عوامل التصفية',
        filtersCount: 'معايير البحث ({0})',

        /* ---------- Pinning ---------- */
        pinnedBanner: 'تم تخصيص المسكن {0} لك، وهو المسكن الوحيد المتاح للحجز.',
        MSG_PIN_CONFLICT: 'هذا المسكن مخصص لمتعامل آخر.',
        opsTitle: 'وضع التخصيص',
        opsSearch: 'ابحث برقم الطلب أو الاسم',
        opsNoResults: 'لا توجد نتائج',
        opsLoan: 'مبلغ القرض المعتمد',
        opsCategory: 'الفئة',
        opsService: 'نوع الخدمة',
        opsPin: 'تخصيص هذا المسكن',
        opsUnpin: 'إزالة التخصيص',
        opsUnpinConfirm: 'تأكيد إزالة التخصيص',
        opsPinnedTo: 'مخصص إلى',
        opsSelectApplicant: 'اختر المتعامل أولاً، ثم اضغط على المسكن في المخطط.',
        opsWarnCategory: 'تنبيه: الفئة غير مطابقة',
        opsWarnService: 'تنبيه: نوع الخدمة غير مطابق',
        opsWarnPrice: 'تنبيه: السعر أعلى من مبلغ القرض المعتمد',
        opsStatusWaiting: 'بانتظار الحجز',
        opsStatusBooked: 'تم الحجز',
        opsStatusSigned: 'تم التوقيع',
        opsStatusBlocked: 'محجوب',
        opsBoardTitle: 'المساكن المخصصة',
        /* Later additions - Aurelix Arabic, recorded unapproved in docs/arabic-approval-register.md. */
        MSG_PIN_ALREADY_PINNED: 'هذا المتعامل مخصص له مسكن آخر بالفعل. يرجى إلغاء التخصيص أولاً.',
        MSG_PIN_HAS_RESERVATION: 'لدى هذا المتعامل حجز قائم بالفعل ولا يمكن تخصيص مسكن له.',
        opsAssign: 'تخصيص',
        opsAssigning: 'جارٍ التخصيص...',
        opsAssigned: 'تم تخصيص المسكن {0} إلى {1}',
        opsReserveStock: 'مخزون محجوز',
        opsTabAssigned: 'مخصصة',
        opsTabAvailable: 'متاحة للتخصيص',
        opsColCluster: 'المجمع',
        opsColType: 'النوع',
        opsColBeds: 'الغرف',
        opsColPrice: 'السعر',
        opsAssignThis: 'تخصيص',
        opsStockEmpty: 'لا توجد مساكن محجوزة متاحة للتخصيص',
        opsFreeCount: 'متاحة للتخصيص ({0})',
        opsReservedBy: 'محجوز لصالح',
        opsUnpinned: 'تمت إزالة التخصيص من المسكن {0}',
        opsPinnedToName: 'مخصص إلى {0}',
        opsPinnedBadge: 'مخصص',
        opsNotAssignable: 'غير قابل للتخصيص',
        opsTagReserved: 'حجز نشط',
        opsTagExpired: 'منتهي الصلاحية',
        opsChangeApplicant: 'تغيير',
        opsBoardEmpty: 'لا توجد مساكن مخصصة بعد',
        opsTapVilla: 'اضغط على مسكن في المخطط لتخصيصه.',
        opsEnlarge: 'عرض اللوحة الكاملة',
        opsCountPinned: 'المخصصة',
        opsColApplicant: 'المتعامل',
        opsColVilla: 'المسكن',
        opsColPinnedOn: 'تاريخ التخصيص',
        opsColDays: 'أيام الانتظار',
        opsColStatus: 'الحالة',
        opsJump: 'عرض على المخطط',
        opsLegendReserve: 'متاحة للتخصيص',
        opsLegendPinned: 'مخصص',
        opsReserveMissing: 'تعذر تحميل المخزون المحجوز. يرجى إعادة تحميل الصفحة.',
        closeFilters: 'إغلاق معايير البحث',
        clearAll: 'مسح الكل',
        zoomIn: 'تكبير',
        zoomOut: 'تصغير',
        baseRealistic: 'واقعي',
        basePlan: 'المخطط',
        baseRealisticTitle: 'عرض توضيحي',
        basePlanTitle: 'المخطط المساحي يتضمن أرقام القطع وأسماء الشوارع',
        yourVilla: 'مسكنك',

        /* ---------- map: status line ---------- */
        loadingUnits: 'جارٍ تحميل بيانات الوحدات...',
        loadingImage: 'جارٍ تحميل صورة المخطط الرئيسي...',
        loadingMapped: 'جارٍ تحميل الوحدات المحددة على المخطط...',
        statusFiltered: '{0} من {1} وحدة مطابقة لعوامل البحث.',
        statusAll: '{0} وحدة في {1} مجموعة سكنية.',
        statusEligible: '{0} من {1} وحدة متاحة لك ضمن {2}.',
        statusClusters: 'تتوفر {0} مجموعة سكنية - اضغط على إحدى المجموعات للمزيد من التفاصيل.',
        statusViewing: 'يتم عرض منطقة {0} - تظل جميع الوحدات متاحة للاختيار.',
        clusterOne: 'مجموعة سكنية واحدة',
        clusterMany: '{0} مجموعة سكنية',
        cluster: 'مجموعة {0}',
        clusterAvailable: '{0} متاحة',
        clusterAssignable: '{0} للتخصيص',
        continuingToReservation: 'القطعة {0} - جارٍ الانتقال إلى إجراءات الحجز.',

        /* ---------- map: unit card and explore ---------- */
        selectedUnit: 'الوحدة المختارة',
        close: 'إغلاق',
        explore: 'استكشاف',
        type: 'النوع',
        bedrooms: 'غرف النوم',
        gsa: 'المساحة الإجمالية',
        plotArea: 'مساحة القطعة',
        aed: 'درهم',
        totalPrice: 'السعر الإجمالي',
        extraToPay: 'المبلغ الإضافي المستحق',
        sqft: 'قدم مربع',
        sqm: 'متر مربع',
        provisionalNote: 'مخطط التوزيع مبدئي، وبانتظار التأكيد من هيئة أبوظبي للإسكان',
        continueWithUnit: 'المتابعة بهذا المسكن',
        reservationsClosedCta: 'سيتم فتح باب الحجز قريباً',
        backToCommunity: 'العودة إلى المشروع',
        floor: 'الطابق',
        floorPlan: 'مخطط الطابق',
        exterior: 'المنظر الخارجي',
        interior: 'المنظر الداخلي',
        /* MODON's walkthrough films, 24 Aug. The Arabic is ours, NOT approved by Comms or ADHA;
           it is on the Comms copy pack. */
        walkthrough: 'جولة بالفيديو',
        walkthroughPlay: 'تشغيل الجولة',
        awaitingAsset: 'بانتظار المواد المعتمدة من هيئة أبوظبي للإسكان للمساكن {0}',
        /* The renders show the villa TYPE, so this must not read as a photo of the plot being
           booked. suppliedPlan is Comms wording, supplied English only - that Arabic is MODON's. */
        suppliedAsset: 'صورة توضيحية للمساكن {0}، ولا تمثل هذه القسيمة تحديداً',
        suppliedPlan: 'مخطط الطابق لأغراض التوضيح فقط',
        heroAlt: 'المركز المجتمعي في مشروع غرب بني ياس السكني',
        loadingMedia: 'جارٍ تحميل الصورة',
        nextImage: 'الصورة التالية',
        prevImage: 'الصورة السابقة',
        imageCount: '{0} / {1}',
        // Interior gallery room names, normalised by the manifest from MODON's English filenames.
        // The Arabic has NOT been confirmed by ADHA - flag with the declaration before go-live.
        roomNumbered: '{0} {1}',
        roomMajlis: 'مجلس',
        roomLadiesMajlis: 'مجلس السيدات',
        roomLivingMajlis: 'غرفة المعيشة ومجلس السيدات',
        roomLiving: 'غرفة المعيشة',
        roomDining: 'غرفة الطعام',
        roomKitchen: 'المطبخ',
        roomLounge: 'صالة',
        roomLoungeHall: 'الصالة والممر',
        roomUpperLounge: 'صالة الطابق العلوي',
        roomStair: 'الدرج',
        roomMasterBedroom: 'غرفة النوم الرئيسية',
        roomBedroom: 'غرفة نوم',
        roomGuestBedroom: 'غرفة نوم الضيوف',
        roomMasterBathroom: 'الحمام الرئيسي',
        roomBathroom: 'حمام',
        roomPowderRoom: 'دورة مياه الضيوف',
        altexterior: 'المنظر الخارجي للمسكن {0}',
        altinterior: 'المنظر الداخلي للمسكن {0}',
        altfloorplan: 'مخطط طابق المسكن {0}',

        /* ---------- map: facets and amenities ---------- */
        amenities: 'المرافق',
        mapKey: 'الدليل',
        hidePanel: 'إخفاء',
        facetProduct: 'المساكن',
        // Two already-translated pieces joined, never a sentence: the style comes from PICKLISTS
        // and the bedroom count from countBedrooms, so neither language needs plural morphology.
        productRow: '{0} · {1}',
        facetBedrooms: 'غرف النوم',
        facetLocation: 'الموقع',
        facetStyle: 'الطراز',
        facetPosition: 'موقع القطعة',
        facetBalconies: 'الشرفات',
        // Label-plus-value, deliberately: Arabic has six plural forms and no interpolated count
        // phrasing can be translated correctly.
        countBedrooms: 'غرف النوم: {0}',
        countBalconies: 'الشرفات: {0}',
        amenityPark: 'الحدائق',
        amenitySchool: 'المدارس',
        amenityMosque: 'المساجد',
        amenityRetail: 'المتاجر',
        amenityClinic: 'العيادة',
        amenityCommunity: 'المرافق المجتمعية',
        amenityParking: 'مواقف السيارات',

        /* A chip names a filter, so plural; a pin names one building, so singular.
           THE ARABIC HERE IS NOT ADHA'S, same flag as the rest. */
        pinPark: 'حديقة',
        pinSchool: 'مدرسة',
        pinMosque: 'مسجد',
        pinRetail: 'متجر',
        pinClinic: 'عيادة',
        pinCommunity: 'مرفق مجتمعي',
        pinParking: 'موقف سيارات',

        /* ---------- explore: drawn villa plans ----------
           Room names for the generated floor plans in villaArt.js. Layout indicative, not ADHA's. */
        rMajlis: 'المجلس',
        rFamily: 'صالة المعيشة العائلية ومنطقة الطعام',
        rKitchen: 'المطبخ',
        rPrep: 'مطبخ التحضير',
        rHall: 'الردهة/البهو',
        rBed: 'غرفة نوم',
        rGarage: 'المرآب',
        rMaster: 'غرفة النوم الرئيسية',
        rLaundry: 'غرفة الغسيل',
        rStair: 'الدرج',
        rPlant: 'غرفة معدات التكييف',
        rTanks: 'خزانات المياه',
        indicativePlan: 'مخطط توضيحي - بانتظار المخططات المعتمدة من الهيئة لـ {0}'
    },

    en: {
        authority: 'Abu Dhabi Housing Authority',
        project: 'West Baniyas',
        sessionEnded: 'Session ended',
        signInAgain: 'Sign in again',
        lockSupersededTitle: 'Signed in on another device',
        lockIdleTitle: 'Signed out',
        lockSuperseded:
            'This window was signed out because your Emirates ID was used to sign in somewhere else. Only one session can be open at a time.',
        lockIdle:
            'You were signed out after 5 minutes due to inactivity. Your 7-day reservation window is unaffected.',
        lockSignedOutTitle: 'Signed out',
        lockSignedOut: 'You have been signed out. Your 7-day reservation window is unaffected.',

        /* ---------- sign out ---------- See the ar block for why there are three bodies. */
        signOut: 'Sign out',
        signOutTitle: 'Sign out?',
        signOutBodyPlain:
            'You will need your Emirates ID and a new verification code to sign back in.',
        signOutBodyHeld:
            'Villa {0} is held for a few more minutes only. Signing out releases it and another applicant may take it. You will need your Emirates ID and a new verification code to sign back in.',
        signOutBodyReserved:
            'Villa {0} stays reserved and your 7-day window is unaffected. You will need your Emirates ID and a new verification code to sign back in.',
        confirmSignOut: 'Yes, sign out',

        /* ---------- exploration mode ---------- See the ar block. */
        noticeTitle: 'Important Notice',
        noticeFullP1:
            'The current phase is dedicated to viewing the project and exploring the available residential units and does not constitute a reservation phase.',
        noticeFullP2:
            'The selection and reservation phase will open next Wednesday, in batches, based on the service type, financial eligibility, and family proximity. You will be notified of your designated reservation time via SMS.',
        noticeFullP3:
            'Please note that the residential units displayed to you are based on your eligibility and cannot be changed. We also advise you, during the viewing phase, to shortlist more than one preferred option in preparation for the reservation phase.',
        noticeMore: 'More',
        noticeLess: 'Less',
        noticeShort:
            'The current phase is for viewing only and not for reservation. The selection and reservation phase will open next Wednesday in batches, and your reservation time will be shared via SMS. Units shown are based on eligibility and cannot be changed. We recommend selecting more than one preferred option.',

        welcomeLede: 'Choose and reserve your home at West Baniyas.',
        whatYouNeed: 'What you will need?',
        whatYouNeedBody:
            'You have been invited to select your home at West Baniyas. Sign in with your Emirates ID to see which villas you are eligible for.',
        step1: 'Verify your Emirates ID',
        step2: 'Review and accept the declaration',
        step3: 'Explore the project and choose your villa',
        welcomeNotice:
            'You have 7 days from your first sign-in to complete your reservation. Once you have signed in, time will start to run out. Only sign in when you are ready.',
        begin: 'Start',

        /* ---------- arrival: the six renders beside the form ---------- See the ar block. */
        slideHeritage: 'Andalusian elevation',
        slideLiving: 'Double-height living',
        slideModern: 'Modern elevation',
        slideDining: 'Dining',
        slideBedroom: 'Master bedroom',
        slideStreet: 'Streetscape',
        back: 'Back',
        changeEmiratesId: 'Change Emirates ID',
        retry: 'Try again',
        stepOneOfFour: 'Step 1 of 4',
        stepTwoOfFour: 'Step 2 of 4',
        verifyIdentity: 'Verify your identity',
        loginLede:
            'Enter the Emirates ID linked to your housing application. We will send a verification code to the mobile number registered with ADHA.',
        emiratesId: 'Emirates ID',
        sendCode: 'Send verification code',
        enterCode: 'Enter your code',
        sentTo: 'Sent to {0}',
        verificationCode: 'Verification code',
        verifyContinue: 'Verify and continue',
        resendCode: 'Resend code',
        resendIn: 'Resend in {0}s',

        generalDeclaration: 'General declaration',
        applicationNo: 'application {0}',
        daysLeft: '{0} days left',
        oneDayLeft: '1 day left',
        declarationPlaceholder:
            'Placeholder text - the approved declaration has not yet been supplied by ADHA. Not for production use.',
        declarationRead: 'You have read the full declaration.',
        declarationScroll: 'Scroll to the end to continue.',
        acceptContinue: 'Accept and continue',

        stepFourOfFour: 'Step 4 of 4',
        financeTitle: 'Additional amount',
        financeLede: 'This villa costs more than the amount ADHA approved for you. Choose your alternative payment option.',
        fPrice: 'Villa price',
        fApproved: 'Approved by ADHA',
        fExtra: 'Additional amount due',
        fMethod: 'How you will pay',
        pmUpfront: 'Pay the full amount upfront',
        pmPlan: 'Pay in monthly instalments',
        pmPartialPlan: 'Pay part now, the rest in instalments',
        pmPartialPlanTopUp: 'Pay part now, instalments, and top-up finance',
        pmTopUp: 'Top-up finance from a partner bank',
        noteRefund: 'If your housing loan approval is rejected, ADHA will instruct a refund of what you have paid.',
        noteCapped: 'The account accepts only the additional amount shown above. Anything paid beyond it is refunded to you.',
        noteTopUpDeclined: 'If the partner bank declines your final offer letter, ADHA will ask you to deposit the difference in cash or move to a payment plan. The additional amount must be paid within a maximum of three (3) months from the date the selection is confirmed.',
        continueLabel: 'Continue',
        undertakingTitle: 'Loan undertaking',
        undertakingLede: 'Read and accept the full undertaking below to complete the reservation of villa {0}.',
        signContinue: 'Accept and confirm reservation',
        loadingUndertaking: 'Loading the undertaking...',
        loadingJourney: 'Restoring your session...',
        doneTitle: 'Your reservation is confirmed',
        doneLede: 'Villa {0} is reserved.',
        donePendingTitle: 'Sign to confirm your reservation',
        donePendingLede:
            'Villa {0} is held for you. Your reservation is confirmed once you sign the undertaking.',
        refLabel: 'Reference',
        factAmend: 'Amend until',
        factDue: 'Amount due',
        deadlineReservation: 'Amend your reservation until',
        deadlinePayment: 'Additional amount due within three (3) months from the date the selection is confirmed.',
        signingToFollow: 'The last step is to sign your undertaking electronically. You sign it here, and nothing is emailed to you.',
        signHeading: 'Sign your undertaking',
        signBody: 'The secure signing page opens, and you come straight back here when it is done. The document is in both Arabic and English.',
        signCta: 'Continue to signing',
        signOpening: 'Preparing your document…',
        signChecking: 'Checking your signature…',
        signedHeading: 'Your undertaking is signed',
        signedBody: 'Your reservation is complete. A signed copy is held with your reservation.',
        downloadUndertaking: 'Download the undertaking',
        downloadSigned: 'Download the signed copy',
        downloadWorking: 'Preparing…',
        downloadFailed: 'We could not download the file just now. Please try again.',
        signNotFinished: 'Signing was not finished. You can continue and sign now.',
        signDeclined: 'The signature was declined. Please contact ADHA.',
        MSG_SIGNING_FAILED: 'We could not open the signing page. Your reservation is safe. Please try again, and contact ADHA if it keeps happening.',
        changeVilla: 'Change villa',
        reservedShort: 'Villa {0} is yours',
        heldForYou: 'Confirm your reservation within {0}',
        holdEndingSoon: 'Two minutes left on your hold.',
        holdLapsed: 'Your hold has lapsed. You can still confirm if nobody else has taken it.',
        chooseAnother: 'Choose another villa',
        details: 'Details',
        backToMap: 'Back to the community',
        changeVillaWarn:
            'This releases villa {0} and you will need to read and accept the undertaking again. Your 7-day window does not restart.',
        changeVillaFinal: 'This is your final opportunity of {0}.',
        confirmChange: 'Yes, change villa',
        cancel: 'Cancel',
        checkingVilla: 'Checking this villa...',
        unitUnavailable: 'This villa is not available',
        unitAlreadyYours: 'This villa is already yours',
        imageFailed: 'The masterplan image could not be loaded.',
        searchNotRendered: 'The requested unit is not currently rendered.',
        searchJumped: 'Jumped to plot {0}.',
        // One answer for every failed search - taken, out of category, filtered out or a typo.
        // Never says the villa does not exist: most of the time it does.
        searchUnavailable: 'Villa {0} is not available.',
        nothingEligibleTitle: 'No villas are available for your application yet',
        nothingEligibleBody:
            'There are currently no villas matching the category and service type on your application. Please contact the Abu Dhabi Housing Authority.',

        stillThere: 'Still there?',
        idleWarning:
            'You will be signed out in {0} seconds. Your 7-day reservation window is not affected.',
        staySignedIn: 'Stay signed in',

        MSG_ENTER_EID: 'Please enter your Emirates ID.',
        MSG_EID_UNVERIFIED: 'We could not verify this Emirates ID. Please check it and try again.',
        MSG_ENTER_OTP: 'Please enter the code sent to your mobile.',
        MSG_CODE_RESENT: 'A new code has been sent.',
        MSG_GENERIC: 'Something went wrong. Please try again.',
        MSG_START:
            'If this Emirates ID is registered for this project, a verification code has been sent to the mobile number registered with ADHA.',
        MSG_SESSION_EXPIRED: 'Your session has ended. Please sign in again.',
        MSG_OTP_INVALID: 'Invalid verification code.',
        MSG_OTP_MAX_ATTEMPTS: 'Maximum verification attempts reached.',
        MSG_OTP_MAX_RESEND: 'Maximum resend count reached.',
        MSG_OTP_TOO_SOON: 'Please wait before requesting another verification code.',

        MSG_UNIT_TAKEN: 'This villa has just been reserved by another applicant. Please choose another.',
        MSG_ALREADY_HELD: 'You already hold a villa. Change your selection to choose a different one.',
        MSG_NOT_ELIGIBLE: 'This villa is not available for your application.',
        MSG_WINDOW_CLOSED: 'Your 7-day selection period has ended.',
        MSG_ATTEMPTS_SPENT: 'You have used both of your selection opportunities.',
        MSG_CHANGES_SPENT: 'You have used all of your villa changes.',
        MSG_PAYMENT_METHOD: 'Please choose how you will pay the additional amount.',
        MSG_RESERVATIONS_CLOSED:
            'Reservations are not open yet. You can explore the community now and choose your home when reservations open.',

        searchPlaceholder: 'Number or ID (WB4_03-405)',
        searchAria: 'Search by number or ID',
        search: 'Search',
        filters: 'Filters',
        filtersCount: 'Filters ({0})',

        /* ---------- Pinning ---------- */
        pinnedBanner: 'Villa {0} has been set aside for you. It is the only villa you can book.',
        MSG_PIN_CONFLICT: 'This villa is already pinned to another applicant.',
        opsTitle: 'Pin mode',
        opsSearch: 'Search by application number or name',
        opsNoResults: 'No results',
        opsLoan: 'Approved loan',
        opsCategory: 'Category',
        opsService: 'Service type',
        opsPin: 'Pin this villa',
        opsUnpin: 'Remove pin',
        opsUnpinConfirm: 'Confirm removing this pin',
        opsPinnedTo: 'Pinned to',
        opsSelectApplicant: 'Choose an applicant first, then tap a villa on the plan.',
        opsWarnCategory: 'Warning: category does not match',
        opsWarnService: 'Warning: service type does not match',
        opsWarnPrice: 'Warning: price exceeds the approved loan',
        opsStatusWaiting: 'Waiting',
        opsStatusBooked: 'Booked',
        opsStatusSigned: 'Signed',
        opsStatusBlocked: 'Blocked',
        opsBoardTitle: 'Pinned villas',
        /* Later additions. */
        MSG_PIN_ALREADY_PINNED: 'This applicant is already pinned to another villa. Unpin that villa first.',
        MSG_PIN_HAS_RESERVATION: 'This applicant already has an active reservation and cannot be pinned.',
        opsAssign: 'Assign',
        opsAssigning: 'Assigning...',
        opsAssigned: 'Villa {0} pinned to {1}',
        opsUnpinned: 'Pin removed from villa {0}',
        opsPinnedToName: 'Pinned to {0}',
        opsPinnedBadge: 'Pinned',
        opsNotAssignable: 'Not assignable',
        opsTagReserved: 'Active reservation',
        opsTagExpired: 'Expired',
        opsChangeApplicant: 'Change',
        opsReserveStock: 'Reserve stock',
        opsTabAssigned: 'Assigned',
        opsTabAvailable: 'Available to assign',
        opsColCluster: 'Cluster',
        opsColType: 'Type',
        opsColBeds: 'Beds',
        opsColPrice: 'Price',
        opsAssignThis: 'Assign',
        opsStockEmpty: 'No reserve villas are free to assign',
        opsFreeCount: 'Available to assign ({0})',
        opsReservedBy: 'Booked by',
        opsBoardEmpty: 'No pinned villas yet',
        opsTapVilla: 'Tap a villa on the plan to assign it.',
        opsEnlarge: 'Open full board',
        opsCountPinned: 'Pinned',
        opsColApplicant: 'Applicant',
        opsColVilla: 'Villa',
        opsColPinnedOn: 'Pinned on',
        opsColDays: 'Days waiting',
        opsColStatus: 'Status',
        opsJump: 'Show on map',
        opsLegendReserve: 'Available to assign',
        opsLegendPinned: 'Pinned',
        opsReserveMissing: 'Reserve stock did not load. Reload the page.',
        closeFilters: 'Close filters',
        clearAll: 'Clear all',
        zoomIn: 'Zoom in',
        zoomOut: 'Zoom out',
        baseRealistic: 'Realistic',
        basePlan: 'Plan',
        baseRealisticTitle: 'Illustrated view',
        basePlanTitle: 'Survey drawing, with plot numbers and street names',
        yourVilla: 'Your villa',

        loadingUnits: 'Loading unit data...',
        loadingImage: 'Loading masterplan image...',
        loadingMapped: 'Loading mapped units...',
        statusFiltered: '{0} of {1} units match your filters.',
        statusAll: '{0} units across {1} clusters.',
        statusEligible: '{0} of {1} units available to you, in {2}.',
        statusClusters: '{0} clusters available - click a cluster to zoom into its area',
        statusViewing: 'Viewing {0} area - all units remain active',
        clusterOne: '1 cluster',
        clusterMany: '{0} clusters',
        cluster: 'Cluster {0}',
        clusterAvailable: '{0} available',
        clusterAssignable: '{0} to assign',
        continuingToReservation: 'Plot {0} - continuing to the reservation journey.',

        selectedUnit: 'Selected unit',
        close: 'Close',
        explore: 'Explore',
        type: 'Type',
        bedrooms: 'Bedrooms',
        gsa: 'GSA',
        plotArea: 'Plot area',
        aed: 'AED',
        totalPrice: 'Total price',
        extraToPay: 'Additional amount payable',
        sqft: 'sqft',
        sqm: 'sqm',
        provisionalNote: 'Plot mapping provisional - pending ADHA confirmation',
        continueWithUnit: 'Continue with this unit',
        reservationsClosedCta: 'Reservations open soon',
        backToCommunity: 'Back to community',
        floor: 'Floor',
        floorPlan: 'Floor Plan',
        exterior: 'Exterior',
        interior: 'Interior',
        walkthrough: 'Walkthrough',
        walkthroughPlay: 'Play the walkthrough',
        awaitingAsset: 'Awaiting ADHA asset for {0} villas',
        suppliedAsset: 'Representative of {0} villas, not this specific plot',
        /* Comms wording, 21 Aug. Floor-plan tab only: the caption above also sits over exterior
           and interior photographs, which this would miscall a floor plan. */
        suppliedPlan: 'Floor plan for representation purposes only',
        heroAlt: 'The community centre at West Baniyas Housing Project',
        loadingMedia: 'Loading image',
        nextImage: 'Next image',
        prevImage: 'Previous image',
        imageCount: '{0} / {1}',
        roomNumbered: '{0} {1}',
        roomMajlis: 'Majlis',
        roomLadiesMajlis: 'Ladies Majlis',
        roomLivingMajlis: 'Living and Ladies Majlis',
        roomLiving: 'Living',
        roomDining: 'Dining',
        roomKitchen: 'Kitchen',
        roomLounge: 'Lounge',
        roomLoungeHall: 'Lounge and Hallway',
        roomUpperLounge: 'Upper Lounge',
        roomStair: 'Stairs',
        roomMasterBedroom: 'Master Bedroom',
        roomBedroom: 'Bedroom',
        roomGuestBedroom: 'Guest Bedroom',
        roomMasterBathroom: 'Master Bathroom',
        roomBathroom: 'Bathroom',
        roomPowderRoom: 'Powder Room',
        altexterior: 'Exterior view of a {0} villa',
        altinterior: 'Interior view of a {0} villa',
        altfloorplan: 'Floor plan for a {0} villa',

        // The map toolbar. Search, filters and close are shared with the panels they open.
        amenities: 'Amenities',
        mapKey: 'Key',
        hidePanel: 'Hide',
        facetProduct: 'Villas',
        productRow: '{0} · {1}',
        facetBedrooms: 'Bedrooms',
        facetLocation: 'Location',
        facetStyle: 'Style',
        facetPosition: 'Plot position',
        facetBalconies: 'Balconies',
        countBedrooms: 'Bedrooms: {0}',
        countBalconies: 'Balconies: {0}',
        amenityPark: 'Parks',
        amenitySchool: 'Schools',
        amenityMosque: 'Mosques',
        amenityRetail: 'Retail',
        amenityClinic: 'Clinic',
        amenityCommunity: 'Community',
        amenityParking: 'Parking',

        /* Singular: the chip names a filter, a pin names one building. See the ar block. */
        pinPark: 'Park',
        pinSchool: 'School',
        pinMosque: 'Mosque',
        pinRetail: 'Retail',
        pinClinic: 'Clinic',
        pinCommunity: 'Community',
        pinParking: 'Parking',

        rMajlis: 'Majlis',
        rFamily: 'Family living and dining',
        rKitchen: 'Kitchen',
        rPrep: 'Prep kitchen',
        rHall: 'Hall',
        rBed: 'Bedroom',
        rGarage: 'Garage',
        rMaster: 'Master bedroom',
        rLaundry: 'Laundry',
        rStair: 'Stair',
        rPlant: 'AC plant',
        rTanks: 'Water tanks',
        indicativePlan: 'Indicative layout - awaiting ADHA\u2019s approved plans for {0}'
    }
};

/**
 * ADHA_Unit__c picklist values keyed on the English API value Apex returns; stands in for
 * objectTranslations/ADHA_Unit__c-ar until Translation Workbench is enabled - see the header.
 */
const PICKLISTS = {
    ar: {
        Available: 'متاح',
        Unavailable: 'غير متاح',
        Reserved: 'محجوز',
        Sold: 'مباع',
        Blocked: 'غير متاح',
        Modern: 'عصري',
        Heritage: 'أندلسي',
        'Double row middle': 'صف مزدوج - وسط',
        'Double row community': 'صف مزدوج - مجتمعي',
        'Double row corner': 'صف مزدوج - زاوية',
        'Internal single row middle': 'صف مفرد داخلي - وسط',
        'Internal single row community': 'صف مفرد داخلي - مجتمعي',
        'Internal single row corner': 'صف مفرد داخلي - زاوية',
        Utilities: 'مرافق',
        'House Purchase Loan': 'قرض شراء مسكن',
        'House Purchase Deferred Loan': 'قرض شراء مسكن آجل السداد',
        'House Grant': 'منحة مسكن'
    },
    /* The API value stays Heritage - ADHA's own inventory feed still sends it, and 824 unit
       records carry it - so the rename is display only, in both languages. */
    en: {
        Heritage: 'Andalusian'
    }
};

/** Resolve a key, substituting {0}, {1}… positionally. Falls back to the key so a missing
 *  translation is visible in testing rather than rendering as an empty element. */
export function t(lang, key, ...args) {
    const table = STRINGS[lang] || STRINGS[DEFAULT_LANG];
    let out = table[key];
    if (out === undefined) {
        out = (STRINGS.en && STRINGS.en[key]) || key;
    }
    for (let i = 0; i < args.length; i++) {
        out = out.split(`{${i}}`).join(String(args[i]));
    }
    return out;
}

/** Translate a picklist value coming from data. Unknown values pass through unchanged, so a new
 *  picklist entry degrades to English rather than disappearing. */
/**
 * Every string for a language as one object for template binding, derived from the table so no
 * hand-written key list can be forgotten; {0} placeholders come back unsubstituted.
 */
const RESOLVED = {};

export function allLabels(lang) {
    const key = STRINGS[lang] ? lang : DEFAULT_LANG;
    if (!RESOLVED[key]) {
        const out = {};
        Object.keys(STRINGS[key]).forEach((k) => {
            out[k] = STRINGS[key][k];
        });
        RESOLVED[key] = out;
    }
    return RESOLVED[key];
}

export function pick(lang, value) {
    if (value == null || value === '') {
        return value;
    }
    const table = PICKLISTS[lang];
    return (table && table[value]) || value;
}

/**
 * Arabic-Indic and Eastern Arabic-Indic digits to ASCII: JS `\d` is ASCII-only and Number('٤٠٥')
 * is NaN, so Arabic-Indic input into the plot search, EID or OTP fields fails silently.
 */
export function toLatinDigits(value) {
    if (!value) {
        return value;
    }
    return String(value).replace(/[٠-٩۰-۹]/g, (d) => {
        const c = d.charCodeAt(0);
        return String(c >= 0x06f0 ? c - 0x06f0 : c - 0x0660);
    });
}

/** Latin digits and grouping regardless of the UI language - see the header note on digits. */
export function num(value, opts) {
    return Number(value).toLocaleString('en-US', opts);
}