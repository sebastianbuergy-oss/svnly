import 'dart:convert';
import 'dart:io';

typedef Subject = ({String en, String de, String category});
typedef Frame = ({String en, String de});

const subjects = <Subject>[
  (
    en: 'the closest red thing',
    de: 'den nächsten roten Gegenstand',
    category: 'observation',
  ),
  (
    en: 'the most colorful object near you',
    de: 'den buntesten Gegenstand in deiner Nähe',
    category: 'creative',
  ),
  (
    en: 'one item you used today',
    de: 'einen Gegenstand, den du heute benutzt hast',
    category: 'everyday',
  ),
  (en: 'something soft', de: 'etwas Weiches', category: 'home'),
  (en: 'your view right now', de: 'deine Aussicht gerade', category: 'view'),
  (
    en: 'your favorite cup or glass',
    de: 'deine liebste Tasse oder dein liebstes Glas',
    category: 'food',
  ),
  (
    en: 'the shoes you are wearing',
    de: 'die Schuhe, die du gerade trägst',
    category: 'everyday',
  ),
  (
    en: 'a snack or ingredient nearby',
    de: 'einen Snack oder eine Zutat in deiner Nähe',
    category: 'food',
  ),
  (
    en: 'the oldest safe object nearby',
    de: 'den ältesten sicheren Gegenstand in deiner Nähe',
    category: 'observation',
  ),
  (
    en: 'the newest thing in the room',
    de: 'den neuesten Gegenstand im Raum',
    category: 'observation',
  ),
  (
    en: 'an interesting shadow',
    de: 'einen interessanten Schatten',
    category: 'creative',
  ),
  (
    en: 'a plant or leaf',
    de: 'eine Pflanze oder ein Blatt',
    category: 'outdoors',
  ),
  (
    en: 'a texture you like',
    de: 'eine Oberfläche, die du magst',
    category: 'observation',
  ),
  (en: 'something round', de: 'etwas Rundes', category: 'weird'),
  (
    en: 'something surprisingly tiny',
    de: 'etwas überraschend Kleines',
    category: 'weird',
  ),
  (
    en: 'an object with a story',
    de: 'einen Gegenstand mit einer Geschichte',
    category: 'wholesome',
  ),
  (
    en: 'the nearest source of light',
    de: 'die nächste Lichtquelle',
    category: 'home',
  ),
  (
    en: 'something that makes you smile',
    de: 'etwas, das dich zum Lächeln bringt',
    category: 'mood',
  ),
  (
    en: 'the funniest harmless object nearby',
    de: 'den lustigsten harmlosen Gegenstand in deiner Nähe',
    category: 'funny',
  ),
  (
    en: 'one thing that matches your mood',
    de: 'etwas, das zu deiner Stimmung passt',
    category: 'mood',
  ),
];

const frames = <Frame>[
  (en: 'Show us {x} right now.', de: 'Zeig uns jetzt {x}.'),
  (en: 'Bring {x} into frame.', de: 'Hol {x} ins Bild.'),
  (en: 'Give us a close-up of {x}.', de: 'Zeig uns {x} ganz nah.'),
  (en: 'Point at {x} without speaking.', de: 'Zeig ohne Worte auf {x}.'),
  (
    en: 'Frame {x} like a movie star.',
    de: 'Setz {x} wie einen Filmstar in Szene.',
  ),
  (
    en: 'Reveal {x} with one quick camera move.',
    de: 'Enthülle {x} mit einer schnellen Kamerabewegung.',
  ),
  (en: 'Show {x} from a low angle.', de: 'Zeig {x} aus der Froschperspektive.'),
  (en: 'Show {x} from above.', de: 'Zeig {x} von oben.'),
  (
    en: 'Place your hand next to {x} for scale.',
    de: 'Halte deine Hand zum Grössenvergleich neben {x}.',
  ),
  (
    en: "Show how today's light falls on {x}.",
    de: 'Zeig, wie das heutige Licht auf {x} fällt.',
  ),
  (
    en: 'Move a little closer to {x} for seven seconds.',
    de: 'Bewege dich sieben Sekunden lang etwas näher an {x} heran.',
  ),
  (
    en: 'Show {x} and your immediate reaction.',
    de: 'Zeig {x} und deine unmittelbare Reaktion.',
  ),
  (
    en: 'Circle gently around {x} if space allows.',
    de: 'Bewege dich vorsichtig um {x}, wenn genug Platz ist.',
  ),
  (
    en: 'Show one detail of {x} that people might miss.',
    de: 'Zeig ein Detail von {x}, das andere übersehen könnten.',
  ),
  (
    en: 'Show the main color of {x} up close.',
    de: 'Zeig die Hauptfarbe von {x} ganz nah.',
  ),
  (en: 'Hold the camera still on {x}.', de: 'Halte die Kamera ruhig auf {x}.'),
  (
    en: 'Show {x} in the widest safe view you can.',
    de: 'Zeig {x} im weitesten sicheren Bildausschnitt.',
  ),
  (
    en: 'Show {x}, then the space around it.',
    de: 'Zeig zuerst {x} und dann die Umgebung darum.',
  ),
  (
    en: 'Start close to {x}, then pull back safely.',
    de: 'Beginne nah bei {x} und geh dann vorsichtig zurück.',
  ),
  (
    en: 'End your take with {x} filling the frame.',
    de: 'Beende deinen Take so, dass {x} das Bild füllt.',
  ),
];

Never fail(String message) => throw StateError(message);
String sql(String value) => value.replaceAll("'", "''");

void main() {
  if (subjects.length * frames.length != 400) {
    fail('Generator must create exactly 400 challenges.');
  }
  final start = DateTime.utc(2026, 9, 1);
  final challenges = <Map<String, Object?>>[];
  for (var subjectIndex = 0; subjectIndex < subjects.length; subjectIndex++) {
    for (var frameIndex = 0; frameIndex < frames.length; frameIndex++) {
      final index = subjectIndex * frames.length + frameIndex;
      final subject = subjects[subjectIndex];
      final frame = frames[frameIndex];
      final date = start.add(Duration(days: index));
      challenges.add({
        'challenge_date': date.toIso8601String().split('T').first,
        'title_en': frame.en.replaceAll('{x}', subject.en),
        'title_de': frame.de.replaceAll('{x}', subject.de),
        'description_en': 'Keep it safe, show no private documents or exact location, and finish in one seven-second take.',
        'description_de': 'Bleib sicher, zeig keine privaten Dokumente oder genauen Orte und filme alles in einem sieben-sekündigen Take.',
        'category': subject.category,
        'safety_notes':
            'No dangerous movement, private data, or exact location.',
        'status': index < 365 ? 'scheduled' : 'draft',
        'reserve': index >= 365,
      });
    }
  }
  validate(challenges);
  Directory('assets/data').createSync(recursive: true);
  File(
    'assets/data/challenges.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(challenges));
  final out = StringBuffer('-- Generated by tool/generate_challenges.dart.\n');
  out.writeln(
    'insert into public.challenges(challenge_date,title_en,title_de,description_en,description_de,category,safety_notes,status,publish_at,expires_at) values',
  );
  for (var index = 0; index < challenges.length; index++) {
    final item = challenges[index];
    final date = item['challenge_date']!;
    out.write(
      "('$date','${sql(item['title_en']! as String)}','${sql(item['title_de']! as String)}','${sql(item['description_en']! as String)}','${sql(item['description_de']! as String)}','${item['category']}','${sql(item['safety_notes']! as String)}','${item['status']}','$date 00:00:00+00'::timestamptz,'$date 00:00:00+00'::timestamptz + interval '1 day')",
    );
    out.writeln(index == challenges.length - 1 ? ';' : ',');
  }
  File('supabase/seed.sql').writeAsStringSync(out.toString());
  stdout.writeln(
    'Validated and wrote ${challenges.length} bilingual challenges (365 scheduled + 35 reserve).',
  );
}

void validate(List<Map<String, Object?>> values) {
  const categories = {
    'everyday',
    'funny',
    'creative',
    'reaction',
    'outdoors',
    'food',
    'sound',
    'movement',
    'friends',
    'observation',
    'wholesome',
    'weekend',
    'weird',
    'seasonal',
    'home',
    'workday',
    'pets',
    'view',
    'mood',
  };
  const banned = {
    'weapon',
    'nude',
    'address',
    'passport',
    'illegal',
    'dangerous stunt',
    'Waffe',
    'nackt',
    'Adresse',
    'Reisepass',
  };
  final english = <String>{};
  final german = <String>{};
  final dates = <String>{};
  for (final item in values) {
    final en = (item['title_en'] as String?)?.trim() ?? '';
    final de = (item['title_de'] as String?)?.trim() ?? '';
    final date = item['challenge_date'] as String? ?? '';
    if (en.isEmpty || de.isEmpty) {
      fail('Missing translation for $date');
    }
    if (en.length > 120 || de.length > 140) {
      fail('Title too long for $date');
    }
    if (!english.add(en.toLowerCase()) || !german.add(de.toLowerCase())) {
      fail('Duplicate challenge at $date');
    }
    if (!dates.add(date) || DateTime.tryParse(date) == null) {
      fail('Invalid or duplicate date $date');
    }
    if (!categories.contains(item['category'])) {
      fail('Missing category for $date');
    }
    if (banned.any(
      (term) =>
          en.toLowerCase().contains(term.toLowerCase()) ||
          de.toLowerCase().contains(term.toLowerCase()),
    )) {
      fail('Problematic term at $date');
    }
  }
  if (values.length != 400 ||
      values.where((item) => item['reserve'] == true).length < 35) {
    fail('Need 365 plus at least 35 reserve challenges.');
  }
}
