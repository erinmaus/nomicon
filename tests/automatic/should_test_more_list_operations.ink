LIST list = l, m = 5, n
{LIST_VALUE(l)}

{list(1)}

~ temp a = LIST_ALL(list)
{a}
{LIST_MIN(a)}
{LIST_MAX(a)}

~ temp t = list()
~ t += n
{t}
~ t = LIST_ALL(t)
~ t -= n
{t}
~ t = LIST_INVERT(t)
{t}