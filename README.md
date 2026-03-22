# Autonomous

A Godot 4 game about control, agency, and complicity.

---

## What it is

The game opens in action. You are placed into combat as a warrior named Litta — her movement, her fighting, her survival. You feel like her.

You are not her.

You are Folgim: one of the Aksjub, a species of colossal ancient beings who have ruled the galaxy for millennia through mind control. Every input you made was Folgim's reach into Litta's body. She was never yours to be. She was never free.

This is not a twist for its own sake. It is the game's philosophical core.

In every other medium, a character has their own autonomy. The audience observes. But in a game, the player *controls* the character. If you extend to a player character even the basic imaginative awareness you'd give any fictional being, that act of control starts to resemble something more troubling. *Autonomous* simply makes that impossible to ignore.

---

## Structure

The game operates across three tiers:

**Action segments** — Direct control of Litta in real-time. The only tier where the player has full, immediate, physical control of anything. This contrast is the point.

**Galactic map** — Turn-based management of Folgim's empire. Cold, vast, strategic. Monitor the repeater network that keeps Litta under control. Make decisions that ripple outward across planets and populations.

**Planetary zoom** — Real-time interaction with creature populations through *thought broadcasting*: the player types directives in natural language, an LLM interprets them into behavioural configuration changes, and the creatures respond. The player never commands — they author the emotional landscape that produces behaviour.

---

## The degradation system

The repeater network is the infrastructure of Folgim's grip on Litta. If it degrades, so does control:

- **0.0–0.2** — full control, no effect
- **0.2–0.4** — input lag, Litta hesitates before responding
- **0.4–0.6** — input drift, occasional wrong directions
- **0.6–0.8** — Litta stops, looks around, ignores commands for stretches
- **0.8–1.0** — Litta acts entirely on her own. The player watches.

Failing missions doesn't just cost resources. It gives Litta something: herself. The punishment for failure is that the puppet becomes a person. The game never tells you how to feel about that.

---

## Two paths

**Folgim's path** — Maintain the network, suppress anomalies, keep control. The empire grows. Litta remains devoted. The question this ending sits with is never asked aloud.

**Litta's path** — Let control degrade. Litta recovers herself — not as organised rebellion, but as something the galaxy has no category for. Her selfhood spreads through the empire as ideological infection. She doesn't rally armies. She introduces doubt into a galaxy where freedom has never existed as a concept.

---

## Tech

- **Engine**: Godot 4 (GDScript)
- **LLM**: Anthropic API — used for the thought-broadcasting mechanic in the planetary zoom tier
- **Platform**: Desktop (Windows / Mac)

---

## Status

Early development. Currently building Milestone 1: the opening action segment and the reframe moment. The goal is a playable vertical slice that demonstrates every major system before expanding scope.

This is a solo project. Scope is managed carefully.
