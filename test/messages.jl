import Lint: iserror, iswarning, isinfo, level

msg1 = LintMessage("none", :W001, "", 1, "foo", "message")
msg2 = LintMessage("none", :E002, "", 2, "", "message\nmessage")
msg3 = LintMessage("none", :W001, "", 1, "foo", "message")

@test string(msg1) == "none:1 W001 foo: message"
@test string(msg2) == "none:2 E002 : message\n              message"

@test sprint(show, msg1) == string(msg1)

@test msg1 == msg3

@test !isless(msg1, msg3)
@test !isless(msg3, msg1)

@test isless(msg1, LintMessage("none2", :W001, "", 1, "foo", "message"))
@test isless(msg1, LintMessage("none", :I001, "", 1, "foo", "message"))
@test !isless(msg1, LintMessage("none", :E001, "", 1, "foo", "message"))
@test isless(msg1, LintMessage("none", :W001, "", 2, "foo", "message"))
@test isless(msg1, LintMessage("none", :W001, "", 1, "foo2", "message"))
@test isless(msg1, LintMessage("none", :W001, "", 1, "foo", "message2"))

@test !iserror(msg1)
@test iswarning(msg1)
@test !isinfo(msg1)

@test iserror(msg2)
@test !iswarning(msg2)
@test !isinfo(msg2)

@test level(msg1) == :WARN
@test level(msg2) == :ERROR
