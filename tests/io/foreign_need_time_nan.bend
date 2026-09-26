# io (io_foreign_need_time_nan): a foreign effect's _need may declare a time
# wait; the wait's deadline is read from the call's first argument. A
# foreign def that declares {time: true} but takes no duration argument
# (or a non-numeric one) used to park its task on a NaN deadline and hang
# the program forever with no output. The runtime now fails loudly.
import Base

law my.tick:
  IO(Unit)

def my.tick():
  import "./foreign_need_time_nan.js"

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    Unit <- IO.print("before")
    Unit <- my.tick()
    Unit <- IO.print("after")
    IO.pure(Unit, Unit{})

#|before
#|Error: bend: a foreign effect waited on time with a non-numeric duration
#|exit 1
