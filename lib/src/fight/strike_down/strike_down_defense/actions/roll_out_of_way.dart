import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/context.dart';
import 'package:edgehead/fractal_stories/pose.dart';
import 'package:edgehead/fractal_stories/simulation.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/world_state.dart';
import 'package:edgehead/src/fight/common/defense_situation.dart';

EnemyTargetAction rollOutOfWayBuilder(Actor enemy) => new RollOutOfWay(enemy);

class RollOutOfWay extends EnemyTargetAction {
  static const String className = "RollOutOfWay";

  @override
  final String helpMessage = null;

  @override
  final bool isAggressive = false;

  @override
  final bool isProactive = false;

  @override
  final bool rerollable = true;

  @override
  final Resource rerollResource = Resource.stamina;

  RollOutOfWay(Actor enemy) : super(enemy);

  @override
  String get commandTemplate => "roll out of way";

  @override
  String get name => className;

  @override
  String get rollReasonTemplate =>
      "will <subject> evade?"; // TODO: come up with something

  @override
  String applyFailure(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    a.report(s, "<subject> tr<ies> to roll out of the way");
    a.report(s, "<subject> can't", but: true);
    w.popSituation(sim);
    return "${a.name} fails to roll out of the way";
  }

  @override
  String applySuccess(ActionContext context) {
    Actor a = context.actor;
    Simulation sim = context.simulation;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    a.report(s, "<subject> <is> able to roll out of the way",
        but: true, positive: true);
    if (a.isPlayer) {
      w.updateActorById(a.id, (b) => b..pose = Pose.standing);
      a.report(s, "<subject> jump<s> up on <subject's> feet", positive: true);
    }
    w.popSituationsUntil("FightSituation", sim);
    return "${a.name} rolls out of the way of ${enemy.name}'s strike";
  }

  @override
  num getSuccessChance(Actor a, Simulation sim, WorldState w) {
    if (a.isPlayer) return 0.98;
    final situation = w.currentSituation as DefenseSituation;
    return situation.predeterminedChance.or(0.5);
  }

  @override
  bool isApplicable(Actor actor, Simulation sim, WorldState world) => true;
}
