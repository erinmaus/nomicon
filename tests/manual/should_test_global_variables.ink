VAR example_1 = "hello"
VAR example_2 = "world"

== the_story ==
{example_1} {example_2}

~ example_1 = "good"
~ mutate(example_2)

{example_1} {example_2}

-> DONE

== function mutate(ref x) ==
~ x = "bye"
