-> obit ->
-> obit ->
-> obit ->
-> DONE

== obit ==
{is_alive(-> obit):Bob! You survived!|Bob... Rest in peace.}

->->

== function is_alive(name) ==
~ temp count = READ_COUNT(name)
{
    - count == 1:
        ~ return 1
    - else:
        ~ return 0
}
