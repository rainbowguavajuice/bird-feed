package imgtex;
use MIME::Base64 qw(encode_base64);

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(imgtex);

# my @para = (
#     q(one $tex$ two $tex2$ three $\displaystyle\int_\gamma{1\over z-z_0}\,{\roman d}z$ four $Q^{-1}$),
#     q(four $hello$ five $1\over 2$ more $\Bbb C$));

use constant {
    OUT => 'tmp',
    TEX_BIN => 'tex',
    DVIPNG_BIN => 'dvipng',
    TEX_REGEXP => qr/\$((?:.|\s)+?)\$/,
    VERTSEP => 1
};

# file handles; reused.
my ($fh_tex, $fh_png);

# deeply evil static variables. get reset at the beginning of `imgtex`
# and incremented with each call of `imgtex_inline`.
my ($count, @dimen);

sub imgtex_inline {
    my ($ft, $wd, $ht, $dp) = @{$dimen[$count]};
    ++$count;

    # pull PNG from the region of the DVI containing the snippet we want
    my ($png_o, $png_w, $png_h, $png_d) = ($ft, $wd, $ht + $dp + 2 * VERTSEP, $dp + VERTSEP);
    system "${\DVIPNG_BIN}" .
	# 1850.112
    " -D462.528 -O0pt,-${png_o}pt -T${png_w}pt,${png_h}pt" .
    " -q* -o ${\OUT}.png ${\OUT}.dvi";

    open $fh_png, '<', "${\OUT}.png";
    my $png_data = do { local $/; <$fh_png>; };
    close $fh_png;

    my $pt_to_em = 1/10;
    my $css_h = $png_h * $pt_to_em;
    my $css_d = $png_d * $pt_to_em;

    # return the <img> tag to be substituted in.
    q(<img style="height:) . $css_h .
	q(em; vertical-align: -) . $css_d .
	q(em;" src="data:image/png;base64,) .
	encode_base64($png_data) .
	q("/>);
}

sub imgtex {

    my ($para) = @_;

    $count = 0;
    @dimen = ();

    my @inline_tex;
    push @inline_tex, map { local $/; $_ =~ m/${\TEX_REGEXP}/g; } @$para;
    print "TeX snippet: $_\n" for @inline_tex;

    open $fh_tex, '>', "${\OUT}.tex";
    # the \vertsep rules place margins between neighbouring lines because
    # some letters seem to be stealthily higher than they claim to be.
    print $fh_tex
	q(\input amstex \loadmsbm\loadeufm) .
	q(\newdimen\vertsep\vertsep) . VERTSEP . q(pt) .
	q(\newdimen\fromtop\fromtop0pt) .
	q(\def\vertseprule{\hrule height \vertsep width 0pt}) .
	q(\newbox\mybox) .
	q(\newwrite\myout\immediate\openout\myout=) . OUT . '.dim' .
	q(\topskip0pt\offinterlineskip);
    foreach (@inline_tex) {
	print $fh_tex
	    q(\setbox\mybox\hbox{$) .
	    $_ .
	    q($}) .
	    q(\immediate\write\myout{\the\fromtop\the\wd\mybox\the\ht\mybox\the\dp\mybox}) .
	    q(\advance\fromtop\ht\mybox\advance\fromtop\dp\mybox\advance\fromtop2\vertsep) .
	    q(\vertseprule\noindent\unhcopy\mybox\vertseprule);
    }
    print $fh_tex q(\closeout\myout\end);
    close $fh_tex;

    # compile the TeX. this also writes dimension information to OUT.dim
    system "${\TEX_BIN} ${\OUT}.tex";

    # read back dimension info
    open $fh_tex, '<', "${\OUT}.dim";
    while (<$fh_tex>) {
	my @dim = $_ =~ m/(.*)pt(.*)pt(.*)pt(.*)pt/;
	push @dimen, \@dim;
    }
    close $fh_tex;

    # substitute
    do { local $/; $_ =~ s/${\TEX_REGEXP}/(imgtex_inline)/eg; } for @$para;
}
1;
