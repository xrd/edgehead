import 'package:edgehead/fractal_stories/action.dart';
import 'package:edgehead/fractal_stories/actor.dart';
import 'package:edgehead/fractal_stories/context.dart';
import 'package:edgehead/fractal_stories/pose.dart';
import 'package:edgehead/fractal_stories/storyline/storyline.dart';
import 'package:edgehead/fractal_stories/team.dart';
import 'package:edgehead/fractal_stories/simulation.dart';
import 'package:edgehead/fractal_stories/world_state.dart';
import 'package:edgehead/src/fight/fight_situation.dart';
import 'package:edgehead/src/fight/off_balance_opportunity/off_balance_opportunity_situation.dart';

final Entity balance =
    new Entity(name: "balance", team: neutralTeam, nameIsProperNoun: true);

final Entity pounding = new Entity(name: "pounding", team: neutralTeam);

class Pound extends EnemyTargetAction {
  static const String className = "Pound";

  @override
  final bool rerollable = true;

  @override
  final Resource rerollResource = Resource.stamina;

  @override
  final bool isAggressive = true;

  @override
  final bool isProactive = true;

  @override
  String helpMessage = "Forcing enemies off balance often means hitting them "
      "heavily several times in a row. The goal is not to deal damage but to "
      "force the opponent to lose control of their combat stance. It can also "
      "give members of your party an opportunity to strike.";

  Pound(Actor enemy) : super(enemy);

  @override
  String get commandTemplate => "force <object> off balance";

  @override
  String get name => className;

  @override
  String get rollReasonTemplate => "will <subject> force "
      "<object> off balance?";

  @override
  String applyFailure(ActionContext context) {
    Actor a = context.actor;
    Storyline s = context.outputStoryline;
    a.report(
        s,
        "<subject> {fiercely|violently} "
        "{strike<s>|hammer<s>|batter<s>} "
        "on <object-owner's> "
        "{<object>|weapon}",
        objectOwner: enemy,
        object: enemy.currentWeapon);
    enemy.report(
        s,
        "<subject> {retain<s>|keep<s>} "
        "<subject's> {|combat} {stance|footing}",
        positive: true);
    return "${a.name} kicks ${enemy.name} off balance";
  }

  @override
  String applySuccess(ActionContext context) {
    Actor a = context.actor;
    WorldStateBuilder w = context.outputWorld;
    Storyline s = context.outputStoryline;
    a.report(
        s,
        "<subject> {fiercely|violently} "
        "{strike<s>|hammer<s>|batter<s>} "
        "on <object-owner's> "
        "{<object>|weapon}",
        objectOwner: enemy,
        object: enemy.currentWeapon);
    if (enemy.isStanding) {
      enemy.report(s, "<subject> lose<s> <object>",
          object: balance, negative: true);
      w.updateActorById(enemy.id, (b) => b..pose = Pose.offBalance);

      var situation =
          new OffBalanceOpportunitySituation.initialized(enemy, culprit: a);
      w.pushSituation(situation);
      return "${a.name} pounds ${enemy.name} off balance";
    } else if (enemy.isOffBalance) {
      enemy.report(s, "<subject> <is> already off balance");
      var groundMaterial = getGroundMaterial(w);
      s.add(
          "<subject> make<s> <object> fall "
          "to the $groundMaterial",
          subject: pounding,
          object: enemy);
      w.updateActorById(enemy.id, (b) => b..pose = Pose.onGround);

      return "${a.name} pounds ${enemy.name} to the ground";
    }
    throw new StateError("enemy pose must be either standing or off-balance");
  }

  @override
  num getSuccessChance(Actor a, Simulation sim, WorldState world) {
    num outOfBalancePenalty = a.isStanding ? 0 : 0.2;
    if (a.isPlayer) return 0.9 - outOfBalancePenalty;
    return 0.5 - outOfBalancePenalty;
  }

  @override
  bool isApplicable(Actor a, Simulation sim, WorldState world) =>
      !a.isOnGround &&
      (a.currentWeapon.isSlashing || a.currentWeapon.isBlunt) &&
      (enemy.currentWeapon.type.canParrySlash ||
          enemy.currentWeapon.type.canParryBlunt) &&
      !enemy.isOnGround;

  static EnemyTargetAction builder(Actor enemy) => new Pound(enemy);
}
