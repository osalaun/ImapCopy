package ImapCopy::Imap;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use Mail::IMAPClient;
use ImapCopy::Tools;


## Creates a new object
sub new {
    my($pkg, %in) = @_;
    my $self = {};
    
    foreach my $param ('server','port','use_ssl','user','password') {
	unless (defined $in{$param}) {
	    &do_log('error', "Missing parameters '%s' to connect to IMAP server", $param);
	    return undef;
	}
	$self->{$param} = $in{$param};
    }
    
        
    ## Bless Message object
    bless $self, $pkg;

    return $self;
}

## Connect to IMAP server and get connexion handler
sub connect {
    my $self = shift;
    
    $self->{'imap_handler'} = Mail::IMAPClient->new( # returns a new, authenticated Mail::IMAPClient object
				 Server   => $self->{'server'},
				 Port     => $self->{'port'},
				 Ssl      => $self->{'use_ssl'},
				 User     => $self->{'user'},
				 Password => $self->{'password'},
				 Peek     => 1,
				);
    
    unless (defined $self->{'imap_handler'}) {
	&do_log('error', 'Failed to connect to IMAP server: %s', $@);
	return undef;
    }

    return 1;    
}

## Disconnect from server
sub disconnect {
    my $self = shift;

    unless (defined $self->{'imap_handler'} and $self->{'imap_handler'}->disconnect()) {
	die "Failed to disconnect from server $self->{'server'}";
    }
    
    return 1;
}

## Append message to mailbox
sub append_message {
    my $self = shift;
    my $mailbox = shift;
    my $message = shift;
    
    ## Reconnect if needed
    unless ($self->{'imap_handler'}->IsConnected()) {
	$self->connect();
    }
    
    unless ($self->{'imap_handler'}->append($mailbox, $message )) {
	&do_log('error', 'Failed to append a message to mailbox %s: %s', $mailbox, $self->{'imap_handler'}->LastError);
	return undef;
    }

    return 1;
}

sub create_folder {
    my $self = shift;
    my $folder = shift;
    
    ## Reconnect if needed
    unless ($self->{'imap_handler'}->IsConnected()) {
	$self->connect();
    }

    if ($self->{'imap_handler'}->exists($folder)) {
	&do_log('info', "Folder $folder already exists; do not create it");
	return 1;
    }
    
    unless ($self->{'imap_handler'}->create($folder)) {
	&do_log('error', 'Failed to create folder %s: %s', $folder, $self->{'imap_handler'}->LastError);
	return undef;
    }    
    
    return 1;
}

sub list_folders {
    my $self = shift;
    
    my @folders;
    unless (@folders = $self->{'imap_handler'}->folders()) {
	&do_log('error', 'Failed to list folders: %s', $mailbox, $self->{'imap_handler'}->LastError);
	return undef;
    }

    return @folders;
}

## Delete folder
sub delete_folder {
    my $self = shift;
    my $folder = shift;

    ## Reconnect if needed
    unless ($self->{'imap_handler'}->IsConnected()) {
	$self->connect();
    }

    unless ($self->{'imap_handler'}->delete($folder)) {
	&do_log('error', 'Failed to delete folder %s: %s', $folder, $self->{'imap_handler'}->LastError);
	return undef;
    }
    
    return @messages;
}

## Search messages in mailbox
sub search_messages_in_folder {
    my $self = shift;
    my $folder = shift;

    ## Reconnect if needed
    unless ($self->{'imap_handler'}->IsConnected()) {
	$self->connect();
    }

    unless ($self->{'imap_handler'}->select($folder)) {
	&do_log('error', 'Failed to select folder %s: %s', $folder, $self->{'imap_handler'}->LastError);
	return undef;
    }

    my @messages;
    unless (@messages = $self->{'imap_handler'}->search('ALL')) {
	&do_log('error', 'Failed to search in folder %s: %s', $folder, $self->{'imap_handler'}->LastError);
	return undef;
    }
    
    return @messages;
}

## Rename folder
sub rename_folder {
    my $self = shift;
    my %in = @_;
    
    unless (defined $in{'dest_folder'}) {
	    &do_log('error', "Missing parameters 'dest_folder'");
	    return undef;
    }

    unless (defined $in{'src_folder'}) {
	    &do_log('error', "Missing parameters 'src_folder'");
	    return undef;
    }

    unless ($self->{'imap_handler'}->rename($in{'src_folder'}, $in{'dest_folder'})) {
	&do_log('error', 'Failed to rename folder %s to %s: %s', $in{'src_folder'}, $in{'dest_folder'}, $self->{'imap_handler'}->LastError);
	return undef;
    }

    return 1;
}


## Migrate folder content to another IMAP server
sub migrate_folder {
    my $self = shift;
    my %in = @_;
    
    foreach my $param ('src_folder','dest_folder','dest_server') {
	unless (defined $in{$param}) {
	    &do_log('error', "Missing parameters '%s' to connect to IMAP server", $param);
	    return undef;
	}
    }

    unless ($self->{'imap_handler'}->select($in{'src_folder'})) {
	&do_log('error', 'Failed to select folder %s: %s', $in{'src_folder'}, $self->{'imap_handler'}->LastError);
	return undef;
    }

    my @messages;
    unless (@messages = $self->{'imap_handler'}->search('ALL')) {
	&do_log('error', 'Failed to search in folder %s: %s', $in{'src_folder'}, $self->{'imap_handler'}->LastError);
	return undef;
    }

    printf "Migrating %d messages...\n", $#messages+1;
    
    unless ($in{'dest_server'}->create_folder($in{'dest_folder'})) {
	&do_log('error', 'Failed to create folder %s on server %s: %s', $in{'dest_folder'}, $in{'dest_server'}, $self->{'imap_handler'}->LastError);
	return undef;
    }
    
    unless ($self->{'imap_handler'}->migrate($in{'dest_server'}->{'imap_handler'}, \@messages, $in{'dest_folder'})) {
	&do_log('error', 'Failed to migrate from folder %s to server %s, folder %s: %s', $in{'src_folder'}, $in{'dest_server'}, $in{'dest_folder'}, $self->{'imap_handler'}->LastError);
	return undef;
    }
    
    return $#messages+1;
}

## Logout from server
sub logout {
    my $self = shift;
    
    $self->{'imap_handler'}->logout;
}




1;