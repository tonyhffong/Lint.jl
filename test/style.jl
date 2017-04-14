
# these are in style not recommended by Julia, but they
# should not generate lint messages.
s = """
function f(Y::Array)
  X = zeros(100, 1)
  for i = 1:100
    X[i] = Y[i]
  end
  X
end

function f(Y::Array)
  function f2(Y=Y)
    Y*2
  end
end
"""
msgs = lintstr(s)
@test_broken isempty(msgs)
