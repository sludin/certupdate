use strict;
use warnings;
use File::Basename;
use File::Path qw( make_path );
use File::Copy qw( cp );

my $filename = shift || die "usage: chrootcp filename [target_dir]\n";
my $target_dir = shift || '.';

my $ldd = `ldd $filename`;

copy_system_file( $filename, $target_dir );

for my $line ( split( /\n/, $ldd ) ) {
		if ( $line =~ m#(/\S+)\s# ) {
				my $source = $1;
				copy_system_file( $source, $target_dir )
		}
}

sub copy_system_file {
		my $source = shift;
		my $target_dir = shift;
		my $dest = $target_dir . '/' . substr( $source, 1 );
		copy_and_create_dir( $source, $dest );
}

sub copy_and_create_dir {
		my $source = shift;
		my $dest = shift;

		my $directory = dirname( $dest );

		if ( ! -d $directory ) {
				print "Creating directory: $directory\n";
				make_path( $directory );
		}
		
		if ( ! -f $dest ) {
				print "Copying $source => $dest\n";
				cp( $source, $dest) || die "Copy failed: $!\n"
		}
		
}


__END__

- 	linux-vdso.so.1 (0x00007ffdc7fc2000)
- 	libselinux.so.1 => /lib/x86_64-linux-gnu/libselinux.so.1 (0x00007ff460110000)
- 	libacl.so.1 => /lib/x86_64-linux-gnu/libacl.so.1 (0x00007ff45ff08000)
- 	libattr.so.1 => /lib/x86_64-linux-gnu/libattr.so.1 (0x00007ff45fd03000)
- 	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007ff45f912000)
- 	libpcre.so.3 => /lib/x86_64-linux-gnu/libpcre.so.3 (0x00007ff45f6a1000)
- 	libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007ff45f49d000)
- 	/lib64/ld-linux-x86-64.so.2 (0x00007ff46055b000)
- 	libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007ff45f27e000)
