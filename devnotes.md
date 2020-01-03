Advise Stefan
--------------
* 4+1
* decentral (mirror maker)
* if persistant "log", it is easy to query queue/ log contant (compare to ksql)

Advise Uwe
----------
* optional auto create
* optional error handler to be passed in (lambda)
* deferred trigger (see issue #1)

Roadmap
-------
- Worker Queue
- Java 8 implementation with test
    - DB Part is common for all tests -> docker compose?
- Python3 implementation with test
- keep common code 
- optional: Bash implementation

Next
----
- write int tests in python for psql functions
- write int test for python function
- split function and "prod" code
- provide an example how to install function via pip git option

Links
-----
https://tnishimura.github.io/articles/queues-in-postgresql/
