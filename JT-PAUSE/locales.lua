Locales = {}

Locales['en'] = {
    -- navigation
    group_menu = 'Menu', group_game = 'Game',
    nav_overview = 'Overview', nav_updates = 'Updates', nav_audio = 'Audio',
    nav_map = 'World Map', nav_settings = 'Settings', nav_resume = 'Resume', nav_quit = 'Quit Game',
    new = 'NEW',

    -- hero / status
    players_online = 'Players Online', police = 'Police', ems = 'EMS',
    active = 'Active', inactive = 'Inactive', on_duty = 'On duty', off_duty = 'Off duty',
    server_id = 'ID', citizen_id = 'Citizen ID',

    -- overview
    robbery_eyebrow = 'Underground Activity', robbery_title = 'Robbery Status',
    available = 'Available', unavailable = 'Unavailable', x_available = '{n} of {t} available',
    requires = 'Requires {n} officers',
    character = 'Character', job = 'Job', gang = 'Gang', cash = 'Cash', bank = 'Bank', none = 'None',

    -- updates
    updates_eyebrow = 'Server Changelog', updates_title = 'Updates', latest = 'LATEST',
    added_section = 'New Features & Additions', changed_section = 'Fixes & Changes',
    no_updates = 'No updates have been published yet.',
    publish = 'Publish', delete = 'Delete', confirm_delete = 'Confirm?',

    -- audio
    audio_eyebrow = 'Preferences', audio_title = 'Audio & Interface', reset = 'Reset',
    volume_section = 'Volume',
    sfx = 'Game Sounds', sfx_desc = 'Weapons, vehicles, world and voices',
    music = 'Music', music_desc = 'Score and ambient music',
    game_audio_section = 'Game Audio',
    radio = 'Vehicle Radio', radio_desc = 'Radio stations inside vehicles',
    scanner = 'Police Scanner', scanner_desc = 'Dispatch voice on the radio',
    sirens = 'Distant Sirens', sirens_desc = 'Ambient police sirens in the city',
    flight_music = 'Flight Music', flight_music_desc = 'Music while flying aircraft',
    wanted_music = 'Wanted Music', wanted_music_desc = 'Music during police chases',
    interface_section = 'Interface',
    ui_sounds = 'Menu Sounds', ui_sounds_desc = 'Clicks and transitions in this menu',
    blur = 'Background Blur', blur_desc = 'Blur the game behind the menu',
    reduced_motion = 'Reduced Motion', reduced_motion_desc = 'Lighter, faster animations',

    -- modals
    quit_title = 'Disconnect From Server',
    quit_text = 'Are you sure you want to leave the server? Any unsaved character actions will end.',
    cancel = 'Cancel', disconnect = 'Disconnect',
    publish_title = 'Publish Server Update',
    f_version = 'Version', f_version_ph = 'e.g. v1.1.0',
    f_title = 'Update Title', f_title_ph = 'e.g. Heists & Bug Fixes',
    f_added = 'Added Features (one per line)', f_added_ph = 'Added new vehicle dealership',
    f_changed = 'Fixes / Changes (one per line)', f_changed_ph = 'Fixed inventory duplication',
    publish_btn = 'Publish Update', required = 'Version and title are required',

    -- footer
    hint_resume = 'Resume', hint_navigate = 'Navigate', hint_select = 'Select', hint_back = 'Back',

    -- toasts / notifications
    toast_published = 'Update published', toast_deleted = 'Update deleted',
    toast_reset = 'Audio settings reset', toast_copied = 'Link copied',
    no_permission = 'You do not have permission to do that.',
    cmd_update_help = 'Publish a server update (admins)',
}

Locales['ar'] = {
    group_menu = 'القائمة', group_game = 'اللعبة',
    nav_overview = 'الرئيسية', nav_updates = 'التحديثات', nav_audio = 'الصوت',
    nav_map = 'الخريطة', nav_settings = 'الإعدادات', nav_resume = 'استئناف', nav_quit = 'خروج',
    new = 'جديد',

    players_online = 'لاعب متصل', police = 'الشرطة', ems = 'الإسعاف',
    active = 'متواجد', inactive = 'غير متواجد', on_duty = 'على رأس العمل', off_duty = 'خارج الدوام',
    server_id = 'الآيدي', citizen_id = 'رقم المواطن',

    robbery_eyebrow = 'النشاط الإجرامي', robbery_title = 'حالة السرقات',
    available = 'متاحة', unavailable = 'غير متاحة', x_available = '{n} من {t} متاحة',
    requires = 'تحتاج {n} عساكر',
    character = 'الشخصية', job = 'الوظيفة', gang = 'العصابة', cash = 'الكاش', bank = 'البنك', none = 'لا يوجد',

    updates_eyebrow = 'سجل السيرفر', updates_title = 'التحديثات', latest = 'الأحدث',
    added_section = 'إضافات جديدة', changed_section = 'إصلاحات وتعديلات',
    no_updates = 'ما فيه تحديثات منشورة للحين.',
    publish = 'نشر', delete = 'حذف', confirm_delete = 'متأكد؟',

    audio_eyebrow = 'التفضيلات', audio_title = 'الصوت والواجهة', reset = 'استعادة',
    volume_section = 'مستوى الصوت',
    sfx = 'أصوات اللعبة', sfx_desc = 'الأسلحة، السيارات، العالم والأصوات',
    music = 'الموسيقى', music_desc = 'موسيقى اللعبة والخلفية',
    game_audio_section = 'أصوات اللعبة',
    radio = 'راديو السيارة', radio_desc = 'محطات الراديو داخل المركبات',
    scanner = 'لاسلكي الشرطة', scanner_desc = 'صوت البلاغات في الراديو',
    sirens = 'السارينات البعيدة', sirens_desc = 'سارينات الشرطة في المدينة',
    flight_music = 'موسيقى الطيران', flight_music_desc = 'الموسيقى أثناء قيادة الطائرات',
    wanted_music = 'موسيقى المطاردة', wanted_music_desc = 'الموسيقى أثناء مطاردات الشرطة',
    interface_section = 'الواجهة',
    ui_sounds = 'أصوات القائمة', ui_sounds_desc = 'نقرات وانتقالات هذه القائمة',
    blur = 'تغبيش الخلفية', blur_desc = 'تغبيش اللعبة خلف القائمة',
    reduced_motion = 'تقليل الحركة', reduced_motion_desc = 'أنيميشن أخف وأسرع',

    quit_title = 'الخروج من السيرفر',
    quit_text = 'متأكد إنك تبي تطلع من السيرفر؟ أي شي ما انحفظ في شخصيتك بيروح.',
    cancel = 'إلغاء', disconnect = 'خروج',
    publish_title = 'نشر تحديث للسيرفر',
    f_version = 'رقم الإصدار', f_version_ph = 'مثال: v1.1.0',
    f_title = 'عنوان التحديث', f_title_ph = 'مثال: سرقات جديدة وإصلاحات',
    f_added = 'الإضافات (كل سطر عنصر)', f_added_ph = 'إضافة معرض سيارات جديد',
    f_changed = 'الإصلاحات / التعديلات (كل سطر عنصر)', f_changed_ph = 'إصلاح تكرار الأغراض',
    publish_btn = 'نشر التحديث', required = 'رقم الإصدار والعنوان مطلوبة',

    hint_resume = 'استئناف', hint_navigate = 'تنقّل', hint_select = 'اختيار', hint_back = 'رجوع',

    toast_published = 'تم نشر التحديث', toast_deleted = 'تم حذف التحديث',
    toast_reset = 'تمت استعادة إعدادات الصوت', toast_copied = 'تم نسخ الرابط',
    no_permission = 'ما عندك صلاحية لهذا الأمر.',
    cmd_update_help = 'نشر تحديث للسيرفر (للإدارة)',
}

-- Returns the active language table with English as a fallback for missing keys.
function GetLocale()
    local selected = Locales[Config.Locale] or Locales['en']
    if selected == Locales['en'] then return selected end
    return setmetatable(selected, { __index = Locales['en'] })
end

-- Picks the right language from a string or an { en = '', ar = '' } table.
function LocalizeValue(value)
    if type(value) == 'table' then
        return value[Config.Locale] or value['en'] or ''
    end
    return value ~= nil and tostring(value) or ''
end
