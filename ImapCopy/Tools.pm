package ImapCopy::Tools;
our @ISA = qw(Exporter);
our @EXPORT = qw(do_log);

sub do_log {
    my $level =shift;
    my $message = shift;
    
    printf STDERR $message."\n", @_;
    
    return 1;
}

1;