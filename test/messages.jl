import Lint: level, Location

msg1 = LintMessage(Location("none", 1), :W001, "", "foo", "message")
msg2 = LintMessage(Location("none", 2), :E002, "", "", "message\nmessage")
msg3 = LintMessage(Location("none", 1), :W001, "", "foo", "message")

@test string(msg1) == "none:1 W001 foo: message"
@test string(msg2) == "none:2 E002 : message\n              message"

@test sprint(show, msg1) == string(msg1)

@test msg1 == msg3

@test !isless(msg1, msg3)
@test !isless(msg3, msg1)

@test isless(msg1, LintMessage(Location("none2", 1), :W001, "", "foo", "message"))
@test isless(msg1, LintMessage(Location("none", 1), :I001, "", "foo", "message"))
@test !isless(msg1, LintMessage(Location("none", 1), :E001, "", "foo", "message"))
@test isless(msg1, LintMessage(Location("none", 2), :W001, "", "foo", "message"))
@test isless(msg1, LintMessage(Location("none", 1), :W001, "", "foo2", "message"))
@test isless(msg1, LintMessage(Location("none", 1), :W001, "", "foo", "message2"))

@test !iserror(msg1)
@test iswarning(msg1)
@test !isinfo(msg1)

@test iserror(msg2)
@test !iswarning(msg2)
@test !isinfo(msg2)

@test level(msg1) == :WARN
@test level(msg2) == :ERROR
