
module LintExample2

#submodule
module LintExSubMod1
subfoo(x) = println(x)
end

module LintExSubMod2
using ..LintExSubMod1
subfar(x) = subfoo(x)
end

using LintExample

export foo, bar

@fancyfuncgen(foo)
@fancyfuncgen(bar)

end
