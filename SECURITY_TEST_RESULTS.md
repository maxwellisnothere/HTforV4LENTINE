# Client-side security checks

Report updated: 2026-11-04 (Asia/Bangkok).

This report records bounded tests initiated through the game client. It is not a server-source review or a certification that every game system is secure. No new production duplication or privilege-escalation vulnerability was demonstrated in this round.

## Latest completed round

The completed round sent **17 requests**: 14 negative checks, followed by three requests to validate normal loadout saving, test a locked slot, and remove the temporary saved loadout. Each negative check compared replicated state before and after, including currencies, inventory, gear, storage, loadouts and Battle Pass state. Requests were spaced out; this was not a load test.

| Area | Checks | Observed result | Limit of the evidence |
|---|---:|---|---|
| Mail | 3 | Unknown mail reference, wrong reference type and claiming an empty mailbox caused no observed state change. | No eligible mail was available for a successful-claim control. |
| Battle Pass | 3 | Unearned free/paid claims and an unknown mission caused no observed state change. | Account had zero points and no premium entitlement; individual eligibility checks cannot be distinguished. |
| Crafting | 1 | A known recipe requested without its materials caused no observed state change. | Replicated recipe configuration also marked this feature coming soon; the rejecting condition is unknown. |
| Heart conversion | 5 | Missing-material, zero, negative, fractional and wrong-type count requests returned a proximity refusal. | The distance gate ran first; these results do not establish that count/material validation would pass near the smith. |
| Stone conversion | 2 | Missing-material request returned a proximity refusal. Negative-count request returned a generic failure. No observed state change. | Generic failure is not proof of a specific validation check. |
| Loadout permissions and cleanup | 3 | Saving in an allowed slot worked. Changing the slot-count attribute locally did not enable saving in a locked slot. The temporary saved loadout was cleared afterward. | Demonstrates this permission boundary only; other client attributes were not tested. |

At the end of that round, Silver, premium currency and equipped gear were unchanged. The loadout list was empty again and the original two-slot value was restored. No other player's inventory was addressed.

On 2026-11-04, a read-only follow-up found the account in a different server session, still with two loadout slots and an empty loadout list. The previous in-memory test record was no longer present. This follow-up is consistent with the cleanup, but is not a controlled persistence or rollback test.

## Earlier reward checks

- A first eligible 120-minute reward received two consecutive requests and granted exactly one advertised bundle.
- The 180-minute reward did not grant while its time requirement was unmet.
- When it later became eligible, a normal claim granted the advertised bundle. Two subsequent replay requests produced no additional observed items or Silver.

These observations were made within their original sessions. They do not rule out all concurrency windows, resets, or cross-server save defects.

## Unverified areas

| Area | Further evidence needed |
|---|---|
| Forge validation after the distance check | Controlled checks near the correct NPC, with a valid-path control and limited test materials. |
| Item trade and gift ownership | A second authorized test account and controlled confirm/cancel cases. |
| Unique gear races | Disposable test gear, known-good storage/transfer controls and conservation checks. |
| Loot-box distance and ownership | Suitable test-owned boxes and a normal opening control. None was available during the final observation. |
| Cross-server persistence | Recorded baselines and a controlled reconnect/teleport sequence. |
| Paid purchases and receipts | A purchase-testing setup; no paid transaction was attempted. |
| Numeric corruption, failure recovery and load limits | A disposable test environment. Potentially corrupting or disruptive cases were not sent to the live profile. |

## Release scope

This update adds documentation only. The farm control center and loader remain at **3.3.2-boss-entry**. No server-side fix was deployed. Findings from the separate local example modules are not evidence of vulnerabilities in the production game.
