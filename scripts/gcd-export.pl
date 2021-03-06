#!/usr/bin/env perl

use strict;
use warnings;

use POSIX qw/strftime/;

#
# Constants.  Avoiding 'use constant' because it doesn't interpolate easily
# into strings.  Code should treat these as constants, however.
#

my $DB = '';
my $DBHOST = '';
my $DBUSER = '';
my $DATA_DIR = '';

my $DATE = strftime('%Y-%m-%d', localtime);

# Tables that don't contain deleted data
my $PUBLIC_SUPPORT_TABLES =
  'stddata_country stddata_language gcd_story_type ' .
  'gcd_issue_reprint gcd_reprint gcd_reprint_from_issue ' .
  'gcd_reprint_to_issue gcd_brand_emblem_group gcd_brand_use ' .
  'gcd_series_bond gcd_series_bond_type gcd_series_publication_type ' .
  'taggit_tag taggit_taggeditem django_content_type gcd_name_type ' .
  'gcd_relation_type gcd_school gcd_degree gcd_membership_type ' .
  'gcd_non_comic_work_role gcd_non_comic_work_type gcd_non_comic_work_year';

# Tables with deleted data which will be filtered out in the dump
# using $PUBLIC_DATA_WHERE
my $PUBLIC_DATA_TABLES =
  'gcd_publisher gcd_brand_group gcd_brand gcd_indicia_publisher gcd_series ' .
  'gcd_issue gcd_story gcd_award gcd_creator ' .
  'gcd_creator_art_influence gcd_creator_award gcd_creator_degree ' .
  'gcd_creator_membership gcd_creator_name_detail gcd_creator_non_comic_work ' .
  'gcd_creator_relation gcd_creator_school';

my $PUBLIC_DATA_WHERE = 'deleted=0';

#
# Functions.
#

sub do_dump {
    my $tmp_sql = shift;     # Temporary filename for dump output
    my $zip_name = shift;    # Name to pass to zip (must not end in .zip!)
    my $link_name = shift;   # Name of the 'current' symlink
    my $extra = shift || ''; # Extra options to mysqldump

    my $file_name = "$zip_name.zip";

    my $dump_prefix = "mysqldump -u$DBUSER -h$DBHOST $DB";
    my @commands = (
        "$dump_prefix $extra $PUBLIC_SUPPORT_TABLES > $tmp_sql",
        "$dump_prefix $extra $PUBLIC_DATA_TABLES " .
          "--where $PUBLIC_DATA_WHERE >> $tmp_sql",
        "zip -j $zip_name $tmp_sql",
    );

    for my $cmd (@commands) {
        print "Running '$cmd'\n";
        undef $!;
        if (system($cmd)) {
            if ($? == -1) {
                die "'$cmd' failed to execute: $!\n";
            } elsif ($? & 127) {
                die sprintf("'$cmd' died with signal %d, %s coredump\n",
                            ($? & 127), ($? & 128) ? 'with' : 'without');
            }
            die sprintf("'$cmd' failed exit status %d\n", $? >> 8);
        }
    }

    if (-l $link_name) {
        unlink($link_name) or die "Cannot unlink '$link_name': $!\n";
    }

    symlink($file_name, $link_name)
      or die "Cannot symlink file '$file_name' to '$link_name': $!\n";
    unlink($tmp_sql) or die "Cannot unlink '$tmp_sql': $!\n";
}


sub main {
    # Standard dumps
    do_dump("/tmp/$DATE.sql", "$DATA_DIR/$DATE", "$DATA_DIR/current.zip");

    # Wait a minute between dumps.
    sleep(60);

    # PostGreSQL compatible dumps
    do_dump("/tmp/pg-$DATE.sql",
            "$DATA_DIR/pg-$DATE",
            "$DATA_DIR/pg-current.zip",
            '--compatible=postgresql');
};

main();

