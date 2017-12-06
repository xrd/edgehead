import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:edgehead/edgehead_lib.dart';
import 'package:edgehead/egamebook/commands/commands.dart';
import 'package:edgehead/egamebook/elements/elements.dart';
import 'package:edgehead/fractal_stories/storyline/randomly.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:slot_machine/result.dart' as slot;

Future<Null> main(List<String> args) async {
  var automated = args.contains("--automated");
  var logged = args.contains("--log");
  RegExp actionPattern;
  if (args.contains("--action")) {
    int index = args.indexOf("--action");
    actionPattern = new RegExp(args[index + 1], caseSensitive: false);
  }

  File file;
  if (logged) {
    file = new File("edgehead.log");
  }
  final runner = new CliRunner(automated, automated, logged ? file : null,
      actionPattern: actionPattern);
  await runner.initialize(new EdgeheadGame(actionPattern: actionPattern));
  try {
    runner.startBook();
    await runner.bookEnd;
  } finally {
    runner.close();
  }
}

final _random = new Random();

class CliRunner extends Presenter<EdgeheadGame> {
  final bool automated;

  final File _logFile;

  final Pattern actionPattern;

  StreamSubscription _loggerSubscription;

  final Logger _log = new Logger("play_run");

  /// Silent mode can be overridden when [actionPattern] is encountered.
  bool _silent;

  /// Instantiate the runner.
  ///
  /// The runner will not print anything if [silent] is `true`.
  /// But, when [actionPattern] is encountered, the [silent] bit will
  /// flipped to true.
  CliRunner(this.automated, bool silent, File logFile,
      {Level logLevel: Level.FINE, this.actionPattern})
      : _logFile = logFile {
    _silent = silent;

    if (_logFile != null) {
      final now = new DateTime.now().toIso8601String();
      _logFile.writeAsStringSync("== $now ==");
      Logger.root.level = logLevel;
      _loggerSubscription = Logger.root.onRecord.listen((record) {
        _logFile.writeAsStringSync(
            '${record.time.toIso8601String()} - '
            '[${record.loggerName}] - '
            '[${record.level.name}] - '
            '${record.message}\n',
            mode: FileMode.APPEND);
      });
    }
  }

  @override
  void addChoiceBlock(ChoiceBlock element) {
    if (!_silent) {
      print("");
      for (int i = 0; i < element.choices.length; i++) {
        var helpMessage = element.choices[i].helpMessage ?? '';
        var shortened = helpMessage.split(' ').take(10).join(' ');
        print("${i + 1}) "
            "${element.choices[i].markdownText} ($shortened ...)");
      }
    }

    int option;

    if (automated && !book.actionPatternWasHit) {
      option = _random.nextInt(element.choices.length);
    } else if (element.choices.length == 1 &&
        element.choices.single.isAutomatic) {
      option = 0;
    } else {
      option = int.parse(stdin.readLineSync()) - 1;
      print("");
    }
    book.accept(
        new PickChoice((b) => b..choice = element.choices[option].toBuilder()));
  }

  @override
  void addCustomElement(ElementBase element) {
    if (element is StatUpdate) {
      _hijackedPrint(
          "=== Stat(${element.name}) updated to ${element.newValue} ===");
      return;
    }
    super.addCustomElement(element);
  }

  @override
  void addError(ErrorElement error) {
    _log.severe(error.message);
  }

  @override
  void addLog(LogElement log) {
    _log.info(log.level);
  }

  @override
  void addLose(LoseGame loseGame) {
    _hijackedPrint(loseGame.markdownText);
    _hijackedPrint("=== YOU LOSE ===");
  }

  @override
  void addSavegameBookmark(SaveGame savegame) {
    throw new UnimplementedError(savegame.toString());
  }

  @override
  void addSlotMachine(SlotMachine element) {
    final result = _showSlotMachine(element.probability, element.rollReason,
        rerollable: element.rerollable,
        rerollEffectDescription: element.rerollEffectDescription);
    result.then((sessionResult) {
      book.accept(new ResolveSlotMachine((b) => b
        ..result = sessionResult.result
        ..wasRerolled = sessionResult.wasRerolled));
    });
  }

  @override
  void addText(TextOutput text) {
    _hijackedPrint(text.markdownText);
  }

  @override
  void addWin(WinGame winGame) {
    _hijackedPrint(winGame.markdownText);
    _hijackedPrint("=== YOU WIN ===");
  }

  @override
  void beforeElement() {
    if (book.actionPatternWasHit) _silent = false;
  }

  @override
  void close() {
    super.close();
    book.close();
    _loggerSubscription?.cancel();
  }

  void _hijackedPrint(Object msg) {
    _log.info(msg);
    if (!_silent) print(msg);
  }

  Future<slot.SessionResult> _showSlotMachine(
      double probability, String rollReason,
      {bool rerollable, String rerollEffectDescription}) async {
    var msg = "[[ SLOT MACHINE '$rollReason' "
        "${probability.toStringAsPrecision(2)} "
        "$rerollEffectDescription "
        "(enabled: ${rerollable ? 'on' : 'off'}) ]]";
    _log.info(msg);
    if (!_silent) {
      print("$msg\n");
    }

    var success = Randomly.saveAgainst(probability);
    var initialResult = new slot.SessionResult(
        success ? slot.Result.success : slot.Result.failure, false);
    _log.info('result = $initialResult');

    if (success) {
      // Success of initial roll.
      if (!_silent) {
        print("result = $initialResult");
      }
      return initialResult;
    } else {
      // Failure of initial roll.
      if (_silent) {
        // We're in silent mode. TODO: figure out if we want to reroll
        return initialResult;
      }
      print("Initial roll failure.");

      if (rerollable) {
        print(rerollEffectDescription);
        print("Reroll? (y/n)");
        var input = stdin.readLineSync().trim().toLowerCase();
        if (input != 'y') {
          print('No reroll');
          return initialResult;
        }

        var rerollSuccess = Randomly.saveAgainst(1 - pow(1 - probability, 2));
        if (rerollSuccess) {
          print("Reroll success!");
          return new slot.SessionResult(slot.Result.success, true);
        }
        print("Reroll failure.");
        return new slot.SessionResult(slot.Result.failure, true);
      }

      print("Reroll impossible. So: $initialResult");
      return initialResult;
    }
  }
}

/// UI of the book. Egamebook UIs, be they CLI-based, web-based or Flutter-based
/// all need to subclass [Presenter].
abstract class Presenter<T extends Book> implements Sink<ElementBase> {
  @protected
  T book;

  final Completer<Null> _bookEndCompleter = new Completer<Null>();

  StreamSubscription<ElementBase> _bookSubscription;

  /// Future completes when the underlying [book] ends, either with [WinGame]
  /// or with [LoseGame].
  ///
  /// After this future completes, the caller should call [close]. This will
  /// close both the [book] and this [Presenter]. Once this happens, there is
  /// no way to restart either. You have to create new ones.
  Future<Null> get bookEnd => _bookEndCompleter.future;

  @protected
  @override
  void add(ElementBase element) {
    beforeElement();

    if (element is TextOutput) {
      addText(element);
      return;
    }

    if (element is WinGame) {
      addWin(element);
      _bookEndCompleter.complete();
      return;
    }

    if (element is LoseGame) {
      addLose(element);
      _bookEndCompleter.complete();
      return;
    }

    if (element is ChoiceBlock) {
      addChoiceBlock(element);
      return;
    }

    if (element is SlotMachine) {
      addSlotMachine(element);
      return;
    }

    if (element is SaveGame) {
      addSavegameBookmark(element);
      return;
    }

    addCustomElement(element);
  }

  @protected
  void addChoiceBlock(ChoiceBlock block);

  /// Implementor of a [Presenter] must make sure that any elements coming
  /// from the game are handled here.
  ///
  /// For example, stats updates, map updates, custom animations, etc.
  ///
  /// This method is annotated with [mustCallSuper] so that implementers never
  /// forget to raise an error when there is an element that this presenter
  /// cannot handle. Failing fast is much better than ignoring an entire
  /// class of book elements.
  @protected
  @mustCallSuper
  void addCustomElement(ElementBase element) {
    throw new UnimplementedError("Unexpected type of element: $element");
  }

  @protected
  void addError(ErrorElement error);

  @protected
  void addLog(LogElement log);

  @protected
  void addLose(LoseGame loseGame);

  @protected
  void addSavegameBookmark(SaveGame savegame);

  @protected
  void addSlotMachine(SlotMachine machine);

  @protected
  void addText(TextOutput text);

  @protected
  void addWin(WinGame winGame);

  void beforeElement();

  @override
  @mustCallSuper
  void close() {
    book.close();
    _bookSubscription.cancel();
  }

  @mustCallSuper
  Future<Null> initialize(T book) {
    assert(this.book == null, "Cannot reuse Presenter several times.");
    this.book = book;
    _bookSubscription = book.elements.listen(add);
    return new Future<Null>.value();
  }

  void startBook() {
    assert(book != null, "Call and await initialize() first");
    book.start();
  }
}
