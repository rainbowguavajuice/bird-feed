package imgtex;
use MIME::Base64 qw(encode_base64);

our @ISA = qw(Exporter);
our @EXPORT = qw(imgtex);

my $TEX_BIN  = 'tex';
my $DVIPNG_BIN = 'dvipng';
my $OUT = 'tmp';

my $fh;

my $tex_preamble = q(\font\tenamsb=msbm10 
\newfam\bbfam
\textfont\bbfam=\tenamsb
\def\Bbb{\fam\bbfam});

sub imgtex {

    my ($tex_str) = @_;

    open $fh, '>', $OUT_TEX;

    # generate TeX source file
    my $tex_src =
	$tex_preamble .
	q(\def\myeqn{$). $tex_str . q($}%
\nointerlineskip\noindent%
\def\mystrut{\vrule height 10pt depth 3.5pt width 0pt}%
\newbox\mybox\setbox\mybox\hbox{\mystrut\myeqn}%
\openout0=). $OUT . q(.dim\write0{%
\the\wd\mybox\the\ht\mybox\the\dp\mybox}%
\closeout0%
\noindent\unhcopy\mybox\end);

    open $fh, '>', "$OUT.tex";
    print $fh $tex_src;
    close $fh;

    # compile the TeX
    system "$TEX_BIN $OUT.tex";

    # read output dimensions
    open $fh, '<', "$OUT.dim";

    <$fh> =~ /(.+)pt(.+)pt(.+)pt/;
    my ($wd, $ht, $dp) = ($1, $2, $3);

    close $fh;

#    print "dimensions: $wd $ht $dp";

    my $png_w = $wd;
    my $png_h = $ht + $dp;
    # convert to png
    system "$DVIPNG_BIN -D1850.112 -T${png_w}pt,${png_h}pt -q* -o $OUT.png $OUT.dvi";
    #system "$DVIPNG_BIN -D462.528 -T${png_w}pt,${png_h}pt -q* -o $OUT.png $OUT.dvi";

    open $fh, '<', "$OUT.png";
    my $png_data = do { local $/; <$fh> };
    close $fh;

    my $pt_to_em = 1/10;
    my $css_w = $png_w * $pt_to_em;
    my $css_h = $png_h * $pt_to_em;
    my $css_d = $dp    * $pt_to_em;

#    print "$css_w, $css_h, $css_d\n";

    '<img style="height:'
    . $css_h . 'em; width:'
    . $css_w . 'em; vertical-align:-'
    . $css_d . 'em" src="data:image/png;base64,'
    . encode_base64($png_data) . '"/>';
}
1;
