VAR base_value = 10
~ mutate_phase_1(base_value)
~ temp result = mutate_temporary(100)
{base_value}
{result}

-> DONE

== function mutate_temporary(value) ==
~ temp result = value
~ mutate_phase_1(result)
~ return result

== function mutate_phase_1(ref x) ==
~ x = x * 10
~ mutate_phase_2(x)

== function mutate_phase_2(ref x) ==
~ x = x / 25
