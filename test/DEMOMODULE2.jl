
module LintExample2

using LintExample

export foo, bar

@fancyfuncgen( foo )
@fancyfuncgen( bar )

end
