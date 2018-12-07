package EPrints::Plugin::Export::Report::CSV;

use EPrints::Plugin::Export::Report;
@ISA = ( "EPrints::Plugin::Export::Report" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Generic CSV";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/plain; charset=utf-8";
	$self->{accept} = [ 'report/generic' ];
	$self->{advertise} = 1;

	return $self;
}

sub output_list
{
        my( $plugin, %opts ) = @_;     

	my $repo = $plugin->repository;

	$plugin->get_export_fields( %opts ); #get export fields based on user requirements or plugin defaults

	if( defined $plugin->{custom_fields} ) #the screen has defined export fields
	{
		$opts{fields} = $plugin->{exportfields};
	}

	#set any custom export functions
	$opts{custom_export} = $repo->config( $plugin->{report}->{export_conf}, "custom_export" );

	#now use the generic multiline csv plugin to handle the export
	my $multiline_csv = EPrints::Plugin::Export::MultilineCSV2->new( %opts );
	$multiline_csv->output_list( %opts ); 
}

#retained for legacy reasons - extensions of Export::Report::CSV may use this
sub escape_value
{
        my( $plugin, $value ) = @_;

        return '""' unless( defined EPrints::Utils::is_set( $value ) );

        # strips any kind of double-quotes:
        $value =~ s/\x93|\x94|"/'/g;
        # and control-characters
        $value =~ s/\n|\r|\t//g;
        
	# if value is a pure number, then add ="$value" so that Excel stops the auto-formatting (it'd turn 123456 into 1.23e+6)
	if( $value =~ /^[0-9\-]+$/ )
        {
		return "=\"$value\"";
        }
        
        # only escapes row with spaces and commas
        if( $value =~ /,| / )
        {
        	return "\"$value\"";
	}
       	
	return $value;
}

1;        
