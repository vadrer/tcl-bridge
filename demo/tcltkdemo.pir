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
pack [text .t]
.t insert end {foo, bar, fluffy}
pack [button .bquit -text {quit} -command {exit}]
focus .b
EOS
    # given existing GUI, get some widget
    .local pmc wbutton
    wbutton = tcl.'widget'('.bquit')
    # and now use widget method
    wbutton.'call'('configure','-text','-Q-u-I-t-')
    # mainloop
    tcl.'MainLoop'()
.end

#

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
