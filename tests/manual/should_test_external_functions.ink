EXTERNAL set_player_name(id, name)
EXTERNAL is_player_alive(id)
EXTERNAL get_player_name(id)
EXTERNAL kill_player(id)

~ set_player_name(1, "Bob-aroni")
~ set_player_name(2, "Bob-inator")

-> player_select

== player_select ==

{not is_player_alive(1) && not is_player_alive(2): -> game_over}

So speaketh the GamePlayer 2000 XP: Whomst do you choose to be fighter FIGHTER for ROUND {player_select}?
  + {is_player_alive(1)} [Player {get_player_name(1)}] -> fight("1")
  + {is_player_alive(2)} [Player {get_player_name(2)}] -> fight("2")

== fight(id) ==

After playing Rippin' Rockin' Rumble!!!, {get_player_name(id)} died!

// kill_player casts the underlying Value to a NUMBER
~ kill_player(id)

-> player_select

== game_over ==

All players are dead! GAME OVER, BRUH!
