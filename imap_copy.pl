#!/usr/bin/perl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 1

my $usage = "Copyright Olivier Salaün 2015

The imap_copy.pl script allows to copy content of mail folders 
from one IMAP server to another IMAP server. A configuration file is used to define
connexion parameters for each IMAP server. List of folders to copy and the corresponding
destination folders can either be specified with command line option or in the
configuration file (useful for bulk copying a set of folders). A sample configuration file
is provided.

See below example of script calls:

Example 1: list folders on SRC IMAP server
  ./imap_copy.pl --config=Conf.pm --list_folders --src_server=my_imap_src

Example 2: list messages on INBOX folder from SRC IMAP server
  ./imap_copy.pl --config=Conf.pm --list_messages --src_server=my_imap_src --src_folder=INBOX

Example 3: Copy content of folder Work/CV of SRC IMAP to foder CV of DEST IMAP server
  ./imap_copy.pl --config=Conf.pm --migrate --src_server=my_imap_src --src_folder=Work/CV --dest_server=my_imap_dest --dest_folder=CV

Example 4: Copy folders from SRC IMAP server to DEST IMAP server. List of src and dest
folders are defined in configuration file.
  ./imap_copy.pl --config=Conf.pm --migrate --src_server=my_imap_src  --dest_server=my_imap_dest

Example 5: Rename a folder on SRC IMAP server
  ./imap_copy.pl --config=Conf.pm --rename_folder --src_server=my_imap_src --src_folder=Archives --dest_folder=_Archives

Installation requirements :
 - perl
 - Mail::IMAPClient library (see http://search.cpan.org/~djkernen/Mail-IMAPClient-2.2.9/)

See http://www.athensfbc.com/imap_tools/details.html for alternative IMAP tools
";


use ImapCopy::Imap;
use ImapCopy::Tools;
use Data::Dumper;
use Getopt::Long;

my %options;
&GetOptions(\%options, 'config=s','delete_folder','dest_folder=s','dest_server=s', 'help',
'list_folders','list_messages','migrate','rename_folder','src_server=s','src_folder=s');

if ($options{'help'}) {
	print $usage;
	exit 0;
}


unless ($options{'config'} and -f $options{'config'}) {
    die "Missing --config option";
}

unless (require $options{'config'}) {
    die "Fail to load configuration from $options{'config'}";
}


## Connect to IMAP servers
my %imap_servers;
foreach my $server_name (keys %imap_config) {
    my $server_config = $imap_config{$server_name};
    printf "Connect to IMAP server %s\n", $server_config->{'server'};
    $imap_servers{$server_name} = new ImapCopy::Imap(%{$server_config});
    
    unless (defined $imap_servers{$server_name}) {
	die "Failed to connect to IMAP server '".$server_config->{'server'}."'";
    }
	
    unless (defined $imap_servers{$server_name}->connect()) {
	die "Failed to connect to IMAP server '".$server_config->{'server'}."'";
    } 
}
    
my ($src_imap, $dest_imap);
if ($options{'src_server'}) {
    
    unless (defined $imap_servers{$options{'src_server'}}) {
	die "Undefined server '%s'", $options{'src_server'};
    }
    
    $src_imap = $imap_servers{$options{'src_server'}};
}

if ($options{'dest_server'}) {

    unless (defined $imap_servers{$options{'dest_server'}}) {
	die "Undefined server '%s'", $options{'sdestserver'};
    }
    
    $dest_imap = $imap_servers{$options{'dest_server'}};
}

if ($options{'list_folders'}) {
    unless (defined $src_imap) {
	die "First set 'select_src';"
    }
    
    printf "List folders from %s\n", $src_imap->{'server'};
    ## List folders
    my @folders;
    unless (@folders = $src_imap->list_folders()) {
	do_log('error', "Failed to list folders on IMAP server '%s'", $src_imap->{'server'});
	exit -1;
    }
    
    printf Data::Dumper::Dumper(\@folders);

}elsif ($options{'list_messages'}) {
    unless ($options{'src_folder'}) {
	die "Missing 'src_folder' option";
    }
    
    unless (defined $src_imap) {
	die "First set 'select_src';"
    }

    printf "Search messages\n";
    ## List messages in Folder
    my @messages;
    unless (@messages = $src_imap->search_messages_in_folder($options{'src_folder'})) {
	do_log('error', "Failed to search on IMAP server '%s'", $src_imap->{'server'});
	exit -1;
    }
    
    printf Data::Dumper::Dumper(\@messages);
    
}elsif ($options{'migrate'}) {
    
    unless (defined $src_imap) {
	die "First set 'src_server';"
    }

    unless (defined $dest_imap) {
	die "First set 'dest_server';"
    }

    our %migrate_folder;
    if ($options{'src_folder'} && $options{'dest_folder'}) {
        %migrate_folder = ($options{'src_folder'} => $options{'dest_folder'});
    }else {
        ## Using mapping defined in configuration file
        unless (%migrate_map) {
            die "You should either define --src_folder and --dest_folder of define %migrate_map in your configuration file for batch migration";
        }
    }

    foreach my $src_folder (keys %migrate_map) {
	my $dest_folder = $migrate_map{$src_folder};
	printf "Migrate content of server %s, folder %s TO server %s, folder %s\n", $src_imap->{'server'}, $src_folder, $dest_imap->{'server'}, $dest_folder;
	
	my $result = $src_imap->migrate_folder(src_folder => $src_folder,
						dest_server => $dest_imap,
						dest_folder => $dest_folder);
	unless (defined $result ) {
	    die "Failed to migrate messages";
	}
	
	printf "Done migrating %d messages\n", $result;
    }

}elsif ($options{'delete_folder'}) {
    unless ($options{'src_folder'}) {
	die "Missing 'src_folder' option";
    }
    
    unless (defined $src_imap) {
	die "First set 'select_src';"
    }

    printf "Deleting folder $options{'src_folder'} on server %s\n", $src_imap->{'server'};
    printf "Confirm (y/n):";
    my $confirmation = <STDIN>; chomp $confirmation;
    
    unless ($confirmation eq "y") {
	die "Canceled";
    }
    
    unless ($src_imap->delete_folder($options{'src_folder'})) {
	die "Failed to delete folder";
    }
    
    printf "Done\n";
}elsif ($options{'rename_folder'}) {
    unless ($options{'src_folder'}) {
	die "Missing 'src_folder' option";
    }
    
    unless (defined $src_imap) {
	die "First set 'src_server';"
    }

    unless ($options{'dest_folder'}) {
	die "Missing 'dest_folder' option";
    }
        
    
    my $result = $src_imap->rename_folder(src_folder => $options{'src_folder'},
					    dest_folder => $options{'dest_folder'});
    unless (defined $result ) {
	die "Failed to migrate messages";
    }
    
    printf "Done renaming folder %s to %s\n", $options{'src_folder'}, $options{'dest_folder'};    
}

## Disconnect from IMAP servers
foreach my $server (values %imap_servers) {
    $server->disconnect();
}
