# Copyright (C) 2008, Parrot Foundation.
# $Id: TclLibrary.pir 39337 2009-06-02 16:50:55Z NotFound $
# vkon

=head1 TITLE

TclLibrary.pir - NCI interface to Tcl language (http://www.tcl.tk)

=head1 DESCRIPTION

This module implements Tcl/Tk interface for Parrot.

=cut

.include "hllmacros.pir"
.include "datatypes.pasm"

.namespace ['TclLibrary']


# derived from tcl.h:
.const int TCL_OK       = 0
.const int TCL_ERROR    = 1
.const int TCL_RETURN   = 2
.const int TCL_BREAK    = 3
.const int TCL_CONTINUE = 4

.const int TCL_GLOBAL_ONLY     = 1
.const int TCL_NAMESPACE_ONLY  = 2
.const int TCL_APPEND_VALUE    = 4
.const int TCL_LIST_ELEMENT    = 8

# DEBUG
.const int debug_objresult = 0

=head2 TclLibrary interpreter Methods

=over 4

=item eval

=cut

#
.sub eval :method
    .param string str

    .local string error, sres
    .local pmc res
    .local pmc f_evalex, f_getobjresult, f_getstringresult, f_resetresult
    f_resetresult = get_global '_tcl_resetresult'
    f_evalex = get_global '_tcl_evalex'
    f_getobjresult = get_global '_tcl_getobjresult'
    f_getstringresult = get_global '_tcl_getstringresult'

    .local pmc interp
    interp = getattribute self,'interp'

    f_resetresult(interp)

    .local int rc
    rc = f_evalex(interp,str,-1,0) # interp, string, length or -1, flags
    # check if the result is TCL_OK(=0)
    if rc==TCL_OK goto eval_ok
    sres = f_getstringresult(interp)
    error = "error during Tcl_EvalEx: " . sres
    die error

eval_ok:
    # get the result (list result, etc - TBD)
    .IfElse(debug_objresult==0,{
	.local pmc obj
	obj = f_getobjresult(interp)
        .local pmc tcl_obj_decl
        tcl_obj_decl = get_global '_tcl_obj_decl' # retrieve tcl_obj structure
        assign obj, tcl_obj_decl                  # ... and use it
	res = _pmc_from_tclobj(interp,obj)
    },{
	sres = f_getstringresult(interp)
        .return(sres)
    })
    .return(res)
.end

# pure string eval, which evals and returns a string
.sub eval_str :method
    .param string str

    .local string res, error
    .local pmc f_eval, f_getstringresult, f_resetresult
    f_resetresult = get_global '_tcl_resetresult'
    f_eval = get_global '_tcl_eval'
    f_getstringresult = get_global '_tcl_getstringresult'

    .local pmc interp
    interp = getattribute self,'interp'

    f_resetresult(interp)

    .local int rc
    rc = f_eval(interp,str)
    # check if the result is TCL_OK(=0)
    if rc==TCL_OK goto eval_ok
    res = f_getstringresult(interp)
    error = "error during Tcl_Eval: " . res
    die error

eval_ok:
    res = f_getstringresult(interp)
    .return(res)
.end

# Constructor for the interpreter object.
# optional parameter - path to the tcl shared library.
.sub init :method :vtable
    .param string libname :optional
    .param int has_libname :opt_flag

    # get interpreter, store it globally
    .local pmc interp, f_createinterp, f_tclinit
    .local pmc libtcl
    libtcl = get_global '_libtcl'
    # if _libtcl not defined yet, then we're starting first time, so need
    # to call _tcl_load_lib

    unless_null libtcl, libtcl_loaded

    .IfElse(has_libname,{
        '_tcl_load_lib'(libname)
    },{
        '_tcl_load_lib'()
    })
    libtcl = get_global '_libtcl'

libtcl_loaded:
    f_createinterp = dlfunc libtcl, "Tcl_CreateInterp", "p"
    interp = f_createinterp()

    unless_null interp, ok_interp
    die "NO interp\n"

  ok_interp:
    setattribute self,'interp', interp
    f_tclinit = dlfunc libtcl, "Tcl_Init", "vp"
    f_tclinit(interp)
.end


=for comment

Performs the initialization of Tcl bridge, namely instantiates TclLibrary class

=cut

.sub _init :load :init
    .local pmc tclclass
    tclclass = newclass ['TclLibrary']
    addattribute tclclass, 'interp'
.end

=for comment

 - creates a helper for Tcl_Obj struct

=cut

.sub _init_tclobj

    # "declare" a helper for Tcl_Obj structure
    # here is the definition of the Tcl_Obj struct
    # typedef struct Tcl_Obj {
    #     int refCount; // When 0 the object will be freed.
    #     char *bytes;  // points to the first byte of the obj string representation...
    #     int length;	// number of bytes at *bytes, not incl.the term.null.
    #     Tcl_ObjType *typePtr; // obj type. if NULL - no int.rep.
    #     union {		     /* The internal representation: */
    #         long longValue;	     /*   - an long integer value */
    #         double doubleValue;    /*   - a double-precision floating value */
    #         VOID *otherValuePtr;   /*   - another, type-specific value */
    #         Tcl_WideInt wideValue; /*   - a long long value */
    #         struct {		/*   - internal rep as two pointers */
    #             VOID *ptr1;
    #             VOID *ptr2;
    #         } twoPtrValue;
    #         struct {		/*   - internal rep as a wide int, tightly
    #                                  *     packed fields */
    #             VOID *ptr;		/* Pointer to digits */
    #             unsigned long value;/* Alloc, used, and signum packed into a
    #                                  * single word */
    #         } ptrAndLongRep;
    #     } internalRep;
    # } Tcl_Obj;

    .local pmc tcl_obj_struct, tcl_obj_struct_d, tcl_obj_decl
    tcl_obj_decl = new 'ResizablePMCArray'
    push tcl_obj_decl, .DATATYPE_INT
    push tcl_obj_decl, 0
    push tcl_obj_decl, 0
    push tcl_obj_decl, .DATATYPE_CSTR
    push tcl_obj_decl, 0
    push tcl_obj_decl, 0
    push tcl_obj_decl, .DATATYPE_INT
    push tcl_obj_decl, 0
    push tcl_obj_decl, 0
    push tcl_obj_decl, .DATATYPE_INT
    push tcl_obj_decl, 0
    push tcl_obj_decl, 0
    # following items are for union, let it be 2 longs, which eventually
    # could be transformed to the required type
    push tcl_obj_decl, .DATATYPE_LONG
    push tcl_obj_decl, 2
    push tcl_obj_decl, 0

    # union TBD
    tcl_obj_struct = new 'UnManagedStruct', tcl_obj_decl
    set_global '_tcl_obj_decl', tcl_obj_decl

    set tcl_obj_decl[12], .DATATYPE_DOUBLE
    set tcl_obj_decl[13], 0

    tcl_obj_struct_d = new 'UnManagedStruct', tcl_obj_decl
    set_global '_tcl_obj_decl_d', tcl_obj_decl
.end

# find proper shared library and use it.
.sub _tcl_load_lib
    .param string libname :optional
    .param int has_libname :opt_flag

    # load shared library
    .local pmc libnames
    libnames = new 'ResizableStringArray'
    unless has_libname goto standard_names
    push libnames, libname
    say libname
    goto standard_names_e
standard_names:
    push libnames, 'tcl85'
    push libnames, 'tcl84'
    push libnames, 'libtcl8.5'
    push libnames, 'libtcl8.4'
    push libnames, 'libtcl8.5.so'
    push libnames, 'libtcl8.4.so'
standard_names_e:

    .local pmc libtcl
    libtcl = _load_lib_with_fallbacks('tcl', libnames)
    set_global '_libtcl', libtcl


    # initialize Tcl library
    .local pmc func_findexec
    func_findexec = dlfunc libtcl, "Tcl_FindExecutable", "vp"
    func_findexec(0)

    # few more functions, store them globally
    .local pmc func
    # need: Tcl_ResetResult, Tcl_EvalEx, Tcl_GetStringResult, etc
    func = dlfunc libtcl, "Tcl_ResetResult", "vp"
    set_global '_tcl_resetresult', func
    func = dlfunc libtcl, "Tcl_EvalEx", "iptii"
    set_global '_tcl_evalex', func
    func = dlfunc libtcl, "Tcl_Eval", "ipt"
    set_global '_tcl_eval', func
    func = dlfunc libtcl, "Tcl_GetStringFromObj", "tp3"
    set_global '_tcl_getstringfromobj', func
    func = dlfunc libtcl, "Tcl_GetIntFromObj", "ipp3"
    set_global '_tcl_getintfromobj', func
    func = dlfunc libtcl, "Tcl_GetDoubleFromObj", "ippp"
    set_global '_tcl_getdoublefromobj', func
    func = dlfunc libtcl, "Tcl_GetStringResult", "tp"
    set_global '_tcl_getstringresult', func
    func = dlfunc libtcl, "Tcl_GetObjResult", "pp"
    set_global '_tcl_getobjresult', func
    func = dlfunc libtcl, "Tcl_GetObjType", "it"
    set_global '_tcl_getobjtype', func
    func = dlfunc libtcl, "Tcl_GetVar", "tpti"
    set_global '_tcl_getvar', func
    func = dlfunc libtcl, "Tcl_GetVar2", "tptti"
    set_global '_tcl_getvar2', func
    func = dlfunc libtcl, "Tcl_SetVar", "tptti"
    set_global '_tcl_setvar', func
    func = dlfunc libtcl, "Tcl_SetVar2", "tpttti"
    set_global '_tcl_setvar2', func
    func = dlfunc libtcl, "Tcl_UnsetVar", "tpti"
    set_global '_tcl_unsetvar', func
    func = dlfunc libtcl, "Tcl_UnsetVar2", "tptti"
    set_global '_tcl_unsetvar2', func

    # for TclLibrary List
    # need: Tcl_ListObjLength, Tcl_ListObjIndex, Tcl_ListObjGetElements
    func = dlfunc libtcl, "Tcl_ListObjLength", "ipp3"
    set_global '_tcl_listobjlength', func
    func = dlfunc libtcl, "Tcl_ListObjIndex", "ippip"
    set_global '_tcl_listobjindex', func
    func = dlfunc libtcl, "Tcl_ListObjGetElements", "ipp3p"
    set_global '_tcl_listobjgetelements', func

    '_init_tclobj'()

.end

#
#static SV *
#SvFromTclObj(pTHX_ Tcl_Obj *objPtr)
=item pmc _pmc_from_tclobj(pmc interp, pmc tclobj)

This is a (static) function that will convert Tcl object to pmc

=cut

.sub _pmc_from_tclobj
    .param pmc interp
    .param pmc tclobj

    # check what type this tcl obj is

    .local int rc

    # check what tclobj actually is (null, integer, list, etc)

    # --->  these lines will be factored out into some init stage! ....
    .local int tclBooleanTypePtr
    .local int tclByteArrayTypePtr
    .local int tclDoubleTypePtr
    .local int tclIntTypePtr
    .local int tclListTypePtr
    .local int tclStringTypePtr
    .local int tclWideIntTypePtr

    .local pmc f_getobjtype
    f_getobjtype = get_global '_tcl_getobjtype'

    tclBooleanTypePtr   = f_getobjtype("boolean")
    tclByteArrayTypePtr = f_getobjtype("bytearray")
    tclDoubleTypePtr    = f_getobjtype("double")
    tclIntTypePtr       = f_getobjtype("int")
    tclListTypePtr      = f_getobjtype("list")
    tclStringTypePtr    = f_getobjtype("string")
    tclWideIntTypePtr   = f_getobjtype("wideInt")
    # ..... <---- (see above)

    #.local pmc tcl_obj_struct
    #tcl_obj_struct = get_global '_tcl_obj_struct'

    if tclobj!=0 goto not_null
    # null
    say "NULL???"
    goto EOJ

not_null:
    .local int obj_type

    obj_type = tclobj[3]

    #print "TCL obj_type is "
    #say obj_type

    if obj_type==0 goto EOJ # if obj_type is null, there's no internal rep

    if obj_type!=tclBooleanTypePtr goto m00
    say "implement tclBooleanTypePtr!"
    goto EOJ

m00:
    if obj_type!=tclByteArrayTypePtr goto m01
    say "implement tclByteArrayTypePtr"
    goto EOJ

m01:
    if obj_type!=tclDoubleTypePtr goto m02
    #sv = newSViv(objPtr->internalRep.doubleValue);
    # the code below doesn't currently work, so go to fallback
    # (fix it!)
    say "implement tclDoubleTypePtr"
    goto EOJ

    .local pmc f_getdoublefromobj
    .local pmc dres
    f_getdoublefromobj = get_global '_tcl_getdoublefromobj'
    dres = new 'Float'
    rc = f_getdoublefromobj(interp, tclobj, dres)
    say dres
    #.local pmc tcl_obj_decl_d
    #tcl_obj_decl_d = get_global '_tcl_obj_decl_d' # retrieve tcl_obj_d structure
    #assign tclobj, tcl_obj_decl_d                  # ... and use it
    #say "hujd1"
    #dres = tclobj[4]
    print "dres="
    say dres
    .return(dres)

m02:
    if obj_type!=tclIntTypePtr goto m03
    #sv = newSViv(objPtr->internalRep.longValue);
    .local pmc f_getintfromobj
    .local pmc iint
    f_getintfromobj = get_global '_tcl_getintfromobj'
    # "direct" way:
    #.local int ires
    #ires = tclobj[4]
    # "better" way:
    iint = new 'Integer'
    rc = f_getintfromobj(interp, tclobj, iint)
    .return(iint)

m03:
    if obj_type!=tclListTypePtr goto m04

    .local pmc argh
    argh = new 'Hash'
    set argh['tclobj'], tclobj
    set argh['interp'], interp
    .local pmc tlist
    tlist = new ['TclLibrary';'List'], argh
    .return(tlist)

m04:
    if obj_type!=tclStringTypePtr goto m05
    say "implement tclStringTypePtr"
    goto EOJ

m05:
    print "implement TCL obj_type "
    say obj_type

EOJ:
    # this is a fallback -
    # if we do not have support for the type, we use 
    # "_tcl_getstringfromobj", which is universal but we like to avoid

    .local string str
    .local pmc f_getstr
    f_getstr = get_global '_tcl_getstringfromobj'
    str = f_getstr(tclobj, 0)

    .return(str)
.end

=item getvar (VARNAME, FLAGS)

Returns the value of Tcl variable VARNAME. The optional argument FLAGS
behaves as in I<setvar>.

=cut

.sub getvar :method
    .param string var
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_getvar
    f_getvar = get_global '_tcl_getvar'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_getvar(interp,var,flags)

    .return(res)
.end

=item getvar2 (VARNAME1, VARNAME2, FLAGS)

Returns the value of the element VARNAME1(VARNAME2) of a Tcl array.
The optional argument FLAGS behaves as in I<setvar>.

=cut

.sub getvar2 :method
    .param string name1
    .param string name2
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_getvar2
    f_getvar2 = get_global '_tcl_getvar2'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_getvar2(interp,name1,name2,flags)

    .return(res)
.end

=item setvar (VARNAME, VALUE, FLAGS)

The FLAGS field is optional. Sets Tcl variable VARNAME in the
interpreter to VALUE. The FLAGS argument is the usual Tcl one and
can be a bitwise OR of the constants TCL_GLOBAL_ONLY,
TCL_LEAVE_ERR_MSG, TCL_APPEND_VALUE, TCL_LIST_ELEMENT.

=cut

.sub setvar :method
    .param string var
    .param string val
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_setvar
    f_setvar = get_global '_tcl_setvar'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_setvar(interp,var,val,flags)

    .return(res)
.end

=item setvar2 (VARNAME1, VARNAME2, VALUE, FLAGS)

Sets the element VARNAME1(VARNAME2) of a Tcl array to VALUE. The optional
argument FLAGS behaves as in I<SetVar> above.
Semantically this is very much like Perl's hash element.

=cut

.sub setvar2 :method
    .param string name1
    .param string name2
    .param string val
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_setvar2
    f_setvar2 = get_global '_tcl_setvar2'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_setvar2(interp,name1,name2,val,flags)

    .return(res)
.end

=item unsetvar (VARNAME, FLAGS)

Unsets Tcl variable VARNAME. The optional argument FLAGS
behaves as in I<setvar>.

=cut

.sub unsetvar :method
    .param string var
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_unsetvar
    f_unsetvar = get_global '_tcl_unsetvar'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_unsetvar(interp,var,flags)

    .return(res)
.end

=item UnsetVar2 (VARNAME1, VARNAME2, FLAGS)

Unsets the element VARNAME1(VARNAME2) of a Tcl array.
The optional argument FLAGS behaves as in I<setvar>.

=cut

.sub unsetvar2 :method
    .param string name1
    .param string name2
    .param int flags :optional
    .param int has_flags :opt_flag

    .local pmc f_unsetvar2
    f_unsetvar2 = get_global '_tcl_unsetvar2'
    .local pmc interp
    interp = getattribute self,'interp'
    .local int flags

    .Unless(has_flags,{
        flags = 0
    })

    .local string res
    res = f_unsetvar2(interp,name1,name2,flags)

    .return(res)
.end

=item MainLoop

MainLoop method, which corresponds to Tcl/Tk Tk_MainLoop call

=cut

.sub MainLoop :method
    # essentially we want to do:
    #   .local pmc f_mainloop
    #   f_mainloop = dlfunc libtk, "Tk_MainLoop", "v"
    #   f_mainloop()
    # we do not have libtk variable, however.
    # providing iface with libtk is easy, but we can avoid this
    # Instead of calling Tk_MainLoop, which is located in libtk8.5.so
    # we do same loop as in Tcl::Tk module. So loading tk shared library
    # is done by tcl itself.
    .local string res
    .local pmc libtcl
    .local pmc f_dooneevent, f_eval, f_getstringresult
    libtcl = get_global '_libtcl'
    f_eval = get_global '_tcl_eval'
    f_getstringresult = get_global '_tcl_getstringresult'
    f_dooneevent = dlfunc libtcl, "Tcl_DoOneEvent", "ii"
    .local pmc interp
    interp = getattribute self,'interp'

    # Loop until mainwindow exists (its path is '.')
    # below are 2 implementations how we get know that mainwindow no more avail
    #  1. eval "winfo exists ."
    #  2. use global variable, which will be destroyed upon exit
    # Now we prefer 2nd method.
    .IfElse(0==1,{
        .DoWhile({
            f_dooneevent(0)  # spin it
            # check if '.' window still exists
            f_eval(interp, 'winfo exists .')
            res = f_getstringresult(interp,0)
        },res=="1")
    },{
        .local pmc f_getvar
        f_getvar = get_global '_tcl_getvar'
        self.'setvar'("MainLoop_continuing","y",TCL_GLOBAL_ONLY)
        f_eval(interp,"trace add command . delete {unset MainLoop_continuing}")
        .DoWhile({
            f_dooneevent(0)  # spin it
            # check if flag variable "MainLoop_continuing" still exists
            res = f_getvar(interp,"MainLoop_continuing",TCL_GLOBAL_ONLY)
         },res=="y")
    })

.end

=item _load_lib_with_fallbacks(string friendly_name, pmc fallback_list)

This function is more generally useful than just for this module -- it
implements the search for a particular libary that may appear under any
of several different filenames.  The C<fallback_list> should be a simple
array of strings, each naming one of the possible filenames, I<without>
the trailing shared library extension (e.g. C<.dll> or C<.so>).  The
C<friendly_name> is only used to fill in the error message in case no
match can be found on the system.

BORROWED from OpenGL.pir - keep an eye on it (e.g. if it will be organized
elsewhere - reuse it from there)

=cut

.sub _load_lib_with_fallbacks
    .param string friendly_name
    .param pmc    fallback_list

    .local pmc    list_iter
    list_iter = iter fallback_list

    .local string libname
    .local pmc    library
  iter_loop:
    unless list_iter goto failed
    libname = shift list_iter
    library = loadlib libname
    unless library goto iter_loop

  loaded:
    print "tcl lib is "
    say libname
    .return (library)

  failed:
    .local string message
    message  = 'Could not find a suitable '
    message .= friendly_name
    message .= ' shared library!'
    die message
.end

.namespace ['TclLibrary';'Obj']

=item _init

base TclObj class for support of Tcl/Tk library

=cut

.sub _init :load :init
    .local pmc tclclass
    tclclass = newclass ['TclLibrary';'Obj']
    addattribute tclclass, 'tclobj'
    addattribute tclclass, 'interp'
.end

.sub get_string :method :vtable
    .local string str
    .local pmc f_getstr
    .local pmc tclobj
    tclobj = getattribute self, 'tclobj'
    f_getstr = get_hll_global ['TclLibrary'], '_tcl_getstringfromobj'
    str = f_getstr(tclobj, 0)
    .return(str)
.end

.namespace ['TclLibrary';'List']

=item _init

TclList support for Tcl/Tk library
Based on Tcl list object, i.e. TclObj of type tclListType

=cut

.sub _init :load :init
    .local pmc tclclass
    tclclass = subclass ['TclLibrary';'Obj'],['TclLibrary';'List']
.end

.sub init :method :vtable
    die "only allowed to instantiate with tcl object of type tclListTypePtr"
.end

.sub init_pmc :method :vtable
    .param pmc argh
    .local pmc tclobj, interp
    tclobj = argh['tclobj']
    interp = argh['interp']
    setattribute self, 'tclobj', tclobj
    setattribute self, 'interp', interp
.end

=for comment

length method calculates number of elements in tcl list by calling tcl API

=cut

.sub length :method
    .local int res
    .local pmc objc
    .local pmc func
    .local pmc tcllistobj, interp
    func = get_hll_global ['TclLibrary'], '_tcl_listobjlength'
    tcllistobj = getattribute self, 'tclobj'
    interp = getattribute self, 'interp'
    objc = new 'Integer' # TODO when should we free this? it GCed, but when?
    res = func(interp, tcllistobj, objc)
    .return(objc)
.end

=for comment

helper sub to create an array of PMCs out of tclListType

There could be 2 approaches - all via tcl strings, or via C API.
We try to do an efficient way to extract all elements at once.

=cut

.sub _tclobj_to_pmcarray
    .param pmc interp
    .param pmc tclobj

    .local pmc objc, objv # pointer which will hold array of tcl_obj's
    .local pmc objc_ptr, objv_ptr

    objv = new 'String'
    objv = "qwerty"
    objv_ptr = new 'String'
    objv_ptr = "qwerty"
    objc = new 'Integer'

    # Tcl_ListObjGetElements(NULL, objPtr, &objc, &objv);
    # if (objc) { .... }

    .local pmc f_listobjgetelements
    .local int rc
    say "123"
    f_listobjgetelements = get_hll_global ['TclLibrary'], '_tcl_listobjgetelements'
    say "456"
    rc = f_listobjgetelements(interp, tclobj, objc, objv_ptr)
    # we have objc TclObj in objv_ptr
    print "objc="
    say objc
    print "rc="
    say rc

    #TBD
.end


=back

=head1 SEE ALSO

http://www.tcl.tk

=head1 AUTHORS

TBD

=cut


# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
