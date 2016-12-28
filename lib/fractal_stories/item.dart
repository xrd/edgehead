library stranded.item;

import 'dart:math';

import 'actor.dart';
import 'storyline/storyline.dart';
import 'team.dart';

Random _random = new Random();

String typeToDescription(ItemType type) {
  switch (type) {
    case ItemType.SPEAR:
      return "spear";
    case ItemType.BRANCH:
      return "branch";
    case ItemType.TENT:
      return "tent";
    case ItemType.SWORD:
      return "sword";
    default:
      throw new ArgumentError(type);
  }
}

abstract class Item<T extends Item> extends Object
    with EntityBehavior
    implements Entity {
  final ItemType type;
  Item(this.type);

  String get description => typeToDescription(type);

  /// When `true`, having more of [this] makes the person happier.
  ///
  /// For example, having more of coins makes an [Actor] happier. On the other
  /// hand, having just one tent is enough -- it won't make the person
  /// happier to have 2 tents.
  bool get luxuryIsCumulative;

  /// This is the intrinsic value of the item.
  ///
  /// When [luxuryScore] is high, people (AI) will be more incentivized to
  /// get it. Sleeping in a tent (as opposed to 'below a tree branch') is
  /// a massive luxury improvement.
  ///
  /// Note that the way AI plans, items don't need to have their own (intrinsic)
  /// value to be wanted. Branch in itself doesn't help you, but it does get
  /// you to traps, which get you to food.
  num get luxuryScore;

  /// Makes a copy of instance. To be overridden by subclasses.
  T copy();
}

enum ItemType { SPEAR, BRANCH, TENT, SWORD }

class Sword extends Item {
  final bool luxuryIsCumulative = false;

  final num luxuryScore = 10;

  @override
  bool isActive = true;
  @override
  Team team = neutralTeam;

  final String name;

  Sword([this.name = "sword"]) : super(ItemType.SWORD);

  @override
  List<String> get categories => const [];

  @override
  int get id => hashCode;

  @override
  bool get isAlive => false;

  @override
  bool get isPlayer => false;

  @override
  bool get nameIsProperNoun => false;

  @override
  Pronoun get pronoun => Pronoun.IT;

  Sword copy() => new Sword();
}
