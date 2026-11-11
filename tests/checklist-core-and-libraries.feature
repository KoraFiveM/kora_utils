# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_utils — Core & Libraries

  @kora_utils @checklist @checklist:kora_utils:crouch-prone @cat:core-and-libraries @manual
  Scenario: Crouch and prone (LCtrl)
    """
    Checklist test: Tap Left Ctrl to toggle crouch, hold ~0.5s to go prone and crawl; tap again to stand. Rebindable.
    """
    When I manually: tap Left Ctrl once while on foot
    Then I confirm: my character crouches
    When I manually: hold Left Ctrl for about 0.5 seconds
    Then I confirm: my character goes prone and can crawl with W/A/S/D
    When I manually: tap Left Ctrl again
    Then I confirm: my character stands up
    When I manually: rebind the crouch key in the game keybind settings and press the new key
    Then I confirm: the new key toggles crouch

  @kora_utils @checklist @checklist:kora_utils:seatbelt @cat:core-and-libraries
  Scenario: Toggle seatbelt (B / /toggleseatbelt)
    """
    Checklist test: In a vehicle press B to buckle/unbuckle; buckled blocks exit control; unbuckled hard crash can eject the player.
    """
    Given I am in the driver seat of a "test_car"
    When I press the "B" key
    Then the seatbelt indicator should be on
    When I manually: try to exit the vehicle while buckled
    Then I confirm: I cannot exit the vehicle while buckled
    When I press the "B" key
    Then the seatbelt indicator should be off
    When I get out of the vehicle
    And I get in the vehicle
    And I run the command "/toggleseatbelt"
    Then the seatbelt indicator should be on
    When I manually: drive into a wall at high speed while unbuckled
    Then I confirm: I can be ejected from the vehicle in a hard crash

  @kora_utils @checklist @checklist:kora_utils:harness-item @cat:core-and-libraries
  Scenario: Use harness item
    """
    Checklist test: Use the 'harness' item in a supported vehicle: 5s equip, consumes a use (20 total); harness prevents crash ejection.
    """
    Given I have 1 "harness"
    And I am in the driver seat of a "test_car"
    When I use a "harness"
    Then a progress bar should run
    When I wait 5 seconds
    Then I confirm: the harness is equipped
    And I confirm: the harness item has consumed one use (20 uses total)
    When I manually: drive into a wall at high speed with the harness equipped
    Then I confirm: I am not ejected from the vehicle in the crash

  @kora_utils @checklist @checklist:kora_utils:weapon-wheel @cat:core-and-libraries @manual
  Scenario: Weapon wheel disabled
    """
    Checklist test: Hold Tab: no radial weapon wheel appears; picking up a weapon does not auto-equip.
    """
    When I manually: hold Tab
    Then I confirm: no radial weapon wheel appears
    When I manually: pick up a weapon from the ground
    Then I confirm: the picked up weapon is not auto-equipped

  @kora_utils @checklist @checklist:kora_utils:no-wanted @cat:core-and-libraries @manual
  Scenario: No NPC wanted level or dispatch
    """
    Checklist test: Commit crimes (shoot a ped): no wanted stars, no HUD star, no NPC police/helis dispatched.
    """
    When I manually: shoot a ped
    Then I confirm: I get no wanted stars
    And I confirm: no wanted star shows on my HUD
    And I confirm: no NPC police or helicopters are dispatched

  @kora_utils @checklist @checklist:kora_utils:no-idle-cam @cat:core-and-libraries @manual
  Scenario: No idle cinematic camera
    """
    Checklist test: Stand still 30+s: the camera does not swing into the idle cinematic.
    """
    When I manually: stand still without touching any input for 30+ seconds
    Then I confirm: the camera does not swing into the idle cinematic view

  @kora_utils @checklist @checklist:kora_utils:no-health-regen @cat:core-and-libraries
  Scenario: No passive health regeneration
    """
    Checklist test: Take damage and wait: health does not regenerate until healed by item/medic.
    """
    Given I am at full health
    When I manually: take some damage, for example by falling from a height
    And I wait 60 seconds
    Then I confirm: my health has not regenerated
    When I manually: heal using a medical item or a medic
    Then I confirm: my health increases only after healing

  @kora_utils @checklist @checklist:kora_utils:no-vehicle-rewards @cat:core-and-libraries
  Scenario: No weapon from entering police cars
    """
    Checklist test: Enter a police vehicle: you do not receive a free weapon.
    """
    When I manually: find a police vehicle and stand next to it
    And I get in the vehicle
    Then I confirm: I did not receive a free weapon from entering the police vehicle

  @kora_utils @checklist @checklist:kora_utils:weapon-blacklist @cat:core-and-libraries
  Scenario: Blacklisted weapons stripped
    """
    Checklist test: Equip a blacklisted weapon (RPG, minigun, railgun...): it is removed and a notification shown.
    """
    Given I have 1 "weapon_rpg"
    And I have 1 "weapon_minigun"
    And I have 1 "weapon_railgun"
    When I manually: equip the RPG, then repeat with the minigun and the railgun
    Then I should see a notification containing "That weapon isn't allowed on this server."
    And I confirm: the blacklisted weapon is removed from my hands

  @kora_utils @checklist @checklist:kora_utils:vehicle-blacklist @cat:core-and-libraries @needs:admin
  Scenario: Blacklisted vehicles cannot spawn
    """
    Checklist test: Spawn rhino/lazer/hydra/oppressor/deluxo etc. (e.g. admin spawn): server cancels the entity creation.
    """
    When I manually: as an admin, spawn a rhino, lazer, hydra, oppressor or deluxo (for example with /car <model>)
    Then I should see a notification containing "That vehicle is not allowed on this server."
    And I confirm: the vehicle was not spawned (server cancelled the entity creation)

  @kora_utils @checklist @checklist:kora_utils:world-depop @cat:core-and-libraries @manual
  Scenario: Calmer world: no random cops/drops
    """
    Checklist test: No ambient cop sirens/spawns, calm NPCs, and dead NPCs do not drop weapons.
    """
    When I manually: look and listen around in the open world for a while
    Then I confirm: I see and hear no ambient cop sirens or cop spawns (only applies when Config.worldDepop.disableRandomCops is enabled)
    And I confirm: nearby NPCs behave calmly (only applies when Config.worldDepop.calmNpcs is enabled)
    When I manually: kill an NPC
    Then I confirm: the dead NPC does not drop a weapon (only applies when Config.worldDepop.disablePedDrops is enabled)

  @kora_utils @checklist @checklist:kora_utils:perf-resmon @cat:core-and-libraries @manual
  Scenario: kora_utils resource time (F8 resmon 1)
    """
    Checklist test: Open F8, run 'resmon 1', stand still on foot, then drive: kora_utils should stay very low. Report it here with your numbers if it is above 0.05ms.
    """
    When I manually: open F8 and run resmon 1
    And I manually: stand still on foot, then drive a vehicle
    Then I confirm: kora_utils stays very low (at or below 0.05ms), otherwise report it with my numbers

  @kora_utils @checklist @checklist:kora_utils:perf-no-stutter @cat:core-and-libraries @manual
  Scenario: No periodic stutter or hitching
    """
    Checklist test: Play ~5 min in a busy area (walk, drive, fight NPCs). There should be no regular freeze or hitch every few seconds. Report it if you see one.
    """
    When I manually: play about 5 minutes in a busy area, walking, driving and fighting NPCs
    Then I confirm: there is no regular freeze or hitch every few seconds

  @kora_utils @checklist @checklist:kora_utils:respawn-settings @cat:core-and-libraries
  Scenario: Settings survive death and respawn
    """
    Checklist test: Die and respawn: weapon wheel still off, no wanted level (shoot a ped), no passive health regen, and no free weapon from a police car.
    """
    Given I am dead
    When I manually: respawn
    And I manually: try to open the weapon wheel
    Then I confirm: the weapon wheel is still off
    When I manually: shoot a ped
    Then I confirm: I get no wanted level
    When I manually: check my health over a short time after taking damage
    Then I confirm: my health does not passively regenerate
    When I manually: get into a police car
    Then I confirm: I receive no free weapon from the police car

  @kora_utils @checklist @checklist:kora_utils:no-star-hud @cat:core-and-libraries @manual
  Scenario: Wanted stars never appear
    """
    Checklist test: Commit crimes (shoot a ped, hit a cop): the wanted stars never show on the HUD, even for a moment, and no NPC police react.
    """
    When I manually: shoot a ped and hit a cop
    Then I confirm: the wanted stars never show on my HUD, even for a moment
    And I confirm: no NPC police react

  @kora_utils @checklist @checklist:kora_utils:idle-cam-vehicle @cat:core-and-libraries
  Scenario: No idle camera in a vehicle either
    """
    Checklist test: Sit in a parked vehicle for 30+s without input: the camera does not swing into the cinematic idle view. Repeat on foot.
    """
    Given I am in the driver seat of a "test_car"
    When I wait 35 seconds
    Then I confirm: the camera does not swing into the cinematic idle view
    When I get out of the vehicle
    And I wait 35 seconds
    Then I confirm: the camera does not swing into the cinematic idle view on foot

  @kora_utils @checklist @checklist:kora_utils:duck-on-foot @cat:core-and-libraries @manual
  Scenario: Stock duck/stealth never triggers
    """
    Checklist test: On foot, tap LCtrl rapidly and also hold it: you only get the real crouch/prone, never the combat/action-mode stance or stealth walk.
    """
    When I manually: on foot, tap LCtrl rapidly several times
    Then I confirm: I only get the real crouch, never the combat/action-mode stance or stealth walk
    When I manually: hold LCtrl
    Then I confirm: I go prone and never get the combat/action-mode stance or stealth walk

  @kora_utils @checklist @checklist:kora_utils:duck-after-vehicle @cat:core-and-libraries
  Scenario: Crouch works after using a vehicle
    """
    Checklist test: Get in and out of a car, bike and boat, then tap LCtrl: crouch and prone still work every time, and the stock duck is still blocked.
    """
    Given a "test_car" is spawned in front of me with keys
    When I get in the vehicle
    And I get out of the vehicle
    And I manually: get in and out of a bike, then get in and out of a boat
    And I manually: tap LCtrl
    Then I confirm: crouch works
    When I manually: hold LCtrl
    Then I confirm: prone works
    And I confirm: the stock duck/stealth stance is still blocked

  @kora_utils @checklist @checklist:kora_utils:seatbelt-exit-block @cat:core-and-libraries
  Scenario: Buckled belt blocks exiting (F)
    """
    Checklist test: In a car buckle up (B) and press F: you stay seated. Unbuckle and press F: you exit straight away with no delay.
    """
    Given I am in the driver seat of a "test_car"
    When I press the "B" key
    Then the seatbelt indicator should be on
    When I press the "F" key
    Then I should be in the driver seat
    When I press the "B" key
    Then the seatbelt indicator should be off
    When I press the "F" key
    Then I confirm: I exit the vehicle straight away with no delay

  @kora_utils @checklist @checklist:kora_utils:seatbelt-switch-vehicle @cat:core-and-libraries
  Scenario: Seatbelt resets between vehicles
    """
    Checklist test: Buckle up, exit, then get in a different vehicle: the belt starts off, B buckles it, and the exit block works for the new vehicle.
    """
    Given I am in the driver seat of a "test_car"
    When I press the "B" key
    Then the seatbelt indicator should be on
    When I get out of the vehicle
    And I manually: get in a different vehicle
    Then the seatbelt indicator should be off
    When I press the "B" key
    Then the seatbelt indicator should be on
    When I press the "F" key
    Then I should be in the driver seat

  @kora_utils @checklist @checklist:kora_utils:crash-after-respawn @cat:core-and-libraries
  Scenario: Crash ejection still works after respawn
    """
    Checklist test: Respawn, get in a car, and crash hard (110+ km/h) unbuckled: you can still be thrown out. Buckled you should stay in unless the hit is extreme.
    """
    Given I am dead
    When I manually: respawn and get in a car
    And I manually: crash hard at 110+ km/h with the seatbelt unbuckled
    Then I confirm: I can be thrown out of the vehicle
    When I manually: get back in, buckle the seatbelt with B and crash at a high speed
    Then I confirm: I stay in the vehicle unless the hit is extreme

  @kora_utils @checklist @checklist:kora_utils:ped-drops-new @cat:core-and-libraries @manual
  Scenario: Weapon drops stay off for new NPCs
    """
    Checklist test: Drive across the map so fresh NPCs spawn, then kill several in different places: none of them drop a weapon, including ones that spawned after you arrived.
    """
    When I manually: drive across the map so fresh NPCs spawn
    And I manually: kill several NPCs in different places, including ones that spawned after I arrived
    Then I confirm: none of the killed NPCs drop a weapon

  @kora_utils @checklist @checklist:kora_utils:world-depop-recover @cat:core-and-libraries @manual
  Scenario: Calm NPCs and no random cops hold up
    """
    Checklist test: Play 10+ min: ambient gangs, medics and cops stay non-hostile and no random cop cars or sirens appear, including after a respawn.
    """
    When I manually: play for 10+ minutes in the open world
    Then I confirm: ambient gangs, medics and cops stay non-hostile
    And I confirm: no random cop cars or sirens appear
    When I manually: die and respawn, then play a few more minutes
    Then I confirm: NPCs are still non-hostile and no random cop cars or sirens appear after the respawn
