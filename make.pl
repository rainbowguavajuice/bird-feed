#!/usr/bin/perl

use strict;
use warnings;
use autodie;

use Getopt::Long;
use Text::Template;

use FindBin;
use lib "$FindBin::Bin";
use imgtex;
use punct;

binmode STDOUT, ":utf8";

use constant {
    TMPL_DIR  => 'template/',
    SRC_DIR   => 'src/',
    # this should be named something more sensible, but hosting on
    # github pages is either this or building directly into the
    # project root directory.
    OUT_DIR   => 'docs/',
    PML_DIR   => 'permalink/'
};

my $NAME = 'bird feed';
my $BASE = '/';

GetOptions(
    'base=s'   => \$BASE,
    'gh-pages' => sub { $BASE = 'https://rainbowguavajuice.github.io/bird-feed/'; });

# directory and file handles; reused throughout file.
my ($dh, $fh);

# compile all templates up front.
opendir $dh, TMPL_DIR;
my %tmpl = map {
    my $tmpl_path = TMPL_DIR.$_;
    if (-f $tmpl_path and /(.+)\.tmpl$/) {
	print "load template $1 from $tmpl_path\n";
	($1, Text::Template->new(
	     TYPE     => 'FILE',
	     ENCODING => 'UTF-8',
	     SOURCE   => $tmpl_path
	 ));
    } else { (); }
} readdir $dh;
closedir $dh;

# collect source file information: identify dates and generate
# alphanumeric IDs, ignoring files with ill-formed names.
opendir $dh, SRC_DIR;
my @src = map {
    my $src_path = SRC_DIR.$_;
    if (-f $src_path and /^(\d{4}-\d{2}-\d{2})([A-Z]+)$/) {
	{ date => $1,
	  id   => $1 =~ y/-//rd.$2,
	  path => $src_path };
    } else { (); }
} reverse sort readdir $dh;
closedir $dh;

sub url_from_path { $BASE.$_[0]; }

# convert post id -> permalink URL
sub permalink_url { url_from_path PML_DIR.$_[0].'.html'; }

# processes a single post from a file. returns a list with the
# permalink url as the first entry, followed by the metadata, followed
# by a triplet of formatted posts in three different levels of
# verbosity.
sub fmt_post {
    my ($date, $id, $path) = @_;

    open $fh, '<', $path;

    # the first line is always the title.
    chomp (my $head = <$fh>);
    # for the remainder of the file, read paragraph-by-paragraph.
    my @tail;
    {
	local $/ = "";
	while (<$fh>) {
	    chomp;
	    push @tail, $_;
	}
    }
    close $fh;

    # post-processing:
    # use HTML entities for punctuation
    punct \@tail;
    # render all the bits of TeX
    imgtex \@tail;

    my $url = permalink_url $id;

    ($url,
     $tmpl{meta}->fill_in(
	 STRICT => 1,
	 HASH   => {
	     site_name => $NAME,
	     base      => $BASE,
	     title     => "$NAME: $head",
	     url       => $url,
	     desc      => 'description',
	     date      => $date
	 }),
     map {
	 $tmpl{$_}->fill_in(
	     STRICT => 1,
	     HASH   => {
		 date  => $date,
		 url   => $url,
		 title => $head,
		 body  => \@tail }
	     );
     } ('post_line', 'post_para', 'post_full'));
}

# this is the array that tells the script which pages should be in the
# navigation bar. the contents of each page are in the form of an
# array; this is passed directly to the template which decides how to
# interpret it.
#
my @pages = ({ page_name => 'latest',  path => 'index.html',   list => [] },
	     { page_name => 'about',   path => 'about.html',   list => [] },
	     { page_name => 'archive', path => 'archive.html', list => [] });

# the 'archive' and 'latest' pages are special because their data is
# built by reading the source folder later; remember where they are in
# the list so that we can update them later. it's annoting that we
# have to do this, but @pages is a list instead of a hash so that the
# order in which they show up in the nav bar is well-defined.
my $archive_page = $pages[2];
my $latest_page  = $pages[0];

# generate the navigation bar --- this has to be done first to be
# included in the permalink pages for individual posts.
#
# 'random' button is a special case.
my @navi_list = ((map { [$_->{page_name}, url_from_path $_->{path}]; } @pages),
		 ['random',  "javascript:goto_random_post();"]);

my $navi = $tmpl{navi}->fill_in(
    STRICT => 1,
    HASH   => { list => \@navi_list });

my (@urls, @lines, @paras);

foreach (@src) {

    my $permalink_path = PML_DIR.$_->{id}.'.html';
    print "generate $permalink_path from $_->{path}\n";

    my ($url, $meta, $line, $para, $full) =
	fmt_post $_->{date}, $_->{id}, $_->{path};

    push @urls,  $url;
    push @lines, $line;
    push @paras, $para;

    # accumulate for line and para views, but write to the full view
    # page immediately
    open $fh, '>', OUT_DIR.$permalink_path;

    $tmpl{frame}->fill_in(
	STRICT => 1,
	HASH   => { meta      => $meta,
		    site_name => $NAME,
		    navi      => $navi,
		    main      => $full },
	OUTPUT => $fh);

    close $fh;

}

$archive_page->{list} = \@lines;
$latest_page->{list} = \@paras;

# now we can format each page.
sub fmt_page {
    my ($page_name, $path, $list) = @_;

    print "generate $path\n";
    open $fh, '>', OUT_DIR.$path;

    my $meta =
	$tmpl{meta}->fill_in(
	    STRICT => 1,
	    HASH   => {
		site_name => $NAME,
		base      => $BASE,
		title     => "$NAME: $page_name",
		url       => (url_from_path $path),
		desc      => 'description',
		date      => '2023'
	    });

    my $main =
	$tmpl{$page_name}->fill_in(
	    STRICT => 1,
	    HASH   => { list => $list });

    $tmpl{frame}->fill_in(
	STRICT => 1,
	HASH   => { meta      => $meta,
		    site_name => $NAME,
		    navi      => $navi,
		    main      => $main },
	OUTPUT => $fh);
    close $fh;
}

fmt_page $_->{page_name}, $_->{path}, $_->{list} for @pages;

# generate javascript.
my $script_path = 'script.js';
print "generate $script_path\n";

open $fh, '>', OUT_DIR.$script_path;
$tmpl{script}->fill_in(
    STRICT => 1,
    HASH   => { list => \@urls },
    OUTPUT => $fh);
close $fh;
