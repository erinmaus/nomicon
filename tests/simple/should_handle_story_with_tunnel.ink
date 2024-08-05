VAR current_hero = "Bob"
VAR current_monster = "Dragonkin"

-> the_fight

== the_fight ==
Robert the Strong, humanity's hero and one last hope, is facing off against Kerapac...

-> attack_monster("Bob", "Kerapac", 0) ->

It seems Bob missed!

-> attack_monster("Bob", "Kerapac", 5) ->

It seems Bob missed again! It's over for Bob as Kerapac kills him... I hope reincarnation is real...

-> DONE

== attack_monster(hero, monster, damage) ==
{
    - damage > 100:
        ->-> big_blow(hero, monster, damage)
    - damage < 50 && damage > 0:
        ->-> weak_blow(hero, monster, damage)
}
->->

== big_blow(hero, monster, damage) ==
The hero {hero} dealt a massive blow, slaying {monster} with {damage} damage!

Congrats {hero}!

-> DONE

== weak_blow(hero, monster, damage) ==
{hero}'s arrow glanced off {monster}! {damage} isn't enough! Oh no!

->-> attack_monster(hero, monster, 500)
