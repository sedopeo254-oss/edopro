# YRPX Replay Compatibility

This branch keeps the `Temporary replay source export #13` YRPX container as
its compatibility baseline. The binary container is unchanged: every streamed
packet remains encoded as a one-byte message identifier, a four-byte payload
length and the payload itself.

## Reader profiles

The reader determines the replay profile from data, not from the client build
number:

- **Legacy / schema 0:** no multiplayer private-pile packets. The reader keeps
  the original `TAG_SWAP` and normal draw behavior.
- **Source export #13 / schema 1:** inferred when messages 192–196 are present.
  Private piles, logical turns, logical draws, Deck Masters and replay-view
  hints use the corrected 3v1 projection paths.
- **Capability envelope / schema 2+:** new recordings start with message 197,
  which declares the schema, minimum reader schema and a 64-bit capability
  mask. The packet is length-prefixed and old readers can skip it.

## Backward compatibility

Known pre-#13 and #13 recordings do not need conversion. Schema 0 replays use
legacy fallbacks; schema 1 is inferred from packet presence before playback.
This prevents a modern-only snapshot path from swallowing legacy draws or
`TAG_SWAP` events.

## Forward compatibility

Message identifiers 197–230 are reserved for additive replay extensions.
Unknown extension packets are skipped without pausing or desynchronizing the
stream because their payload length is known. Known capability bits remain
usable even when a future writer adds unknown bits.

A future replay that declares a minimum reader schema newer than this build is
opened in best-effort mode and marked as requiring a newer semantic reader.
Additive packets remain safe. A fundamentally incompatible future container,
encryption scheme, or changed meaning of an existing packet still requires a
new adapter; no present-day client can guarantee exact interpretation of an
unknown breaking semantic change.

## Current capabilities

- logical turn ownership
- logical draw ownership
- independent Deck Master state
- private Deck/Hand/Extra/GY/Banish snapshots
- replay view hints
- logical location and damage routing
- public card codes for face-up Special Summons
- length-prefixed extension skipping
