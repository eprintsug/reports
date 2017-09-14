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

	$plugin->get_export_fields( %opts ); #get export fields based on user requirements or plugin defaults

	my $ds = $opts{dataset};
	$plugin->{dataset} = $ds;	

	#print header row
	print join( ",", map { my $field = EPrints::Utils::field_from_config_string( $ds, $_ ); $plugin->escape_value( EPrints::Utils::tree_to_utf8( $field->render_name ) ) } @{$opts{exportfields}} ) . "\n";

	#print values
	$opts{list}->map( sub {
               	my( undef, undef, $dataobj ) = @_;
                my $output = $plugin->output_dataobj( $dataobj, $plugin->get_related_objects( $dataobj ) );
       	        return unless( defined $output );
               	print "$output\n";
        } );
}

# Exports a single object / row
# TODO Note quite a lot of replication between this and Screen::Report::validate_dataobj
sub output_dataobj
{
	my( $plugin, $dataobj, $objects ) = @_;
	my $repo = $plugin->repository;

	my @row;

	if( defined $plugin->{custom_fields} ) #the screen has defined export fields
	{
		for( @{ $plugin->{exportfields} } )
	        {
                	if( exists $repo->config( $plugin->{report}->{export_conf}, "custom_export" )->{$_} )
	                {
				my $value = $repo->config( $plugin->{report}->{export_conf}, "custom_export" )->{$_}->( $dataobj, $plugin->{report} );
                                if( EPrints::Utils::is_set( $value ) )
                                {
					push @row, $plugin->escape_value( $value );
				}
                	}
	                else
        	        {
				my @fnames = split( /\./, $_ );
				if( scalar( @fnames > 1 ) ) #a field of another dataset, e.g. documents.content
				{
					my $field = $plugin->{dataset}->get_field( $fnames[0] ); #first get the field
					if( $field->is_type( "subobject", "itemref" ) ) #if thee field belongs to another dataset
					{	
						my @values;
						my @dataobjs;
						my $datasetid = $field->get_property( "datasetid" );
						if( $datasetid eq "document" ) #documents represent a special case of sub object - we don't want volatile documents (probably)
						{
							@dataobjs = $dataobj->get_all_documents;
						}
						else
						{
							@dataobjs = @{$dataobj->value( $fnames[0] )};
						}
						foreach my $obj ( @dataobjs ) #get the values we are requesting of the dataobjects
						{
							push @values, $plugin->escape_value( EPrints::Utils::tree_to_utf8( $obj->render_value( $fnames[1] ) ) );
						} 
						push @row, join( ";", @values );
					}	
					else	
					{
						push @row, "Unrecognised field definition.";
					}
				}
				else
				{
		       	      		push @row, $plugin->escape_value( EPrints::Utils::tree_to_utf8( $dataobj->render_value( $_ ) ) );
				}
	                }
        	}

	}
	else	#use the conventional generic reporting framework approach
	{	
		# related objects and their datasets
	        my $valid_ds = {};
        	foreach my $dsid ( keys %$objects )
	        {	
			$valid_ds->{$dsid} = $repo->dataset( $dsid );
        	}

		my $report_fields = $plugin->report_fields();

		# don't print out empty row so check that something's been done:
		my $done_any = 0;

		foreach my $field ( @{ $plugin->report_fields_order() } )
		{
			my $ep_field = $report_fields->{$field};
			if( ref( $ep_field ) eq 'CODE' )
			{
				# a sub{} we need to run
				eval {
					my $value = &$ep_field( $plugin, $objects );
					if( EPrints::Utils::is_set( $value ) )
					{
						push @row, $plugin->escape_value( $value );
						$done_any++ 
					}
					else
					{
						push @row, "";
					}
				};
				if( $@ )
				{
					$repo->log( "Report::CSV Runtime error: $@" );
				}
				next;
			}
			elsif( $ep_field !~ /^([a-z_]+)\.([a-z_]+)$/ )
			{
				# wrong format :-/
				push @row, "";
				next;
			}
			# a straight mapping with an EPrints field
			my( $ds_id, $ep_fieldname ) = ( $1, $2 );
			my $ds = $valid_ds->{$ds_id};

			unless( defined $ds && $ds->has_field( $ep_fieldname ) )
			{
				# dataset or field doesn't exist
				push @row, "";
				next;
			}

			my $value = $objects->{$ds_id}->value( $ep_fieldname );
			$done_any++ if( EPrints::Utils::is_set( $value ) );
			push @row, $plugin->escape_value( $value );
		}
		return undef unless( $done_any );
	}
	
	return join( ",", @row );
}

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
