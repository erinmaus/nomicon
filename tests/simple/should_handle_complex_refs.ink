VAR base_value = 10
mutate_phase_1(base_value)
{base_value}

-> DONE

== function mutate_phase_1(ref x) ==
~ x = x * 10
~ temp y = x
~ mutate_phase_2(y)

== function mutate_phase_2(ref x) ==
~ x = base_value / 25
