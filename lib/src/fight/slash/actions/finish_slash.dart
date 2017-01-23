import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/item.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/world.dart';
import 'package:edgehead/src/fight/damage_reports.dart';
import 'package:edgehead/src/fight/fight_situation.dart';
import 'package:edgehead/src/fight/slash/slash_situation.dart';

class FinishSlash extends EnemyTargetAction {
  @override
  final String helpMessage = null;

  FinishSlash(Actor enemy) : super(enemy);

  @override
  String get nameTemplate => "kill <object> "
      "(WARNING should not be user-visible)";

  @override
  String get rollReasonTemplate => "(WARNING should not be user-visible)";

  @override
  String applyFailure(Actor a, WorldState w, Storyline s) {
    throw new UnimplementedError();
  }

  @override
  String applySuccess(Actor a, WorldState w, Storyline s) {
    final extraForce = (w.currentSituation as SlashSituation).extraForce;
    final damage = extraForce ? 2 : 1;
    w.updateActorById(enemy.id, (b) => b..hitpoints -= damage);
    bool killed = !w.getActorById(enemy.id).isAlive;
    if (!killed) {
      a.report(
          s,
          "<subject> {slash<es>|cut<s>} <object's> "
          "{shoulder|abdomen|thigh}"
          "${extraForce ? ' with all <subjectPronoun\'s> {power|might}' : ''}",
          object: enemy,
          positive: true);
      reportPain(s, enemy);
    } else {
      a.report(
          s,
          "<subject> {slash<es>|cut<s>} "
          "{across|through} <object's> "
          "{neck|abdomen|lower body}"
          "${extraForce ? ' with all <subjectPronoun\'s> {power|might}' : ''}",
          object: enemy,
          positive: true);
      var groundMaterial =
          w.getSituationByName<FightSituation>("FightSituation").groundMaterial;
      reportDeath(s, enemy, groundMaterial);
    }
    return "${a.name} slashes${killed ? ' (and kills)' : ''} ${enemy.name}";
  }

  @override
  num getSuccessChance(Actor a, WorldState w) => 1.0;

  @override
  bool isApplicable(Actor a, WorldState w) => a.wields(ItemType.sword);

  static EnemyTargetAction builder(Actor enemy) => new FinishSlash(enemy);
}