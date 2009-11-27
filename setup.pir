#! /usr/local/bin/parrot
# Copyright (C) 2009, Parrot Foundation.

=head1 NAME

setup.pir - Python distutils style

=head1 DESCRIPTION

No Configure step, no Makefile generated.

=head1 USAGE

    $ parrot setup.pir build
    $ parrot setup.pir test
    $ sudo parrot setup.pir install

=cut

.sub 'main' :main
    .param pmc args
    $S0 = shift args
    load_bytecode 'distutils.pbc'

    $P0 = new 'Hash'
    $P0['name'] = 'tcl-bridge'
    $P0['abstract'] = 'Tcl/Tk binding for Parrot'
    $P0['authority'] = 'http://github.com/vadrer'
    $P0['description'] = 'This is the tcl/tk library bridge for Parrot VM.'
    $P5 = split ',', 'tcl/tk,Tcl::Tk,tcl'
    $P0['keywords'] = $P5
    $P0['license_type'] = 'Artistic License 2.0'
    $P0['license_uri'] = 'http://www.perlfoundation.org/artistic_license_2_0'
    $P0['copyright_holder'] = 'Parrot Foundation'
    $P0['checkout_uri'] = 'git://github.com/vadrer/tcl-bridge.git'
    $P0['browser_uri'] = 'http://github.com/vadrer/tcl-bridge'
    $P0['project_uri'] = 'http://github.com/vadrer/tcl-bridge'

    # build
    $P1 = new 'Hash'
    $P1['src/TclLibrary.pbc'] = 'src/TclLibrary.pir'
    $P0['pbc_pir'] = $P1

    # test
    $S0 = get_parrot()
    $S1 = " -L src"
    $S0 .= $S1
    $P0['prove_exec'] = $S0

    # install
    $P3 = split "\n", <<'LIBS'
src/TclLibrary.pir
LIBS
    $S0 = pop $P3
    $P0['inst_lang'] = $P3

    .tailcall setup(args :flat, $P0 :flat :named)
.end

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
