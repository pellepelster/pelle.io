---
title: "Whats my age again? (PostgreSQL Edition)"
date: 2021-10-21T20:00:00+01:00
draft: true
---

One of many fun aspects when taking over existing codebases is that you inevitably learn somehting new (if you want it or not does not matter ;-)).

Today a user reported a bug, that some numbers that are derived from the diff of two dates produced incoherent results. Looking at the code, it turned out that PostgreSQLs AGE function was used to get the timespan between two dates. The shortest reproduce I was able to come up with that exposed the buggy behavior looks like this:

```
SELECT AGE('2021-06-30','2021-05-19') AS age1, AGE('2021-07-01','2021-05-20') AS age2;
```

```
+----------------------------------------------+----------------------------------------------+
|age1                                          |age2                                          |
+----------------------------------------------+----------------------------------------------+
|0 years 1 mons 11 days 0 hours 0 mins 0.0 secs|0 years 1 mons 12 days 0 hours 0 mins 0.0 secs|
+----------------------------------------------+----------------------------------------------+
```

The correct answer in both cases should be `0 years 1 mons 11 days`. This post will try to shed some light on the AGE function and show alternatives that produce a (maybe) better result.

<!--more-->


Being unfamiliar with the AGE function a look in the documentation did not really help:

> age ( timestamp, timestamp ) → interval
>
>   Subtract arguments, producing a “symbolic” result that uses years and months, rather than just days
>   age(timestamp '2001-04-10', timestamp '1957-06-13') → 43 years 9 mons 27 days

So we havbe to dig deeper. PostgreSQL being an open source project makes this easy, some digging around on Github revealed the C function that is backing the AGE function:

https://github.com/postgres/postgres/blob/e94c1a55dada49772622d2be2d17a2a9973b2661/src/backend/utils/adt/timestamp.c#L3691 which has this nice comment in front:


> /* timestamptz_age()
> * Calculate time difference while retaining year/month fields.
> * Note that this does not result in an accurate absolute time span
> *	since year and month are out of context once the arithmetic
> *	is done.
       > */

Still not crystal clear what it does, but the

> Note that this does not result in an accurate absolute time span

already looks suspicious. Digging even deeper into the function we can see

Lets use the example input we have and try to follow the flow of the function to see where it goes wrong (or to be more precise where it does not work as we expected):

For the arguments `2021-06-30` and `2021-05-19` a diff is calculated for each individual field at https://github.com/postgres/postgres/blob/e94c1a55dada49772622d2be2d17a2a9973b2661/src/backend/utils/adt/timestamp.c#L3715

`tm1 = 2021-06-30` and `tm2 = 2021-05-19`

after

```
tm->tm_mday = tm1->tm_mday - tm2->tm_mday;
tm->tm_mon = tm1->tm_mon - tm2->tm_mon;
tm->tm_year = tm1->tm_year - tm2->tm_year;
```

results in the following diff:


```
tm->tm_day = 11
tm->tm_month = 1
tm->tm_year = 0
```

which is the exact reult we get for `age1` in our reproduce SQL query.
So far so godd, lets do the exercise again with the second pair of parameters, `tm1 = 2021-07-01` and `tm2 = 2021-05-20`. The diff for those parameters looks like this:




```
tm->tm_day = -19
tm->tm_month = 2
tm->tm_year = 0
```

The negative difference in `tm->tm_mday` triggers https://github.com/postgres/postgres/blob/e94c1a55dada49772622d2be2d17a2a9973b2661/src/backend/utils/adt/timestamp.c#L3759 the following code:


```
/* propagate any negative fields into the next higher field */

[...]

while (tm->tm_mday < 0)
{
       if (dt1 < dt2)
       {
              tm->tm_mday += day_tab[isleap(tm1->tm_year)][tm1false->tm_mon - 1];
              tm->tm_mon--;
       }
       else
       {
              tm->tm_mday += day_tab[isleap(tm2->tm_year)][tm2->tm_mon - 1];
              tm->tm_mon--;
       }
}
```

this looks promising. Because in our case `dt1 > dt2` we have to look at the else branch. What exactly a negative `tm->tm_mday` means may become a little bit clearer with the help of some ASCII art:

```
not to scale

month   5                         6                       7
        │                         │                       │
        │               20        │                       │ 1
day  ─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼────►
                        │         │                       │ │
                   tm2->tm_day    │                       │ tm1->tm_day
                        │         │                       │ │
                        │─────────│───── -19 ─────────────│─│
                        │         │                       │ │
                        │─── a ───│────────── b ──────────│c|
```

looking at it it becomes pretty apearant that we want `a` + `b` as the days difference without the `c` part. Because the `c` part is a full month we can just add it to `tm->tm_mday` and adjust `tm->tm_month` afterwards by decreasing it by one. Via `day_tab`, which looks like this:

```
const int	day_tab[2][13] =
{
	{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0},
	{31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0}
};
```

we can look up the number of days for each month (in leap- and non-leap years) and this is also is where the whole things falls apart. Looking back at the inital method comment it was mentioned that the result will be wrong because:

> year and month are out of context

mapped to the code this means that the method can not know what number of days from which month to use to add to `tm->tm_mday`. It currently uses `tm2->tm_mon`but one could also argue that `tm1->tm_mon` can also be correct in some cases. In our example it uses may which has 31 days and introduces the off by one error due to `-19 + 31 = 12`


```
tm->tm_mday += day_tab[isleap(tm2->tm_year)][tm2->tm_mon - 1];
tm->tm_mon--;
```

```
SELECT '2021-06-30'::timestamp - '2021-05-19'::timestamp AS diff1,
'2021-07-01'::timestamp - '2021-05-20'::timestamp AS diff2;
```

```
+-------------------------------------+-------------------------------------+
|diff1                                |diff2                                |
+-------------------------------------+-------------------------------------+
|0 years 0 mons 42 days 0 hours 0 mins|0 years 0 mons 42 days 0 hours 0 mins|
+-------------------------------------+-------------------------------------+
```
