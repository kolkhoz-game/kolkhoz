import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';

class RuleSummary {
  const RuleSummary({
    required this.iconPath,
    required this.titleKey,
    required this.bodyKey,
  });

  final String iconPath;
  final KolkhozText titleKey;
  final KolkhozText bodyKey;

  String title(KolkhozLanguage language) => language.t(titleKey);

  String body(KolkhozLanguage language) => language.t(bodyKey);
}

const optionsRuleSummaries = [
  RuleSummary(
    iconPath: fieldPlanNavigationJobsPath,
    titleKey: KolkhozText.ruleSummary6Title,
    bodyKey: KolkhozText.ruleSummary6Body,
  ),
  RuleSummary(
    iconPath: fieldPlanPlotIconPath,
    titleKey: KolkhozText.ruleSummary7Title,
    bodyKey: KolkhozText.ruleSummary7Body,
  ),
  RuleSummary(
    iconPath: 'assets/ui/Icons/icon-warning.png',
    titleKey: KolkhozText.ruleSummary8Title,
    bodyKey: KolkhozText.ruleSummary8Body,
  ),
];

enum RulebookBlockKind {
  sectionTitle,
  subsectionTitle,
  groupTitle,
  paragraph,
  bullet,
}

class RulebookBlock {
  const RulebookBlock(this.kind, this.text);

  final RulebookBlockKind kind;
  final String text;
}

const kolkhozBaseRulebookTitle = 'Kolkhoz (Колхоз)';
const kolkhozBaseRulebookPlayerCount =
    '3 or 4 players, standard deck of cards plus a joker, '
    '4 medal cards';

const kolkhozBaseRulebook = [
  RulebookBlock(
    RulebookBlockKind.sectionTitle,
    '1. Game Setup (Игровой Набор):',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'For each suit, set aside the Ace through 4 and one randomly selected '
    'card from 5 through King, keeping this randomly selected card hidden '
    'from all players. Shuffle those five cards together to form a '
    'separate face-down reward pile beside that suit’s field.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Shuffle the remaining cards to form the Workers Deck (Колода Рабочих). '
    'Shuffle a joker (вредитель) into the deck. The joker counts as 0 of '
    'every suit (simultaneously). During the requisition (Ищут врагов '
    'народа), if the joker has been assigned to a field (поля), that job '
    'fails regardless of the number of work hours it may have otherwise '
    '(though the reward can still be claimed).',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Each player has a designated area in front of them for their scoring '
    'cards, split into two sections, called their cellar (подвал) '
    '(face down cards, hidden from other players) and their plot '
    '(face up cards, visible to everyone).',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Designate an area of the table as the north (face up cards that have '
    'been removed from the game).',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Choose a player to be the first central planner (Центральный Плановик) '
    '(dealer). This can be done randomly or by agreement.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The game is played over five rounds (years). After five years, the '
    'player with the highest total value in their cellar and plot wins.',
  ),
  RulebookBlock(
    RulebookBlockKind.sectionTitle,
    '2. Playing a Year (Ход Игры):',
  ),
  RulebookBlock(
    RulebookBlockKind.paragraph,
    'Each year is split into 4 tricks except the fifth, which has only 3.',
  ),
  RulebookBlock(
    RulebookBlockKind.subsectionTitle,
    'a. Planning Phase (Фаза Планирования):',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The central planner deals 5 cards face-down to each player. During the '
    'fifth year, it is a “year of no harvest” (Год неурожая) and only '
    'four cards are dealt to each player and only 3 tricks (пора) are '
    'played.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The central planner reveals the top card (Карты Плановых Заданий) for '
    'each of the four fields from the four piles set aside at the start '
    'of the game. The revealed card is that field’s reward for the year. '
    'If claimed, it is added face up to the Brigadier’s plot and scores '
    'its face value at the end of the game.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'During years one through four, the Central Planner chooses one of the '
    'four suits as trump. During the fifth year, reveal the top card of '
    'the Workers Deck after dealing; its suit is trump. Send that card '
    'North. If it is the Joker, there is no trump.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'After the first year, starting with the player to the left of the '
    'central planner, players may then swap (Поменять шило на мыло) one '
    'of the cards in their hand with one of the cards in their cellar or '
    'plot. The card taken from the cellar or plot enters the player’s '
    'hand. The card replacing it is placed face-down in the cellar or '
    'face-up in the plot, matching the card removed.',
  ),
  RulebookBlock(RulebookBlockKind.subsectionTitle, 'b. Tricks (пора):'),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The player to the Central Planner’s left leads the first trick.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Players must follow suit if able (since the joker is every suit, it can '
    'always follow suit, and when played counts as a 0 of the trump '
    'suit); otherwise, they may play any card. If the Joker is led, every '
    'suit is considered led, so any card may follow.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The highest-ranking card of the lead suit, or the highest ranking trump '
    'card if trump was played, wins the trick '
    '(A/J/Q/K/Joker are 1/11/12/13/0).',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The winner becomes the brigadier (Бригадир) of the trick, takes a medal '
    'card, and gathers the cards played in the trick for assignment.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The Brigadier must assign every card from the trick (назначить '
    'добровольцев). Each card may be assigned to any field whose suit '
    'appeared anywhere in the trick (remember that the joker is every '
    'suit, so if the joker appears in the trick, cards from that trick '
    'may be sent to any field); the assigned card’s own suit does not '
    'restrict where it may go.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'If the total work hours from workers in a field, either previously '
    'assigned or assigned from this trick, meets or exceeds the '
    'Work-Hours threshold for the field (40 hours for 4 players, '
    '32 hours for 3 players) (J/Q/K/Joker give 11/12/13/0 hours) the '
    'brigadier immediately adds the reward card for that field to their '
    'plot face-up.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The brigadier then leads the next trick.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Four tricks are played in total (except in the fifth year, during which '
    '3 are played).',
  ),
  RulebookBlock(
    RulebookBlockKind.subsectionTitle,
    'c. Уносить, что под руку попадётся:',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'After the final trick, each player adds their one remaining card from '
    'that hand to their cellar, keeping it hidden.',
  ),
  RulebookBlock(
    RulebookBlockKind.subsectionTitle,
    'd. Requisition (Ищут врагов народа):',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Count the number of failed fields (fields with fewer than the required '
    'work hours assigned, or containing the joker). Each player who was '
    'a brigadier during the year (they will have a medal) sends to the '
    'North (отправить на Север) that many cards: the highest cards they '
    'possess in their cellar and plot among all suits corresponding to '
    'failed fields. If a player has fewer eligible cards than the number '
    'of failed jobs, they send all of them. If a player has equally '
    'ranked eligible cards, they may decide which one(s) are sent north.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Hero of Socialist Labor (стахановец): If a player won every trick in '
    'the year, all other players are requisitioned instead of them, '
    'regardless of if they were a brigadier or not.',
  ),
  RulebookBlock(
    RulebookBlockKind.subsectionTitle,
    'e. End of Year (Конец Раунда):',
  ),
  RulebookBlock(RulebookBlockKind.groupTitle, 'Years 1-4'),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'All unclaimed reward cards for the year are sent to the north.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Players return any claimed medals to the supply.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The role of central planner passes to the player to the left.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'The central planner gathers every card assigned to a field and every '
    'undealt Worker card that is not in a cellar, a plot, or the North, '
    'then shuffles them to form the new Workers Deck.',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Begin the next year with the Planning Phase',
  ),
  RulebookBlock(RulebookBlockKind.groupTitle, 'Year 5'),
  RulebookBlock(RulebookBlockKind.bullet, 'proceed to the End of Game'),
  RulebookBlock(
    RulebookBlockKind.sectionTitle,
    '3. End of Game (Конец Игры и Итоговый Подсчет Очков):',
  ),
  RulebookBlock(
    RulebookBlockKind.paragraph,
    'After the completion of the fifth year, players calculate their final '
    'scores:',
  ),
  RulebookBlock(
    RulebookBlockKind.bullet,
    'Sum the face values of the cards (J/Q/K/Joker are 11/12/13/0) remaining '
    'in their cellar and plot. This includes hidden cards and revealed '
    'cards. The player with the highest total wins. If there is a tie, '
    'the player with the most cards in their cellar and plot wins. If '
    'there is still a tie, then both players are sent to the north and '
    'the player with the next highest amount wins.',
  ),
];
