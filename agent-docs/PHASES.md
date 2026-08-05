# Game Phases & Transitions

Phase flow is owned by the C engine in `engine/KolkhozCEngine/`. Flutter renders the
current projected phase and submits legal C actions. Research code consumes the same
phase flow through the Python `ctypes` wrapper.

## Phase Flow Diagram

```text
                        +--------------+
                        |   planning   |
                        |  set trump   |
                        +------+-------+
                               |
              +----------------+----------------+
              | year > 1 && pass variant?       |
              +----------------+----------------+
                    yes        |        no
                     v         |         |
              +----------+     |         |
              |   pass   |-----+         |
              +----+-----+               |
                   |                     |
                   v                     v
              +----------------+----------------+
              | year > 1 && allowSwap variant?  |
              +----------------+----------------+
                    yes        |        no
                     v         |         v
              +----------+     |    +----------+
              |   swap   |-----+--->|  trick   |
              +----+-----+          +----+-----+
                   |                     |
                   +---------------------+
                               |
                               v
                        +--------------+
                        |    trick     |<----------+
                        | play cards   |           |
                        +------+-------+           |
                               |                   |
                               v                   |
                        +--------------+           |
                        | assignment   |           |
                        | assign work  |           |
                        +------+-------+           |
                               |                   |
              +----------------+----------------+  |
              | year complete?                  |  |
              +----------------+----------------+  |
                    yes        |        no         |
                     v         |         +---------+
              +---------------+
              | move hands to |
              | hidden plots  |
              +-------+-------+
                      |
                      v
              +---------------+
              | requisition   |
              | exile cards   |
              +-------+-------+
                      |
        +-------------+-------------+
        | year after increment <= 5 |
        +-------------+-------------+
              yes     |      no
               v      |       v
        +----------+  |  +----------+
        | planning |  |  | gameOver |
        +----------+  |  +----------+
```

## Phase Definitions

### 1. Planning

Reveal jobs and set trump. With Final Year Trump enabled, the fifth-year leftover deal
card is public and sets trump automatically; a revealed Saboteur means no trump. The card
is then sent North and has no other effect. Otherwise famine has no trump and advances
automatically. AI trump selection is implemented in the C engine.

With Managed Economy in years 1-4, reveal all four reward offers publicly in their crop
slots. The Central Planner may provisionally swap any reward with a matching-suit card
from their hand; leaving a slot untouched keeps its reward, swaps may be repeated or
reversed, and Saboteur matches every crop. The replaced reward enters the Planner's
hand. The Planner confirms the complete reward layout, then selects trump. Only after
both decisions are public does the game advance to the other players' plot swaps.
The four aces were dealt to player plots during setup, with the clubs/Wheat ace revealed
to identify the first Planner. Year 5 reveals no rewards and advances through famine
planning normally.

### 2. Pass

When enabled, every player privately selects one hand card in years 2-5. Selections lock
independently and all four cards move simultaneously: left in years 2 and 4, right in
years 3 and 5. Any card, including Saboteur, may be passed.

### 3. Swap

Each player may exchange at most one hand card with a hidden or revealed plot card when
`allow_swap` is enabled. Human/manual callers submit `swap`, `undoSwap`, and
`confirmSwap` actions; AI turns are automatic.

With Managed Economy in years 1-4, the Central Planner is pre-confirmed and the other
three players swap normally, including year 1 because each begins with an ace in their
plot. All four players use the normal swap flow in year 5.

### 4. Trick

Players play one card each. The engine validates follow-suit, resolves trump/lead-suit
winner, awards a medal, stores `last_trick`, and enters assignment.

### 5. Assignment

The trick winner assigns captured cards to jobs. Legal target suits are only the suits
present in the completed trick. Every unassigned trick card may be assigned to any legal
target suit. Once all cards have pending targets, `submitAssignments` applies work and
claims rewards.

### 6. Year-End Hand Movement

There is no plot-selection phase. When a year is complete, the engine moves remaining
hand cards into hidden plots before requisition.

With Managed Economy, unclaimed rewards are shuffled back into the worker deck for the
next deal instead of being sent North.

### 7. Requisition

Failed jobs may reveal and exile matching plot cards. Drunkard, Informant, Party
Official, mice, northern style, and hero immunity behavior all live in the C engine.

The active failed crop suits form one eligible pool. Each medal holder loses their highest
eligible card once per Medal they hold. The medal holders then privately nominate their
highest remaining eligible cards once per active failed crop; the global highest goes
North, including ties, and lower Cellar nominations remain face up. Informant expands its
field's comparison to all players and that comparison resolves first. Party Official adds
one comparison; when sharing the Informant field, that expanded comparison resolves next.
A Hero sweep replaces the entire sequence: each non-Hero loses one highest eligible card
per Hero Medal and no comparisons occur. Northern Style and Mice retain their universal
individual-loss behavior. Drunkard removes its crop from the pool and comparison count.

### 8. Game Over

After year 5 requisition, the engine calculates final scores and winner.

## Phase Transition Gotchas

### Famine

Famine is year 5. It means:

- 3 tricks instead of 4;
- normally no trump suit, unless Final Year Trump reveals an ordinary crop card;
- 4 cards dealt per player instead of 5.
- with Managed Economy, no job reward cards are available.

### Assignment Targets

Legal assignment targets are only the suits present in the completed trick. Do not
reintroduce older assignment rules.

Saboteur counts as matching every crop suit for this check. A completed trick containing
Saboteur makes every crop suit a legal assignment target even though Saboteur is not a fifth
job suit.

### Requisition Timing

The engine records exiled cards and events immediately, but plot cards remain visible for
the requisition screen until the user continues.

A job containing Saboteur is requisitioned as failed even if it reached 40 work hours and
claimed its reward. A plot Saboteur matches any failed job, but a specific Saboteur card is
exiled only once in a year's requisition report. Hero immunity fully protects the Hero
from that failure.

### Swap Is Sequential

The app processes swap confirmations in player order. AI players are automatic.

### Pass Is Simultaneous

Pass selections are private until all four players have locked a card. The server redacts
each selection from other viewers, and the engine resolves all four transfers together.

## Debugging Phase Issues

Check:

```text
phase
year and trick_count
trump and famine
current_player and lead
hand counts
current_trick and last_trick counts
pending_assignment_targets
```
