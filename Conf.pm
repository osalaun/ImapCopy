## Configuration file for imap_copy.pl

# IMAP config
our %imap_config = (
		    my_imap_src => {
				use_ssl => 1,
				server => 'my.imap.org',
				port => 993,
				user => 'src_user_name',
				password => 'src_user_pwd',
		    },
		   },
		   my_imap_dest => {
				use_ssl => 1,
				server => 'imap.googlemail.com',
				port => 993,
				user => 'dest_user_name@gmail.com',
				password => 'dest_user_pwd',
		   },
		  );

our %migrate_map = (
          'Folder1/Sub2'=>'Folder2/Sub3',
          'Folder3'=>'Folder4',
);

1;