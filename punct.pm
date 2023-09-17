package punct;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(punct);

sub punct {
    my ($para) = @_;
    for (@$para) {
	# left & right double quotes
	s/``((?:\s|.)*?)''/&ldquo;$1&rdquo;/g;
	s/`((?:\s|.)*?)'/&lsquo;$1&rsquo;/g;
	# en & em dashes
	s/---/&mdash;/g;
	s/--/&ndash;/g;
    }
}
