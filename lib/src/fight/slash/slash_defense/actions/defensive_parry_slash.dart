import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/context.dart';
import 'package:edgehead/fractal_stories/pose.dart';
import 'package:edgehead/fractal_stories/simulation.dart';
import 'package:edgehead/fractal_stories/storyline/randomly.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/world_state.dart';
import 'package:edgehead/src/fight/common/defense_situation.dart';
import 'package:edgehead/src/fight/common/weapon_as_object2.dart';

EnemyTargetAction defensiveParrySlashBuilder(Actor enemy) =>
    new DefensiveParrySlash(enemy);

class DefensiveParrySlash extends EnemyTargetAction {
  static const String className = "DefensiveParrySlash";

  @override
  final String helpMessage = "Stepping back is the safest way to get out of "
      "harm's way.";

  @override
  final bool isAggressive = false;

  @override
  final bool isProactive = false;

  @override
  final bool rerollable = true;

  @override
  final Resource rerollResource = Resource.stamina;

  DefensiveParrySlash(Actor enemy) : super(enemy);

  @override
  String get commandTemplate => "step back and parry";

  @override
  String get name => className;

  @override
  String get rollReasonTemplate => "will <subject> parry it?";

  @override
  String applyFailure(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    a.report(
        s,
        "<subject> tr<ies> to {parry|deflect it|"
        "meet it with ${weaponAsObject2(a)}|"
        "fend it off}");
    if (a.isOffBalance) {
      a.report(s, "<subject> <is> out of balance", but: true);
    } else {
      Randomly.run(
          () => a.report(s, "<subject> {fail<s>|<does>n't succeed}", but: true),
          () => enemy.report(s, "<subject> <is> too quick for <object>",
              object: a, but: true));
    }
    w.popSituation(sim);
    return "${a.name} fails to parry ${enemy.name}";
  }

  @override
  String applySuccess(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    if (a.isPlayer) {
      a.report(s, "<subject> {step<s>|take<s> a step} back");
    }
    a.report(
        s,
        "<subject> {parr<ies> it|deflect<s> it|"
        "meet<s> it with ${weaponAsObject2(a)}|"
        "fend<s> it off}",
        positive: true);

    if (!a.isStanding) {
      w.updateActorById(a.id, (b) => b..pose = Pose.standing);
      if (a.isPlayer) {
        a.report(s, "<subject> regain<s> balance");
      }
    }
    w.popSituationsUntil("FightSituation", sim);
    return "${a.name} steps back and parries ${enemy.name}";
  }

  @override
  num getSuccessChance(Actor a, Simulation sim, WorldState w) {
    if (a.isPlayer) return 0.98;
    final situation = w.currentSituation as DefenseSituation;
    num outOfBalancePenalty = a.isStanding ? 0 : 0.2;
    return situation.predeterminedChance.or(0.5 - outOfBalancePenalty);
  }

  @override
  bool isApplicable(Actor a, Simulation sim, WorldState w) =>
      a.currentWeapon.type.canParrySlash;
}
