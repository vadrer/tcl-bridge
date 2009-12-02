# Copyright (C) 2009, Parrot Foundation.
# $Id: tcltkdemo.pir 39338 2009-06-02 16:59:27Z NotFound $
# demonstrate Tcl/Tk GUI using NCI

.sub try :main
    load_bytecode 'TclLibrary.pbc'
    .local pmc tcl
    tcl = new 'TclLibrary'
    .local string res
    res = tcl.'eval'(<<"EOS")
package require Tk
pack [button .b -text {useful button} -command {puts this}]
pack [frame .f]
pack [text .t]
.t insert end {foo, bar, fluffy\n}
pack [button .bquit -text {quit} -command {exit}]
set w_e text
EOS
    # given existing GUI, get some widget
    .local pmc wbutton, wtext
    wbutton = tcl.'widget'('.b')
    wtext = tcl.'widget'('.t')
    # and now use widget method
    wtext.'call'('insert','end','some text...')
    # create some more widgets, using another method
    tcl.'call'('entry','.f.e','-textvariable','w_e')
    tcl.'call'('pack','.f.e')
    tcl.'call'('focus','.f.e')
    # and change button behaviour
    wbutton.'call'('configure','-command','.t insert end $w_e')
    # mainloop
    tcl.'MainLoop'()
.end

#

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
