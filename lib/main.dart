import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuoteFlow',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F2456),
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF091126),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF0F1E43),
          onSurface: Colors.white,
        ),
      ),
      home: HomeScreen(
        currentThemeMode: _themeMode,
        onThemeChanged: _changeThemeMode,
      ),
    );
  }
}

class LocalQuote {
  final String text;
  final String author;
  final String language;

  const LocalQuote({
    required this.text,
    required this.author,
    required this.language,
  });
}

class ColorSchemePreset {
  final List<Color> colors;
  final Color accentOrbColor;

  const ColorSchemePreset({
    required this.colors,
    required this.accentOrbColor,
  });
}

class HomeScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late LocalQuote _currentQuote;
  final Random _random = Random();
  double _fontSizeModifier = 1.0;

  final GlobalKey _boundaryKey = GlobalKey();
  String _selectedLanguage = 'English';
  List<LocalQuote> _filteredQuotes = [];

  final List<LocalQuote> _history = [];
  int _historyIndex = -1;

  LocalQuote? _prefetchedEnglish;
  LocalQuote? _prefetchedHindi;
  LocalQuote? _prefetchedTelugu;
  bool _isPrefetching = false;

  // Slide & Fade Animation Controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Offset _slideBeginOffset = const Offset(1.0, 0.0);

  double _cardScale = 1.0;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _horizontalDragOffset = 0.0;
  double _verticalDragOffset = 0.0;

  final List<ColorSchemePreset> _cardColorPresets = const [
    ColorSchemePreset(
      colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
      accentOrbColor: Color(0xFF2A5298),
    ),
    ColorSchemePreset(
      colors: [Color(0xFF0B3C5D), Color(0xFF328CC1)],
      accentOrbColor: Color(0xFF328CC1),
    ),
    ColorSchemePreset(
      colors: [Color(0xFF3A1C71), Color(0xFFD76D77)],
      accentOrbColor: Color(0xFFD76D77),
    ),
    ColorSchemePreset(
      colors: [Color(0xFF1F4037), Color(0xFF99F2C8)],
      accentOrbColor: Color(0xFF99F2C8),
    ),
    ColorSchemePreset(
      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
      accentOrbColor: Color(0xFFF27121),
    ),
  ];
  int _cardColorIndex = 0;

  // Massive Offline Database: 300 Quotes (100 English, 100 Hindi, 100 Telugu)
  final List<LocalQuote> _fallbackDatabase = [
    // === ENGLISH DATABASE (100 QUOTES) ===
    LocalQuote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs", language: "English"),
    LocalQuote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt", language: "English"),
    LocalQuote(text: "In the middle of difficulty lies opportunity.", author: "Albert Einstein", language: "English"),
    LocalQuote(text: "Peace begins with a smile.", author: "Mother Teresa", language: "English"),
    LocalQuote(text: "Quiet the mind and the soul will speak.", author: "Buddha", language: "English"),
    LocalQuote(text: "It always seems impossible until it's done.", author: "Nelson Mandela", language: "English"),
    LocalQuote(text: "Act as if what you do makes a difference. It does.", author: "William James", language: "English"),
    LocalQuote(text: "Happiness is not something ready made. It comes from your own actions.", author: "Dalai Lama", language: "English"),
    LocalQuote(text: "Try to be a rainbow in someone else's cloud.", author: "Maya Angelou", language: "English"),
    LocalQuote(text: "The mind is everything. What you think you become.", author: "Buddha", language: "English"),
    LocalQuote(text: "Life is what happens when you're busy making other plans.", author: "John Lennon", language: "English"),
    LocalQuote(text: "You miss 100% of the shots you don't take.", author: "Wayne Gretzky", language: "English"),
    LocalQuote(text: "Whether you think you can or you think you can't, you're right.", author: "Henry Ford", language: "English"),
    LocalQuote(text: "The best way to predict your future is to create it.", author: "Peter Drucker", language: "English"),
    LocalQuote(text: "If you want to lift yourself up, lift up someone else.", author: "Booker T. Washington", language: "English"),
    LocalQuote(text: "An unexamined life is not worth living.", author: "Socrates", language: "English"),
    LocalQuote(text: "What you leave behind is what is woven into the lives of others.", author: "Pericles", language: "English"),
    LocalQuote(text: "The only true wisdom is in knowing you know nothing.", author: "Socrates", language: "English"),
    LocalQuote(text: "Success is not final, failure is not fatal: it is the courage to continue that counts.", author: "Winston Churchill", language: "English"),
    LocalQuote(text: "Do not go where the path may lead, go instead where there is no path and leave a trail.", author: "Ralph Waldo Emerson", language: "English"),
    LocalQuote(text: "You must be the change you wish to see in the world.", author: "Mahatma Gandhi", language: "English"),
    LocalQuote(text: "Spread love everywhere you go. Let no one ever come to you without leaving happier.", author: "Mother Teresa", language: "English"),
    LocalQuote(text: "The purpose of our lives is to be happy.", author: "Dalai Lama", language: "English"),
    LocalQuote(text: "Get busy living or get busy dying.", author: "Stephen King", language: "English"),
    LocalQuote(text: "You only live once, but if you do it right, once is enough.", author: "Mae West", language: "English"),
    LocalQuote(text: "To live is the rarest thing in the world. Most people exist, that is all.", author: "Oscar Wilde", language: "English"),
    LocalQuote(text: "Pain is inevitable. Suffering is optional.", author: "Haruki Murakami", language: "English"),
    LocalQuote(text: "Be yourself; everyone else is already taken.", author: "Oscar Wilde", language: "English"),
    LocalQuote(text: "A room without books is like a body without a soul.", author: "Marcus Tullius Cicero", language: "English"),
    LocalQuote(text: "Warmth, warmth, more warmth! For we are dying of cold and not of darkness.", author: "Miguel de Unamuno", language: "English"),
    LocalQuote(text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci", language: "English"),
    LocalQuote(text: "Time you enjoy wasting is not wasted time.", author: "Marthe Troly-Curtin", language: "English"),
    LocalQuote(text: "The journey of a thousand miles begins with one step.", author: "Lao Tzu", language: "English"),
    LocalQuote(text: "Dream big and dare to fail.", author: "Norman Vaughan", language: "English"),
    LocalQuote(text: "What we think, we become.", author: "Buddha", language: "English"),
    LocalQuote(text: "Everything you've ever wanted is on the other side of fear.", author: "George Addair", language: "English"),
    LocalQuote(text: "Hardships often prepare ordinary people for an extraordinary destiny.", author: "C.S. Lewis", language: "English"),
    LocalQuote(text: "It is never too late to be what you might have been.", author: "George Eliot", language: "English"),
    LocalQuote(text: "There is no charm equal to tenderness of heart.", author: "Jane Austen", language: "English"),
    LocalQuote(text: "All limitations are self-imposed.", author: "Oliver Wendell Holmes", language: "English"),
    LocalQuote(text: "Be so good they can't ignore you.", author: "Steve Martin", language: "English"),
    LocalQuote(text: "Yesterday is history, tomorrow is a mystery, today is a gift.", author: "Eleanor Roosevelt", language: "English"),
    LocalQuote(text: "Never let the fear of striking out keep you from playing the game.", author: "Babe Ruth", language: "English"),
    LocalQuote(text: "Love all, trust a few, do wrong to none.", author: "William Shakespeare", language: "English"),
    LocalQuote(text: "The limits of my language mean the limits of my world.", author: "Ludwig Wittgenstein", language: "English"),
    LocalQuote(text: "Imitation is suicide.", author: "Ralph Waldo Emerson", language: "English"),
    LocalQuote(text: "No legacy is so rich as honesty.", author: "William Shakespeare", language: "English"),
    LocalQuote(text: "I can resist everything except temptation.", author: "Oscar Wilde", language: "English"),
    LocalQuote(text: "Knowledge speaks, but wisdom listens.", author: "Jimi Hendrix", language: "English"),
    LocalQuote(text: "The truth is rarely pure and never simple.", author: "Oscar Wilde", language: "English"),
    LocalQuote(text: "You can't blame gravity for falling in love.", author: "Albert Einstein", language: "English"),
    LocalQuote(text: "Out of the mountain of despair, a stone of hope.", author: "Martin Luther King Jr.", language: "English"),
    LocalQuote(text: "No one can make you feel inferior without your consent.", author: "Eleanor Roosevelt", language: "English"),
    LocalQuote(text: "If you judge people, you have no time to love them.", author: "Mother Teresa", language: "English"),
    LocalQuote(text: "The only limit to our realization of tomorrow will be our doubts of today.", author: "Franklin D. Roosevelt", language: "English"),
    LocalQuote(text: "Do what you can, with what you have, where you are.", author: "Theodore Roosevelt", language: "English"),
    LocalQuote(text: "The best and most beautiful things in the world cannot be seen or even touched - they must be felt with the heart.", author: "Helen Keller", language: "English"),
    LocalQuote(text: "It is during our darkest moments that we must focus to see the light.", author: "Aristotle", language: "English"),
    LocalQuote(text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Aristotle", language: "English"),
    LocalQuote(text: "Your time is limited, so don't waste it living someone else's life.", author: "Steve Jobs", language: "English"),
    LocalQuote(text: "In three words I can sum up everything I've learned about life: it goes on.", author: "Robert Frost", language: "English"),
    LocalQuote(text: "The weak can never forgive. Forgiveness is the attribute of the strong.", author: "Mahatma Gandhi", language: "English"),
    LocalQuote(text: "Live as if you were to die tomorrow. Learn as if you were to live forever.", author: "Mahatma Gandhi", language: "English"),
    LocalQuote(text: "Keep your eyes on the stars, and your feet on the ground.", author: "Theodore Roosevelt", language: "English"),
    LocalQuote(text: "Success is stumbling from failure to failure with no loss of enthusiasm.", author: "Winston Churchill", language: "English"),
    LocalQuote(text: "If you tell the truth, you don't have to remember anything.", author: "Mark Twain", language: "English"),
    LocalQuote(text: "A person who never made a mistake never tried anything new.", author: "Albert Einstein", language: "English"),
    LocalQuote(text: "We must accept finite disappointment, but never lose infinite hope.", author: "Martin Luther King Jr.", language: "English"),
    LocalQuote(text: "Darkness cannot drive out darkness; only light can do that. Hate cannot drive out hate; only love can do that.", author: "Martin Luther King Jr.", language: "English"),
    LocalQuote(text: "Happiness depends upon ourselves.", author: "Aristotle", language: "English"),
    LocalQuote(text: "It is not length of life, but depth of life.", author: "Ralph Waldo Emerson", language: "English"),
    LocalQuote(text: "You do not find a happy life. You make it.", author: "Camilla Eyring Kimball", language: "English"),
    LocalQuote(text: "Be grateful for what you already have while you pursue your goals.", author: "Roy T. Bennett", language: "English"),
    LocalQuote(text: "You are never too old to set another goal or to dream a new dream.", author: "C.S. Lewis", language: "English"),
    LocalQuote(text: "Action is the foundational key to all success.", author: "Pablo Picasso", language: "English"),
    LocalQuote(text: "Normal is not something to aspire to, it's something to get away from.", author: "Jodie Foster", language: "English"),
    LocalQuote(text: "Life shrinks or expands in proportion to one's courage.", author: "Anais Nin", language: "English"),
    LocalQuote(text: "There is only one way to avoid criticism: do nothing, say nothing, and be nothing.", author: "Aristotle", language: "English"),
    LocalQuote(text: "Don't count the days, make the days count.", author: "Muhammad Ali", language: "English"),
    LocalQuote(text: "Turn your wounds into wisdom.", author: "Oprah Winfrey", language: "English"),
    LocalQuote(text: "Strive not to be a success, but rather to be of value.", author: "Albert Einstein", language: "English"),
    LocalQuote(text: "Integrity is doing the right thing when no one is watching.", author: "C.S. Lewis", language: "English"),
    LocalQuote(text: "Only those who dare to fail greatly can ever achieve greatly.", author: "Robert F. Kennedy", language: "English"),
    LocalQuote(text: "I have not failed. I've just found 10,000 ways that won't work.", author: "Thomas A. Edison", language: "English"),
    LocalQuote(text: "He who has a why to live can bear almost any how.", author: "Friedrich Nietzsche", language: "English"),
    LocalQuote(text: "That which does not kill us makes us stronger.", author: "Friedrich Nietzsche", language: "English"),
    LocalQuote(text: "Without music, life would be a mistake.", author: "Friedrich Nietzsche", language: "English"),
    LocalQuote(text: "Be kind, for everyone you meet is fighting a harder battle.", author: "Plato", language: "English"),
    LocalQuote(text: "Wisdom begins in wonder.", author: "Socrates", language: "English"),
    LocalQuote(text: "The price of apathy is to be ruled by evil men.", author: "Plato", language: "English"),
    LocalQuote(text: "You can discover more about a person in an hour of play than in a year of conversation.", author: "Plato", language: "English"),
    LocalQuote(text: "Do not spoil what you have by desiring what you have not.", author: "Epicurus", language: "English"),
    LocalQuote(text: "The greatest wealth is to live content with little.", author: "Plato", language: "English"),
    LocalQuote(text: "Waste no more time arguing about what a good man should be. Be one.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "The best revenge is to be unlike him who performed the injury.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "Very little is needed to make a happy life; it is all within yourself.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "Accept the things to which fate binds you, and love the people with whom fate brings you together.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "When you arise in the morning, think of what a precious privilege it is to be alive.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "The happiness of your life depends upon the quality of your thoughts.", author: "Marcus Aurelius", language: "English"),
    LocalQuote(text: "Never let your emotions override your intelligence.", author: "Drake", language: "English"),

    // === HINDI DATABASE (100 QUOTES) ===
    LocalQuote(text: "सफलता का कोई रहस्य नहीं है, यह केवल अत्यधिक परिश्रम की मांग करती है।", author: "APJ Abdul Kalam", language: "Hindi"),
    LocalQuote(text: "ख्वाहिशों से नहीं गिरते हैं फूल झोली में, कर्म की शाख को हिलाना होगा।", author: "Harivansh Rai Bachchan", language: "Hindi"),
    LocalQuote(text: "मन के हारे हार है, मन के जीते जीत।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "उठो, जागो और तब तक मत रुको जब तक लक्ष्य प्राप्त न हो जाए।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "सच्चा आत्मज्ञान ही परम शांति की ओर ले जाता है।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "बड़ा सोचो, तेजी से सोचो, दूसरों से आगे सोचो। विचारों पर किसी का एकाधिकार नहीं है।", author: "Dhirubhai Ambani", language: "Hindi"),
    LocalQuote(text: "विश्वास में वह शक्ति है जिससे उजड़ी हुई दुनिया में प्रकाश लाया जा सकता है।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "जैसे ही आप भय को अपने करीब आने दें, उस पर आक्रमण कर उसे नष्ट कर दें।", author: "Chanakya", language: "Hindi"),
    LocalQuote(text: "जो लोग अपनी तुलना दूसरों से करते हैं, वे अपनी बेइज्जती खुद करते हैं।", author: "Chanakya", language: "Hindi"),
    LocalQuote(text: "कल का रिकॉर्ड आज तोड़ दो, यही सफलता का मूलमंत्र है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "खुद वो बदलाव बनिए जो आप दुनिया में देखना चाहते हैं।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "सत्य बिना किसी समर्थन के भी खड़ा रहता है, वह आत्मनिर्भर है।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "कमजोर कभी क्षमा नहीं कर सकते। क्षमा करना ताकतवर का गुण है।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "एक विनम्र तरीके से, आप दुनिया को हिला सकते हैं।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "जो समय बचाते हैं, वे धन बचाते हैं और बचाया हुआ धन कमाए हुए धन के बराबर है।", author: "Mahatma Gandhi", language: "Hindi"),
    LocalQuote(text: "कर्म ही पूजा है और ईमानदारी ही सर्वोत्तम नीति है।", author: "Lal Bahadur Shastri", language: "Hindi"),
    LocalQuote(text: "हम रहे या न रहें, लेकिन यह तिरंगा हमेशा ऊंचा रहना चाहिए।", author: "Lal Bahadur Shastri", language: "Hindi"),
    LocalQuote(text: "यदि हम स्वतंत्र होना चाहते हैं, तो दूसरों को भी स्वतंत्रता देनी होगी।", author: "Subhash Chandra Bose", language: "Hindi"),
    LocalQuote(text: "तुम मुझे खून दो, मैं तुम्हें आजादी दूंगा।", author: "Subhash Chandra Bose", language: "Hindi"),
    LocalQuote(text: "सफलता हमारा परिचय दुनिया से कराती है और असफलता हमें दुनिया का परिचय कराती है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "महानता कभी न गिरने में नहीं है, बल्कि हर बार गिरकर उठ जाने में है।", author: "Confucius", language: "Hindi"),
    LocalQuote(text: "यदि आप किसी चीज को दिल से चाहें, तो पूरी कायनात उसे मिलाने में लग जाती है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "समय और समझ दोनों एक साथ खुशकिस्मत लोगों को ही मिलते हैं।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "विपत्ति में जो धैर्य बनाए रखता है, वही सच्चा योद्धा है।", author: "Chanakya", language: "Hindi"),
    LocalQuote(text: "ज्ञान ही आपका सबसे बड़ा मित्र है, जो हर परिस्थिति में साथ देता है।", author: "Chanakya", language: "Hindi"),
    LocalQuote(text: "एक अच्छा चरित्र आपकी सबसे बड़ी संपत्ति है।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "जिस दिन आपके सामने कोई समस्या न आए, समझें कि आप गलत रास्ते पर हैं।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "ब्रह्मांड की सभी शक्तियां हमारे अंदर हैं, हम ही अपनी आंखों पर हाथ रख लेते हैं।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "अनुभव ही एकमात्र शिक्षक है, जिससे हम सब कुछ सीखते हैं।", author: "Swami Vivekananda", language: "Hindi"),
    LocalQuote(text: "चिंता उतनी ही करो कि काम हो जाए, इतनी नहीं कि जिंदगी तमाम हो जाए।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "काल करे सो आज कर, आज करे सो अब।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "धीरे-धीरे रे मना, धीरे सब कुछ होय।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "निंदक नियरे राखिए, आँगन कुटी छवाय।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "बड़ा हुआ तो क्या हुआ, जैसे पेड़ खजूर।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "बुरा जो देखन मैं चला, बुरा न मिलिया कोय।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "पोथी पढ़ि पढ़ि जग मुआ, पंडित भया न कोय।", author: "Kabir Das", language: "Hindi"),
    LocalQuote(text: "विद्या ददाति विनयं, विनयाद् याति पात्रताम्।", author: "Sanskrit Proverb", language: "Hindi"),
    LocalQuote(text: "सत्यमेव जयते नानृतं, सत्येन पन्था विततो देवयानः।", author: "Upanishad", language: "Hindi"),
    LocalQuote(text: "वसुधैव कुटुम्बकम्, पूरी धरती ही मेरा परिवार है।", author: "Sanskrit Proverb", language: "Hindi"),
    LocalQuote(text: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "क्रोध से भ्रम पैदा होता है, भ्रम से बुद्धि व्यग्र होती है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "जो हुआ वह अच्छा हुआ, जो हो रहा है वह अच्छा हो रहा है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "परिवर्तन ही इस संसार का नियम है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "आत्मा अमर है, इसे न तो आग जला सकती है न पानी भिगो सकता है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "मन बहुत चंचल है, लेकिन अभ्यास से इसे वश में किया जा सकता है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "जो लोग दूसरों की मदद करते हैं, ईश्वर उनकी मदद करता है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "मेहनत का फल और समस्या का हल देर से ही सही लेकिन मिलता जरूर है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सपने वो नहीं जो हम सोते हुए देखते हैं, सपने वो हैं जो हमें सोने नहीं देते।", author: "APJ Abdul Kalam", language: "Hindi"),
    LocalQuote(text: "यदि आप सूर्य की तरह चमकना चाहते हैं, तो पहले सूर्य की तरह जलना सीखें।", author: "APJ Abdul Kalam", language: "Hindi"),
    LocalQuote(text: "ज्ञान के बिना इंसान एक खाली बर्तन की तरह है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "कठिन परिश्रम का कोई विकल्प नहीं है।", author: "Thomas Edison", language: "Hindi"),
    LocalQuote(text: "आपका समय सीमित है, इसलिए इसे दूसरों की जिंदगी जीने में व्यर्थ न करें।", author: "Steve Jobs", language: "Hindi"),
    LocalQuote(text: "एक उत्कृष्ट जीवन जीने के लिए, हमेशा अपने दिल की सुनें।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सच्चे मित्र वही हैं जो संकट के समय आपका साथ दें।", author: "Sanskrit Proverb", language: "Hindi"),
    LocalQuote(text: "ज्ञान ही वह शक्ति है जिससे आप दुनिया को बदल सकते हैं।", author: "Nelson Mandela", language: "Hindi"),
    LocalQuote(text: "शिक्षा सबसे शक्तिशाली हथियार है जिसका उपयोग आप दुनिया को बदलने के लिए कर सकते हैं।", author: "Nelson Mandela", language: "Hindi"),
    LocalQuote(text: "गलतियाँ करने में कोई बुराई नहीं है, लेकिन उन्हें न सुधारना मूर्खता है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "मंजिलें उन्हीं को मिलती हैं जिनके सपनों में जान होती है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "मुश्किलें दिल के इरादे आजमाती हैं, स्वप्न के परदे निगाहों से हटाती हैं।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "हौसला मत हार गिरकर ओ मुसाफिर, अगर दर्द यहाँ मिला है तो दवा भी यहीं मिलेगी।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "परिश्रम ही सफलता की कुंजी है।", author: "Anold", language: "Hindi"),
    LocalQuote(text: "जो मुस्कुरा रहा है उसे दर्द ने पाला होगा, जो चल रहा है उसके पाँव में छाला होगा।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "बिना संघर्ष के कोई महान नहीं होता, बिना कुछ किये जय जय कार नहीं होता।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सफलता की शुरुआत हमेशा छोटे संकल्पों से होती है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "विचारों को शुद्ध रखें, कर्म अपने आप उत्कृष्ट हो जाएंगे।", author: "Socrates", language: "Hindi"),
    LocalQuote(text: "शांति की शुरुआत हमेशा एक मुस्कान से होती है।", author: "Mother Teresa", language: "Hindi"),
    LocalQuote(text: "धैर्य कड़वा है, लेकिन इसका फल बहुत मीठा होता है।", author: "Jean-Jacques Rousseau", language: "Hindi"),
    LocalQuote(text: "सत्य हमेशा कड़वा होता है, लेकिन अंततः विजय उसी की होती है।", author: "Sanskrit Proverb", language: "Hindi"),
    LocalQuote(text: "जो झुक सकता है, वह सारी दुनिया को झुका सकता है।", author: "Chinese Proverb", language: "Hindi"),
    LocalQuote(text: "अपने सपनों को सच करने का सबसे अच्छा तरीका है कि जाग जाओ।", author: "Paul Valery", language: "Hindi"),
    LocalQuote(text: "कल का इंतजार मत करो, क्योंकि कल कभी नहीं आता।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "क्रोध में बोला गया एक शब्द पूरे जीवन की शांति को भंग कर सकता है।", author: "Buddha", language: "Hindi"),
    LocalQuote(text: "वाणी में वह जादू है जो दुश्मन को भी दोस्त बना सकती है।", author: "Kabir", language: "Hindi"),
    LocalQuote(text: "जो लोग दूसरों को खुशी देते हैं, वे स्वयं भी खुश रहते हैं।", author: "Dalai Lama", language: "Hindi"),
    LocalQuote(text: "जीवन एक रंगमंच है और हम सब इसकी कठपुतलियाँ हैं।", author: "Shakespeare", language: "Hindi"),
    LocalQuote(text: "ईमानदारी सर्वोत्तम नीति है।", author: "Aesop", language: "Hindi"),
    LocalQuote(text: "मेहनत कभी बेकार नहीं जाती।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सुख और दुःख एक ही सिक्के के दो पहलू हैं।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "वक्त सबको मिलता है जिंदगी बदलने के लिए, पर जिंदगी दोबारा नहीं मिलती वक्त बदलने के लिए।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "लगातार प्रयास करने वाले कभी असफल नहीं होते।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "जो चाहा वो मिल जाना सफलता है, जो मिला है उसे चाहना प्रसन्नता है।", author: "Dale Carnegie", language: "Hindi"),
    LocalQuote(text: "अनुभव कड़वा जरूर होता है लेकिन जीवन का सर्वश्रेष्ठ शिक्षक है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "पछतावे से कुछ नहीं बदलता, केवल आज का दिन खराब होता है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "वाणी की मधुरता से हर कोई प्रभावित होता है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "समय की कद्र करना सीखें, समय आपकी कद्र करेगा।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "जो दूसरों का भला सोचता है, उसका कभी बुरा नहीं होता।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "एकता में ही असली शक्ति है।", author: "Aesop", language: "Hindi"),
    LocalQuote(text: "किताबें हमारी सबसे अच्छी मित्र हैं।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सत्यमेव जयते - सत्य की ही हमेशा जीत होती है।", author: "Mundaka Upanishad", language: "Hindi"),
    LocalQuote(text: "योग ही कर्मों में कुशलता है।", author: "Bhagavad Gita", language: "Hindi"),
    LocalQuote(text: "स्वास्थ्य ही सबसे बड़ा धन है।", author: "Virgil", language: "Hindi"),
    LocalQuote(text: "दयालुता एक ऐसी भाषा है जिसे बहरे सुन सकते हैं और अंधे देख सकते हैं।", author: "Mark Twain", language: "Hindi"),
    LocalQuote(text: "सच्चा ज्ञान विनम्रता लाता है।", author: "Sanskrit Proverb", language: "Hindi"),
    LocalQuote(text: "क्रोध का अंत हमेशा पश्चाताप से होता है।", author: "Pythagoras", language: "Hindi"),
    LocalQuote(text: "बिना सोचे-समझे किया गया कार्य हमेशा हानि पहुँचाता है।", author: "Panchatantra", language: "Hindi"),
    LocalQuote(text: "लक्ष्य को पाने के लिए निरंतरता बहुत आवश्यक है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "सहानुभूति दुनिया की सबसे खूबसूरत भावनाओं में से एक है।", author: "Unknown", language: "Hindi"),
    LocalQuote(text: "जीवन का मुख्य उद्देश्य खुश रहना है।", author: "Dalai Lama", language: "Hindi"),
    LocalQuote(text: "आप अपनी सोच को बदलकर अपनी दुनिया बदल सकते हैं।", author: "Norman Vincent Peale", language: "Hindi"),
    LocalQuote(text: "असंभव शब्द केवल मूर्खों के शब्दकोश में पाया जाता है।", author: "Napoleon Bonaparte", language: "Hindi"),

    // === TELUGU DATABASE (100 QUOTES) ===
    LocalQuote(text: "కృషి ఉంటే మనుషులు ఋషులవుతారు, మహాపురుషులవుతారు.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "ఓటమి అనేది విజయానికి మొదటి మెట్టు మాత్రమే.", author: "Sirivennela", language: "Telugu"),
    LocalQuote(text: "ప్రశాంతత అనేది బయట దొరికేది కాదు, నీ మనస్సులోనే ఉంది.", author: "Buddha", language: "Telugu"),
    LocalQuote(text: "నీ ఆలోచనలే నీ భవిష్యత్తును నిర్దేశిస్తాయి.", author: "Swami Vivekananda", language: "Telugu"),
    LocalQuote(text: "మౌనం అనేది అన్ని సమస్యలకు అత్యుత్తమ సమాధానం.", author: "Chanakya", language: "Telugu"),
    LocalQuote(text: "లక్ష్యం ఎంత పెద్దదైతే, శ్రమ కూడా అంత ఎక్కువగా ఉండాలి.", author: "Alluri Sitarama Raju", language: "Telugu"),
    LocalQuote(text: "సమయం చాలా విలువైనది, దాన్ని వృధా చేయడం అంటే జీవితాన్ని వృధా చేయడమే.", author: "Potti Sreeramulu", language: "Telugu"),
    LocalQuote(text: "నిజాయితీ గల జీవితమే మనిషికి నిజమైన అందం.", author: "Sri Sri", language: "Telugu"),
    LocalQuote(text: "సాధనతో సాధించలేనిది లోకంలో ఏదీ లేదు.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "నీపై నీకు నమ్మకం లేనప్పుడు, భగవంతుడిపై నమ్మకం ఉన్నా ప్రయోజనం లేదు.", author: "Swami Vivekananda", language: "Telugu"),
    LocalQuote(text: "కోపం అనేది నిన్ను నువ్వు కాల్చుకునే నిప్పు లాంటిది.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "మంచి పుస్తకం వంద మంది స్నేహితులతో సమానం.", author: "APJ Abdul Kalam", language: "Telugu"),
    LocalQuote(text: "కష్టం వస్తే కుంగిపోవద్దు, సుఖం వస్తే పొంగిపోవద్దు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మాతృభాషను మరవడం అంటే తల్లిని మరవడమే.", author: "Gidugu Ramamurthy", language: "Telugu"),
    LocalQuote(text: "ధైర్యమే మానవుడికి అసలైన రక్షణ కవచం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "సత్యం ఎప్పుడూ ఒంటరిగానే ఉంటుంది, కానీ గెలుస్తుంది.", author: "Mahatma Gandhi", language: "Telugu"),
    LocalQuote(text: "సహనం అనేది చేదుగా ఉండవచ్చు, కానీ దాని ఫలితం చాలా తీపిగా ఉంటుంది.", author: "Aristotle", language: "Telugu"),
    LocalQuote(text: "विद्या కంటే విలువైన సంపద లోకంలో ఇంకొకటి లేదు.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "అతిగా మాట్లాడటం వల్ల గౌరవం తగ్గుతుంది.", author: "Chanakya", language: "Telugu"),
    LocalQuote(text: "పరుల సేవలోనే పరమాత్మ ఉన్నాడు.", author: "Mother Teresa", language: "Telugu"),
    LocalQuote(text: "ఆలోచన లేకుండా చేసే పని ఎప్పుడూ నష్టాన్ని తెస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి పనులు చేయడానికి సమయం కోసం ఎదురుచూడకూడదు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "శత్రువును క్షమించడం వల్ల నీవు మరింత గొప్పవాడివి అవుతావు.", author: "Buddha", language: "Telugu"),
    LocalQuote(text: "జీవితం ఒక ఆట, దాన్ని చిరునవ్వుతో ఆడాలి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "కృతజ్ఞత లేని హృదయం ఎడారి లాంటిది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఆశే జీవన బలం, నిరాశే మరణ కారణం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "పెద్దలను గౌరవించడం మన సంస్కృతి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "అబద్ధం చెప్పి బతకడం కంటే, నిజం చెప్పి చావడం మేలు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి మనస్సు గలవారే లోకాన్ని జయించగలరు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "అహంకారం మనిషిని సర్వనాశనం చేస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "పట్టుదల ఉంటే ఆకాశాన్ని కూడా అందుకోవచ్చు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "స్నేహం అనేది రెండు శరీరాల ఒకే ఆత్మ.", author: "Aristotle", language: "Telugu"),
    LocalQuote(text: "ఇతరులకు కీడు చేయాలని అనుకోవడం నీకే నష్టం.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "మాట జారితే వెనక్కి తీసుకోలేము, జాగ్రత్తగా మాట్లాడాలి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "తల్లిదండ్రుల సేవ పరమ పుణ్యం.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "జ్ఞానం అనేది పంచే కొద్దీ పెరుగుతుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "సంతోషమే సగం బలం.", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "ఇల్లు చూసి ఇల్లాలును చూడాలి.", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "ఆరోగ్యమే మహాభాగ్యం.", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "చింత చచ్చినా పులుపు చావదు.", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "అడుగు ముందుకు వేస్తేనే గమ్యం చేరుతావు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "కష్టపడకుండా వచ్చే ప్రతిఫలం ఎక్కువ కాలం నిలవదు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నీ తప్పులను నువ్వు తెలుసుకోవడమే జ్ఞానం.", author: "Socrates", language: "Telugu"),
    LocalQuote(text: "ఎవరిని చూసి ఈర్ష్య పడకూడదు, అది నిన్నే దహిస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "చిన్న మొక్కే కదా అని నిర్లక్ష్యం చేయవద్దు, అదే రేపు పెద్ద వృక్షం అవుతుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "సమయపాలన పాటించేవాడు ఎప్పుడూ వెనుకబడడు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "దేశాన్ని ప్రేమించుమన్నా, మంచి అన్నది పెంచుమన్నా.", author: "Gurajada Apparao", language: "Telugu"),
    LocalQuote(text: "సొంత లాభం కొంత మానుకొని, పొరుగువానికి తోడుపడవోయ్.", author: "Gurajada Apparao", language: "Telugu"),
    LocalQuote(text: "వెలుగు ఉన్నప్పుడే ఇల్లు చక్కబెట్టుకోవాలి.", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "మొక్కై వంగనిది మానై వంగునా?", author: "Telugu Proverb", language: "Telugu"),
    LocalQuote(text: "నీ ధైర్యమే నీకు శ్రీరామరక్ష.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "కష్టాలు నిన్ను బలవంతుడిని చేయడానికి వస్తాయి, బలహీనుడిని చేయడానికి కాదు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఆనందం అనేది ఎక్కడో లేదు, మన ప్రవర్తనలోనే ఉంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "అందరితో మంచిగా ఉండటమే నిజమైన సంస్కారం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నీవు నమ్మిన సిద్ధాంతం కోసం ప్రాణాలైనా ఇవ్వవచ్చు.", author: "Alluri Sitarama Raju", language: "Telugu"),
    LocalQuote(text: "అనుభవం కంటే గొప్ప పాఠశాల లోకంలో మరొకటి లేదు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నిత్యం నేర్చుకోవాలనే తపన ఉన్నవాడే నిజమైన మేధావి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "శ్రమ నీ ఆయుధం అయితే, విజయం నీ బానిస అవుతుంది.", author: "APJ Abdul Kalam", language: "Telugu"),
    LocalQuote(text: "మనసు ప్రశాంతంగా ఉంటే ఎలాంటి సమస్యనైనా జయించవచ్చు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి ఆలోచనలే జీవితానికి వెలుగునిస్తాయి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఎదుటివారి కష్టాన్ని చూసి స్పందించే హృదయమే దైవస్వరూపం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "గొప్ప పనులు రాత్రికి రాత్రే జరగవు, వాటికి నిరంతర శ్రమ అవసరం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ప్రేమ అనేది ప్రపంచాన్ని మార్చగల ఏకైక శక్తి.", author: "Mother Teresa", language: "Telugu"),
    LocalQuote(text: "చీకటిని తిట్టడం కంటే ఒక చిన్న దీపం వెలిగించడం మేలు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ప్రతి సంక్షోభం వెనుక ఒక గొప్ప అవకాశం దాగి ఉంటుంది.", author: "Albert Einstein", language: "Telugu"),
    LocalQuote(text: "నమ్మకమే జీవిత ప్రయాణానికి ఆయువు పట్టు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఇతరుల కోసం బతికే జీవితమే అత్యున్నతమైనది.", author: "Swami Vivekananda", language: "Telugu"),
    LocalQuote(text: "నీ సమయం అమూల్యమైనది, దాన్ని ఇతరుల కోసం వృధా చేయకు.", author: "Steve Jobs", language: "Telugu"),
    LocalQuote(text: "విజయం అనేది అదృష్టం కాదు, అది నిరంతర శ్రమ యొక్క ఫలితం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నీ బలమే నీకు విజయాన్ని చేకూరుస్తుంది, నీ బలహీనతే నిన్ను ఓడిస్తుంది.", author: "Swami Vivekananda", language: "Telugu"),
    LocalQuote(text: "అహంకారాన్ని విడనాడితేనే మనిషికి నిజమైన గౌరవం లభిస్తుంది.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "మంచి పుస్తకాలు చదవడం వల్ల జ్ఞాన పరిధి పెరుగుతుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నువ్వు చేసే ప్రతి పనిలోనూ పూర్తి శ్రద్ధ పెట్టు.", author: "Bhagavad Gita", language: "Telugu"),
    LocalQuote(text: "నిజాయితీతో కూడిన సంపాదన మాత్రమే మనశ్శాంతిని ఇస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "కోపాన్ని అదుపులో ఉంచుకోవడం వల్ల చాలా అనర్థాలు తప్పుతాయి.", author: "Chanakya", language: "Telugu"),
    LocalQuote(text: "ప్రతి రోజూ ఒక కొత్త అవకాశాన్ని మోసుకొస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఇతరులను తక్కువగా అంచనా వేయడం మన బలహీనతను చూపిస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి గుణం ఉన్నవాడే నిజమైన భాగ్యవంతుడు.", author: "Vemana", language: "Telugu"),
    LocalQuote(text: "ఆరోగ్యమే మానవ జీవితానికి అత్యంత ముఖ్యమైన సంపద.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "కృతజ్ఞతా భావం కలిగి ఉండటం అనేది గొప్ప దైవగుణం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "జీవితంలో గెలుపోటములు సహజం, వాటిని సమానంగా స్వీకరించాలి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నీ గమ్యం వైపు నీ ప్రయాణం నిరంతరం సాగాలి.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "పరిశుభ్రత దైవత్వంతో సమానం.", author: "Mahatma Gandhi", language: "Telugu"),
    LocalQuote(text: "గొప్ప కలలు కనండి, వాటిని సాకారం చేసుకోవడానికి నిరంతరం శ్రమించండి.", author: "APJ Abdul Kalam", language: "Telugu"),
    LocalQuote(text: "నీవు చేసే సహాయం గుప్తంగా ఉండాలి, ప్రశంసల కోసం కాకూడదు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "సంస్కారం లేని చదువు వ్యర్థం.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "జీవితాన్ని ఆనందంగా గడపడమే ఒక కళ.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి నడవడికతోనే సమాజంలో గుర్తింపు లభిస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "స్నేహితులు మన జీవితానికి అద్దం లాంటివారు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "భయం అనేది ఒక మానసిక బలహీనత మాత్రమే, దాన్ని అధిగమించాలి.", author: "Swami Vivekananda", language: "Telugu"),
    LocalQuote(text: "నిజమైన సంతోషం ఇతరులను సంతోషపెట్టడంలోనే ఉంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "క్షమించే గుణం ఉన్నవాడు శత్రువునైనా జయించగలడు.", author: "Buddha", language: "Telugu"),
    LocalQuote(text: "నీ లక్ష్య సాధనలో ఆటంకాలు వస్తే వెనుకడుగు వేయకు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "మంచి మార్గంలో సాగే ప్రయాణం ఎప్పుడూ కష్టంగానే ఉంటుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "నిగ్రహం ఉన్న వ్యక్తిని ఏ శక్తి కూడా లొంగదీసుకోలేదు.", author: "Chanakya", language: "Telugu"),
    LocalQuote(text: "విమర్శలను స్వీకరించి నిన్ను నువ్వు మెరుగుపరుచుకో.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "సమయాన్ని గౌరవించే వ్యక్తి సమాజంలో గౌరవించబడతాడు.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ప్రతి మనిషిలోనూ ఏదో ఒక ప్రతిభ దాగి ఉంటుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "ఆశ నిన్ను ముందుకు నడిపిస్తుంది, నిరాశ నిన్ను నిశ్చేష్టుడిని చేస్తుంది.", author: "Unknown", language: "Telugu"),
    LocalQuote(text: "చీకటి ఎంత దట్టంగా ఉన్నా ఉదయం రాకను ఆపలేదు.", author: "Unknown", language: "Telugu"),
  ];

  @override
  void initState() {
    super.initState();
    _applyLanguageFilter(_selectedLanguage);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeIn);

    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundPrefetchPipeline();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _applyLanguageFilter(String language) {
    setState(() {
      _selectedLanguage = language;
      _filteredQuotes = _fallbackDatabase.where((q) => q.language == language).toList();
      final initQuote = _filteredQuotes[_random.nextInt(_filteredQuotes.length)];
      _currentQuote = initQuote;

      _history.clear();
      _history.add(initQuote);
      _historyIndex = 0;
    });
  }

  void _nextCardColorScheme() {
    setState(() {
      _cardColorIndex = (_cardColorIndex + 1) % _cardColorPresets.length;
    });
    HapticFeedback.mediumImpact();
  }

  void _prevCardColorScheme() {
    setState(() {
      _cardColorIndex = (_cardColorIndex - 1 + _cardColorPresets.length) % _cardColorPresets.length;
    });
    HapticFeedback.mediumImpact();
  }

  void _quoteTriggerAction() {
    _nextCardColorScheme();
    _slideBeginOffset = const Offset(1.0, 0.0);
    _getNextQuote();
  }

  void _getPreviousQuote() {
    if (_historyIndex > 0) {
      _slideBeginOffset = const Offset(-1.0, 0.0);
      _slideController.reverse().then((_) {
        setState(() {
          _historyIndex--;
          _currentQuote = _history[_historyIndex];
        });
        _slideController.forward();
      });
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reached the beginning of your session history!'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _getNextQuote() {
    _slideBeginOffset = const Offset(1.0, 0.0);
    _slideController.reverse().then((_) {
      if (_historyIndex < _history.length - 1) {
        setState(() {
          _historyIndex++;
          _currentQuote = _history[_historyIndex];
        });
        _slideController.forward();
        return;
      }

      LocalQuote? nextUp;

      if (_selectedLanguage == 'English' && _prefetchedEnglish != null) {
        nextUp = _prefetchedEnglish;
        _prefetchedEnglish = null;
      } else if (_selectedLanguage == 'Hindi' && _prefetchedHindi != null) {
        nextUp = _prefetchedHindi;
        _prefetchedHindi = null;
      } else if (_selectedLanguage == 'Telugu' && _prefetchedTelugu != null) {
        nextUp = _prefetchedTelugu;
        _prefetchedTelugu = null;
      }

      if (nextUp == null) {
        if (_filteredQuotes.isNotEmpty) {
          nextUp = _filteredQuotes[_random.nextInt(_filteredQuotes.length)];
        } else {
          nextUp = _fallbackDatabase[_random.nextInt(_fallbackDatabase.length)];
        }
      }

      setState(() {
        _currentQuote = nextUp!;
        _history.add(nextUp);
        _historyIndex++;
      });

      _slideController.forward();
      _startBackgroundPrefetchPipeline();
    });
  }

  Future<void> _startBackgroundPrefetchPipeline() async {
    if (_isPrefetching) return;
    _isPrefetching = true;

    try {
      final response = await http.get(Uri.parse('https://zenquotes.io/api/random')).timeout(
        const Duration(seconds: 3),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          String rawText = data[0]['q'];
          String author = data[0]['a'];

          _prefetchedEnglish = LocalQuote(text: rawText, author: author, language: 'English');

          _fetchSingleTranslation(rawText, 'hi').then((translatedText) {
            if (translatedText != null) {
              _prefetchedHindi = LocalQuote(text: translatedText, author: author, language: 'Hindi');
            }
          });

          _fetchSingleTranslation(rawText, 'te').then((translatedText) {
            if (translatedText != null) {
              _prefetchedTelugu = LocalQuote(text: translatedText, author: author, language: 'Telugu');
            }
          });
        }
      }
    } catch (_) {}
    finally {
      _isPrefetching = false;
    }
  }

  Future<String?> _fetchSingleTranslation(String text, String targetLang) async {
    try {
      final url = Uri.parse(
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|$targetLang'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final Map<String, dynamic> transData = json.decode(response.body);
        String cleanResult = transData['responseData']['translatedText'] ?? text;
        return cleanResult
            .replaceAll(RegExp(r'&quot;'), '"')
            .replaceAll(RegExp(r'&#39;'), "'");
      }
    } catch (_) {}
    return null;
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: '"${_currentQuote.text}" — ${_currentQuote.author}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote copied directly to clipboard! 📋'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareWholeCardLayout() async {
    try {
      final RenderRepaintBoundary? boundary =
      _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        await Share.shareXFiles(
          [
            XFile.fromData(
              pngBytes,
              name: 'QuoteFlow_Premium_Card.png',
              mimeType: 'image/png',
            )
          ],
          text: '"${_currentQuote.text}" — ${_currentQuote.author} \nShared via QuoteFlow',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to compile whole-card frame: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _exportQuoteAsAssetImage() async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final RenderRepaintBoundary? boundary =
      _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        await Gal.putImageBytes(pngBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved layout cleanly to Gallery! 📸'), backgroundColor: Colors.teal),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error details: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _changeFontSize() {
    setState(() {
      if (_fontSizeModifier >= 1.3) {
        _fontSizeModifier = 0.9;
      } else {
        _fontSizeModifier += 0.1;
      }
    });
  }

  void _cycleThemeMode() {
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final currentIndex = modes.indexOf(widget.currentThemeMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    widget.onThemeChanged(modes[nextIndex]);
    HapticFeedback.selectionClick();
  }

  IconData _getThemeIcon() {
    switch (widget.currentThemeMode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  String _getThemeLabel() {
    switch (widget.currentThemeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardPreset = _cardColorPresets[_cardColorIndex];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Layout Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ScaleBounceWidget(
                        onTap: _changeFontSize,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.format_size_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),

                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD465), size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'QuoteFlow',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F2456),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inspire Every Moment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          ScaleBounceWidget(
                            onTap: _cycleThemeMode,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                shape: BoxShape.circle,
                              ),
                              child: Tooltip(
                                message: 'Theme: ${_getThemeLabel()}',
                                child: Icon(
                                  _getThemeIcon(),
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: isDark ? const Color(0xFF102146) : Colors.white,
                            ),
                            child: DropdownButton<String>(
                              value: _selectedLanguage,
                              underline: const SizedBox(),
                              icon: Icon(
                                  Icons.translate_rounded,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  size: 20
                              ),
                              alignment: Alignment.centerRight,
                              items: ['English', 'Hindi', 'Telugu'].map((String lang) {
                                return DropdownMenuItem<String>(
                                  value: lang,
                                  child: Text(
                                    lang == 'Hindi' ? 'हिंदी' : (lang == 'Telugu' ? 'తెలుగు' : 'EN'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF0F2456),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _applyLanguageFilter(value);
                                  _getNextQuote();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Swipeable Quote Card
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _horizontalDragOffset += details.delta.dx;
                        _verticalDragOffset += details.delta.dy;
                      });
                    },
                    onPanEnd: (details) {
                      if (_horizontalDragOffset.abs() > _verticalDragOffset.abs()) {
                        if (_horizontalDragOffset > 100) {
                          _getPreviousQuote();
                        } else if (_horizontalDragOffset < -100) {
                          _getNextQuote();
                        }
                      } else {
                        if (_verticalDragOffset > 100) {
                          _prevCardColorScheme();
                        } else if (_verticalDragOffset < -100) {
                          _nextCardColorScheme();
                        }
                      }

                      setState(() {
                        _horizontalDragOffset = 0.0;
                        _verticalDragOffset = 0.0;
                      });
                    },
                    child: Listener(
                      onPointerDown: (details) {
                        setState(() {
                          _cardScale = 0.96;
                        });
                      },
                      onPointerMove: (details) {
                        final RenderBox? box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final size = box.size;
                          final localPos = details.localPosition;
                          setState(() {
                            _tiltX = ((localPos.dy / size.height) - 0.5) * 0.15;
                            _tiltY = ((localPos.dx / size.width) - 0.5) * -0.15;
                          });
                        }
                      },
                      onPointerUp: (details) {
                        setState(() {
                          _cardScale = 1.0;
                          _tiltX = 0.0;
                          _tiltY = 0.0;
                        });
                      },
                      onPointerCancel: (details) {
                        setState(() {
                          _cardScale = 1.0;
                          _tiltX = 0.0;
                          _tiltY = 0.0;
                        });
                      },
                      child: GestureDetector(
                        onLongPress: _exportQuoteAsAssetImage,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1.0, end: _cardScale),
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          builder: (context, scaleVal, child) {
                            final double rotationY = (_horizontalDragOffset * 0.0012);
                            final double rotationX = (_verticalDragOffset * -0.0012);

                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..translate(_horizontalDragOffset * 0.8, _verticalDragOffset * 0.8, 0.0)
                                ..rotateX(_tiltX + rotationX)
                                ..rotateY(_tiltY + rotationY)
                                ..scale(scaleVal),
                              alignment: Alignment.center,
                              child: child,
                            );
                          },
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: cardPreset.colors,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardPreset.colors.last.withOpacity(0.35),
                                      blurRadius: 25,
                                      offset: const Offset(0, 12),
                                    )
                                  ]
                              ),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: _slideBeginOffset,
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _slideController,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.format_quote_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        _currentQuote.text,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22 * _fontSizeModifier,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.5,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(0.15),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          "- ${_currentQuote.author}",
                                          style: TextStyle(
                                            fontSize: 15 * _fontSizeModifier,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withOpacity(0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Tri-Action Grid Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ScaleBounceWidget(
                            onTap: _copyToClipboard,
                            child: _buildActionCard(
                              context: context,
                              icon: Icons.copy_all_rounded,
                              label: 'Copy Text',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ScaleBounceWidget(
                            onTap: _shareWholeCardLayout,
                            child: _buildActionCard(
                              context: context,
                              icon: Icons.share_rounded,
                              label: 'Share Card',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // "Quote" Action Button (Triggers color shift + next quote slide transition)
                  ScaleBounceWidget(
                    onTap: _quoteTriggerAction,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.white : const Color(0xFF0F2456),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Quote',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF091126) : Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isDark ? Colors.white : const Color(0xFF0F2456),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class ScaleBounceWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ScaleBounceWidget({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<ScaleBounceWidget> createState() => _ScaleBounceWidgetState();
}

class _ScaleBounceWidgetState extends State<ScaleBounceWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}