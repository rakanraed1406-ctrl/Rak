// ============================================================================
//  JT loading screen — settings (change everything here)
// ============================================================================
var LoadConfig = {
    // Title: "first" is drawn in blue, "second" in white
    welcome: 'WELCOME TO',
    title: { first: 'Jinxed', second: 'Town' },
    tagline: 'Roleplay · Community · Story',
    logo: 'JT',                               // the two letters in the logo mark (top left)

    // Links shown top right (just text, the player reads them)
    socials: [
        { label: 'DISCORD', value: 'discord.gg/JT' },
        // { label: 'STORE', value: 'store.example.com' },
    ],

    // Team cards
    team: [
        { name: 'Rko', role: 'DEV', image: '' },   // image: 'assets/rko.png' (optional)
        // { name: 'Name', role: 'ADMIN', image: '' },
    ],

    // Tips that rotate under the title (every tipSeconds)
    tipSeconds: 7,
    tips: [
        'اضغط F1 عشان تفتح القائمة ',
        'احترم القوانين واستمتع بالرول بلاي',
        'تقدر تجرّب السيارة بالمعرض قبل لا تشتريها — زر G',
        'اقرأ القوانين في الدسكورد قبل لا تبدأ',
        'استخدم /report لو احتجت مساعدة من الإدارة',
    ],

    // Music: add as many tracks as you want (files go in assets/)
    music: {
        volume: 0.35,          // start volume 0..1 (the player's own choice is remembered)
        shuffle: false,
        tracks: [
            { src: 'assets/music.mp3', title: 'RP', artist: 'Rko' },
            // { src: 'assets/track2.mp3', title: 'Night Drive', artist: 'JT Records' },
        ],
    },

    // Background images (optional). Empty = animated background only.
    // Put images in assets/ and list them: ['assets/bg1.jpg', 'assets/bg2.jpg']
    backgrounds: [],
    backgroundSeconds: 9,

    // Moving particles in the background (lower = lighter while the game loads)
    particles: 55,
};
