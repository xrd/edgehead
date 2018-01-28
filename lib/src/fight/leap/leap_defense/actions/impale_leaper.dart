import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/pose.dart';
import 'package:edgehead/fractal_stories/simulation.dart';
import 'package:edgehead/fractal_stories/storyline/randomly.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/world_state.dart';
import 'package:edgehead/src/fight/common/defense_situation.dart';
import 'package:edgehead/src/fight/common/weapon_as_object2.dart';
import 'package:edgehead/src/fight/humanoid_pain_or_death.dart';
import 'package:edgehead/writers_helpers.dart';

EnemyTargetAction impaleLeaperBuilder(Actor enemy) => new ImpaleLeaper(enemy);

class ImpaleLeaper extends EnemyTargetAction {
  static const String className = "ImpaleLeaper";

  @override
  final String helpMessage = "You can move your weapon to point at "
      "the attacker. If successful, the weapon will pierce the attacker "
      "with the force of his own leap.";

  @override
  final bool isAggressive = false;

  @override
  final bool isProactive = false;

  @override
  final bool rerollable = true;

  @override
  final Resource rerollResource = Resource.stamina;

  ImpaleLeaper(Actor enemy) : super(enemy);

  @override
  String get commandTemplate => "impale";

  @override
  String get name => className;

  @override
  String get rollReasonTemplate => "will <subject> impale <objectPronoun>?";

  @override
  String applyFailure(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    final thread = getThreadId(sim, w, "LeapSituation");
    a.report(
        s,
        "<subject> tr<ies> to {move|swing|shift} "
        "${weaponAsObject2(a)} between <subjectPronounSelf> "
        "and <object>",
        object: enemy,
        actionThread: thread,
        isSupportiveActionInThread: true);
    if (a.isOffBalance) {
      a.report(s, "<subject> <is> out of balance",
          but: true, actionThread: thread, isSupportiveActionInThread: true);
    } else {
      Randomly.run(
          () => a.report(s, "<subject> {can't|fail<s>|<does>n't succeed}",
              but: true,
              actionThread: thread,
              isSupportiveActionInThread: true),
          () => a.report(s, "<subject> {<is> too slow|<is>n't fast enough}",
              but: true,
              actionThread: thread,
              isSupportiveActionInThread: true));
    }
    w.popSituation(sim);
    return "${a.name} fails to impale ${enemy.name}";
  }

  @override
  String applySuccess(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    final thread = getThreadId(sim, w, "LeapSituation");
    a.report(
        s,
        "<subject> {move<s>|swing<s>|shift<s>} "
        "${weaponAsObject2(a)} between <subjectPronounSelf> "
        "and <object>",
        object: enemy,
        positive: true,
        actionThread: thread);
    enemy.report(s, "<subject> {leap<s>|run<s>|lunge<s>} right into it",
        negative: true);
    final damage = 1;
    w.updateActorById(
        enemy.id,
        (b) => b
          ..hitpoints -= damage
          ..pose = Pose.onGround);
    final updatedEnemy = w.getActorById(enemy.id);
    bool killed = !updatedEnemy.isAlive && updatedEnemy.id != brianaId;
    if (!killed) {
      a.currentWeapon.report(
          s,
          "<subject> {cut<s> into|pierce<s>|go<es> into} "
          "<object's> flesh",
          object: updatedEnemy);
      updatedEnemy.report(s, "<subject> fall<s> to the ground");
      reportPain(context, updatedEnemy, damage);
    } else {
      a.currentWeapon.report(
          s,
          "<subject> {go<es> right through|completely impale<s>|"
          "bore<s> through} <object's> {body|chest|stomach|neck}",
          object: updatedEnemy);
      updatedEnemy.report(s, "<subject> go<es> down", negative: true);
      killHumanoid(context, updatedEnemy);
    }

    w.popSituationsUntil("FightSituation", sim);
    return "${a.name} impales ${enemy.name}";
  }

  @override
  num getSuccessChance(Actor a, Simulation sim, WorldState w) {
    num outOfBalancePenalty = a.isStanding ? 0 : 0.2;
    num enemyJumpedFromGroundBonus = enemy.isOnGround ? 0.2 : 0;
    if (a.isPlayer) {
      return 0.5 - outOfBalancePenalty + enemyJumpedFromGroundBonus;
    }
    final situation = w.currentSituation as DefenseSituation;
    return situation.predeterminedChance
        .or(0.4 - outOfBalancePenalty + enemyJumpedFromGroundBonus);
  }

  @override
  bool isApplicable(Actor a, Simulation sim, WorldState w) =>
      !a.isOnGround && a.currentWeapon.isThrusting;
}
