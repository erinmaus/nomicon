VAR base_value = 10
~ mutate_phase_1(base_value)
{base_value}

-> DONE

== function mutate_phase_1(ref x) ==
~ x = x * 10
~ mutate_phase_2(x)

== function mutate_phase_2(ref x) ==
~ x = x / 25
