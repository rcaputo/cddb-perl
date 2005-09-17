#!perl -w
# $Id$
# vim: filetype=perl
# 
# Copyright 1998-2005 Rocco Caputo <troc@netrus.net>.  All rights
# reserved.  This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.

use strict;
use CDDB;

BEGIN {
	select(STDOUT); $|=1;
	print "1..34\n";
};

my ($i, $result);

### test connecting

my $cddb = new CDDB(
	Host           => 'freedb.freedb.org',
	Port           => 8880,
	Submit_Address => 'test-submit@freedb.org',
	Debug          => 0,
);

defined($cddb) || print 'not '; print "ok 1\n";

### test genres

my @test_genres = qw(
	blues classical country data folk jazz misc newage reggae rock
	soundtrack
);
my @cddb_genres = $cddb->get_genres();

if (@cddb_genres) {
	print "ok 2\n";
	if (@cddb_genres == @test_genres) {
		print "ok 3\n";
		@test_genres = sort @test_genres;
		@cddb_genres = sort @cddb_genres;
		$result = 'ok';
		while (my $test = shift(@test_genres)) {
			$result = 'not ok' if ($test ne shift(@cddb_genres));
		}
		print "$result 4\n";
	}
}
else {
	print "not ok 2\n";
	print "not ok 3\n";
	print "not ok 4\n";
}

### helper sub: replace != tests with "not off by 5%"

sub not_near {
	my ($live, $test) = @_;
	return (abs($live-$test) > ($test * 0.05));
}

### sample TOC info for next few tests

# A CD table of contents is a list of tracks acquired from whatever Your
# Particular Operating System uses to manage CD-ROMs.  Often, it's some
# sort of API or ioctl() interface.  You're on your own here.
#
# Whatever you use should return the TOC as a list of whitespace-delimited
# records.  Each record should have three fields: the track number, the
# minutes offset of the track's beginning, the seconds offset of the track's
# beginning, and the leftover frames of the track's offset.  In other words,
#    track_number M S F  (where M S and F are defined in the CD-I spec.)
#
# Special information is indicated by these "virtual" track numbers:
#   999: lead-out information (same as regular track format)
#  1000: error reading TOC (minutes and seconds are unused; frame
#        contains a text message describing the error)
#
# Sample TOC information:

my @toc = (
	"1   0  1  71",  # track  1 starts at 00:01 and 71 frames
	"999 5 42   4",  # leadout  starts at 05:42 and  4 frames
);

### calculate CDDB ID

my ($id, $track_numbers, $track_lengths, $track_offsets, $total_seconds) =
	$cddb->calculate_id(@toc);

($id ne '03015501') && print 'not '; print "ok 5\n";
&not_near($total_seconds, 344) && print 'not '; print "ok 6\n";

my @test_numbers = qw(001);
my @test_lengths = qw(05:41);
my @test_offsets = qw(296);

if (@$track_numbers == @test_numbers) {
	print "ok 7\n";
	$i = 0; $result = 'ok';
	foreach my $number (@test_numbers) {
		$result = 'not ok' if ($number ne $track_numbers->[$i++]);
	}
	print "$result 8\n";
}
else {
	print "not ok 7\n";
	print "not ok 8\n";
}

if (@$track_lengths == @test_lengths) {
	print "ok 9\n";
	$i = 0; $result = 'ok';
	foreach my $length (@test_lengths) {
		$result = 'not ok' if ($length ne $track_lengths->[$i++]);
	}
	print "$result 10\n";
}
else {
	print "not ok 9\n";
	print "not ok 10\n";
}

if (@$track_offsets == @test_offsets) {
	print "ok 11\n";
	$i = 0; $result = 'ok';
	foreach my $offset (@test_offsets) {
		$result = 'not ok' if (&not_near($offset, $track_offsets->[$i++]));
	}
	print "$result 12\n";
}
else {
	print "not ok 11\n";
	print "not ok 12\n";
}

### test looking up discs (one match)

my @discs = $cddb->get_discs($id, $track_offsets, $total_seconds);

(@discs == 1) || print 'not '; print "ok 13\n";

my ($genre, $cddb_id, $title) = @{$discs[0]};
($genre   eq 'misc')      || print 'not '; print "ok 14\n";
($cddb_id eq '03015501')  || print 'not '; print "ok 15\n";

print 'not ' unless $title =~ / freedb disc ID test/i;
print "ok 16 # $title\n";

### test macro lookup

$cddb->disconnect();
my @other_discs = $cddb->get_discs_by_toc(@toc);

if (@other_discs) {
	(@other_discs == 1) || print 'not '; print "ok 17\n";
	($other_discs[0]->[0] eq $discs[0]->[0]) || print 'not '; print "ok 18\n";
	($other_discs[0]->[1] eq $discs[0]->[1]) || print 'not '; print "ok 19\n";
	($other_discs[0]->[2] eq $discs[0]->[2]) || print 'not '; print "ok 20\n";
}
else {
	for (17..20) {
		print "not ok $_ # no result\n";
	}
}

### test gathering disc details

$cddb->disconnect();
my $disc_info = $cddb->get_disc_details($genre, $cddb_id);

# -><- uncomment if you'd like to see all the details
# foreach my $key (sort keys(%$disc_info)) {
#   my $val = $disc_info->{$key};
#   if (ref($val) eq 'ARRAY') {
#     print STDERR "\t$key: ", join('; ', @{$val}), "\n";
#   }
#   else {
#     print STDERR "\t$key: $val\n";
#   }
# }

($disc_info->{'disc length'} eq '344 seconds') || print 'not ';
print "ok 21 # $disc_info->{'disc length'}\n";

($disc_info->{'discid'} eq $cddb_id) || print 'not ';
print "ok 22\n";

($disc_info->{'dtitle'} eq $title) || print 'not ';
print "ok 23\n";

if (@{$disc_info->{'offsets'}} == @$track_offsets) {
	print "ok 24\n";
	$i = 0; $result = 'ok';
	foreach my $offset (@{$disc_info->{'offsets'}}) {
		$result = 'not ok' if &not_near($offset, $track_offsets->[$i++]);
	}
	print "$result 25\n";
}
else {
	print "not ok 24\n";
	print "not ok 25\n";
}

my @test_titles = ( "5:40:00" );

my $ok_tracks = 0;
$i = 0; $result = 'ok';
foreach my $detail_title (@{$disc_info->{'ttitles'}}) {
	my ($detail_norm, $test_norm) = (lc($detail_title), lc($test_titles[$i++]));

	next unless $detail_norm eq $test_norm;
	$ok_tracks++;
}

print "not " unless $ok_tracks >= @test_titles / 2;
print "ok 26 # $ok_tracks >= ", (@test_titles / 2), " ?\n";

### test fuzzy matches ("the freeside tests")

$id = 'a70cfb0c';
$total_seconds = 3323;
my @fuzzy_offsets = qw(
	0 20700 37275 57975 78825 102525 128700 148875 167100 184500 209250
	229500
);

@discs = $cddb->get_discs($id, \@fuzzy_offsets, $total_seconds);
@discs || print 'not '; print "ok 27\n";

($genre, $cddb_id, $title) = @{$discs[0]};
(length $genre)         || print 'not '; print "ok 28\n";
(length($cddb_id) == 8) || print 'not '; print "ok 29\n";
(length $title)         || print 'not '; print "ok 30\n";

$id = 'c509b810';
$total_seconds = 2488;
@fuzzy_offsets = qw(
	0 11250 19125 33075 47850 58950 69075 80175 91500 105975 120225
	142425 152325 163200 167850 182775
);

@discs = $cddb->get_discs($id, \@fuzzy_offsets, $total_seconds);

if (@discs > 1) {
	print "ok 31\n";
}
else {
	print "not ok 31\n";
}

### test CDDB submission

if ($cddb->can_submit_disc()) {
	eval {
		$cddb->submit_disc(
			Genre       => 'classical',
			Id          => 'b811a20c',

			# iso-8859-1 u with diaeresis (umlaut) for testing
			Artist      => "Vario\xDCs",
			DiscTitle   => 'Cartoon Classics',
			Offsets     => $disc_info->{'offsets'},
			TrackTitles => $disc_info->{'ttitles'},

			# odd revision for testing
			Revision    => 123,
		);
		print "ok 32\n";
	};

	# skip if SMTPHOSTS and default are bad
	if ($@ ne '') {
		print "ok 32 # Skip - $@\n";
	}
}

# <bekj> dngor It's not Polite to have tests fail when things are OK,
# Makes CPAN choke :(

																				# skip when needed modules are missing
else {
	print(
		"ok 32 # Skip - Mail::Internet; Mail::Header; and MIME::QuotedPrint ",
		"are needed to submit discs\n"
	);
}

### Test fetch-by-query.

my $query = (
	"cddb query d30ffd0e 14 150 19705 40130 59947 77417 96730 109345" .
	" 131927 149287 167635 185130 206002 229075 279870 4095"
);

@discs = $cddb->get_discs_by_query($query);
if (@discs) {
	print "not " unless $discs[0][0] eq 'rock';
	print "ok 33\n";
	print "not " unless $discs[0][1] eq 'd30ffd0e';
	print "ok 34\n";
}
else {
	print "not ok 33\n";
	print "not ok 34\n";
}

__END__

sub developing {
																				# CD-ROM interface
	$cd = new CDROM($device) or die $!;
																				# loads CD TOC
	@toc = $cd->toc();
																				# returs an array like:


	$toc[0] = [ # track 999 is the lead-out information
							# track 1000 indicates an error
							$track_number,
							# next three fields are CD-i MSF information, broken apart
							$offset_minutes, $offset_seconds, $offset_frames,
						];
																				# rips a track to a file
	$cd->rip(track => 2, file => '/tmp/track-2', format => 'wav') or die $!;
	$cd->rip(start => '12:34/0', stop => '15:57/0', file => '/tmp/msfrange',
					 format => 'wav'
					) or die $!;

	# synchronous methods wait for finish
	$cd->play(track => 1, method => synchronous);

	# asynch methods return right away
	$cd->play(track => 2, method => asynchronous);

	# returns what's going on ('playing', 'ripping', etc.)
	# used to poll the device during asynchronous operations?
	$cd->status();

	# fill out the interface
	$cd->stop();
	$cd->pause();
	$cd->resume();

	# whimsy.  virtually useless stuff, but why not?
	$cd->seek(track => 1);
	$cd->seek(offset => '12:34/0');
	$cd->seek(offset => '-0:34/0');
	$cd->seek(offset => '+0:34/0');
}
