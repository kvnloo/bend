# io (io_foreign_need_time_noarg): a foreign effect's _need may declare a
# time wait; the wait's deadline is read from the call's first argument. A
# foreign def that declares {time: true} but takes no duration argument
# used to hang the program forever with no output. In the JS runtime the
# deadline became NaN; in the C runtime io_step read the request's first
# field slot, which for a zero-argument request holds the continuation
# term, and waited on that garbage as the deadline. Both runtimes now
# fail loudly instead.
import Base

law my.tick:
  IO(Unit)

def my.tick():
  import "./foreign_need_time_noarg.js"
  import "./foreign_need_time_noarg.c"

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    Unit <- IO.print("before")
    Unit <- my.tick()
    Unit <- IO.print("after")
    IO.pure(Unit, Unit{})

#|before
#|bend: a foreign effect waited on time with a non-numeric duration
#|exit 1
