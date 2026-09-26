# io (io_foreign_need_read_noarg): a foreign effect's _need may declare a
# read wait; the wait's file descriptor is read from the call's first
# argument. A foreign def that declares {read: true} but takes no fd
# argument (or a non-numeric one) used to park its task on a bogus wait
# and hang the program forever with no output. The runtime now fails
# loudly.
import Base

law my.read:
  IO(Unit)

def my.read():
  import "./foreign_need_read_noarg.js"

law main:
  IO(Unit)

def main():
  do IO<Unit>:
    Unit <- IO.print("before")
    Unit <- my.read()
    Unit <- IO.print("after")
    IO.pure(Unit, Unit{})

#|before
#|Error: bend: a foreign effect waited on read with a non-numeric file descriptor
#|exit 1
