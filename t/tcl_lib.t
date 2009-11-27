#!./parrot
# Copyright (C) 2009, Parrot Foundation.

=head1 NAME

t/tcl_lib.t - test parrot to external Tcl connection

=head1 SYNOPSIS

    % prove t/tcl_lib.t

=head1 DESCRIPTION

=cut

.const int TESTS = 8

.sub 'main' :main
    load_bytecode 'Test/More.pbc'

    .local pmc exports, curr_namespace, test_namespace
    curr_namespace = get_namespace
    test_namespace = get_namespace [ 'Test'; 'More' ]
    exports        = split ' ', 'plan diag ok nok is is_deeply like isa_ok skip isnt todo'

    test_namespace.'export_to'(curr_namespace, exports)

    plan(TESTS)

    load_bytecode 'TclLibrary.pbc'
    'ok'(1, 'loaded TclLibrary')

    .local pmc tcl
    tcl = new 'TclLibrary'
    'ok'(1, 'created instance')

    .local string res
    .local int ires

    # misc evals
    res = tcl.'eval'("return {3+3}")
    'is'(res, '3+3', 'return of a string')
    res = tcl.'eval'("string repeat {qwerty} 2")
    'is'(res, 'qwertyqwerty', 'test string')
    # TODO res = tcl.'eval'("return [list a b foo bar]")
    ires = tcl.'eval'("expr {3+3}")
    'is'(ires, 6, 'return of an integer')
    res = tcl.'eval'("return [expr 1.0]")
    'is'(res, '1.0', 'return of double')

    # variable methods: getvar, setvar2, unsetvar2, etc.
    tcl.'setvar'("foo", "ok")
    res = tcl.'eval_str'("set foo")
    'is'(res,"ok", "setvar ok")
    res = tcl.'eval_str'("return $foo")
    'is'(res,"ok", "setvar ok")

    goto skip2
    tcl.'eval_str'('set a(OK) ok; set a(five) 5')
    res = tcl.'getvar2'('a','OK')
    'is'(res,'ok','getvar2 ok')
    tcl.'setvar2'("foo", "bar", "ok")
    res = tcl.'getvar2'('foo','bar')
    'is'(res,'ok','setvar2 ok')
    res = tcl.'eval_str'("set bar(foo)")
    'is'(res,"ok", "setvar ok")
    res = tcl.'eval_str'("return $foo(bar)")
    'is'(res,"ok", "setvar ok")
  
    # list
    .local pmc tlist
    tlist = tcl.'eval'("return [list a b foo bar]")
    ires = tlist.'length'()
    ok(ires,4,"list length")

skip2:

    # MORE TBD


.end
# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:

