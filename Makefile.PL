#!/usr/bin/perl

use ExtUtils::MakeMaker;

## Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

WriteMakefile(
	NAME         => 'CDDB',
	AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
	ABSTRACT     => 'High-level interface to CDDB and freedb servers.',
	LICENSE      => 'perl',
	VERSION_FROM => 'lib/CDDB.pm',
	PREREQ_PM    => {
		'Test::More' => 0,
	},
	META_ADD     => {
		resources  => {
			license    => 'http://dev.perl.org/licenses/',
			repository => 'http://github.com/rcaputo/cddb-perl'
		},
	},
	dist         => {
		COMPRESS   => 'gzip -9',
		SUFFIX     => 'gz',
		PREOP      => (
			'git-log.pl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
		),
	},
);
