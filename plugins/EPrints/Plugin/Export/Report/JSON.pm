package EPrints::Plugin::Export::Report::JSON;

use EPrints::Plugin::Export::Report;
@ISA = ( "EPrints::Plugin::Export::Report" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "JSON";
	$self->{suffix} = ".js";
	$self->{mimetype} = "application/json; charset=utf-8";
	$self->{accept} = [ 'report/generic' ];
	$self->{advertise} = 1;

	return $self;
}

sub _header
{
        my( $self, %opts ) = @_;

        my $jsonp = $opts{json} || $opts{jsonp} || $opts{callback};
        if( EPrints::Utils::is_set( $jsonp ) )
        {
                $jsonp =~ s/[^=A-Za-z0-9_]//g;
                return "$jsonp(";
        }

        return "";
}

sub _footer
{
        my( $self, %opts ) = @_;

        my $jsonp = $opts{json} || $opts{jsonp} || $opts{callback};
        if( EPrints::Utils::is_set( $jsonp ) )
        {
                return ");\n";
        }
        return "";
}

sub output_list
{
        my( $plugin, %opts ) = @_;     

	$plugin->get_export_fields( %opts ); #get export fields based on user requirements or plugin defaults
	
	my $ds = $opts{dataset};
        $plugin->{dataset} = $ds;
	
	my $r = [];
        my $part;
        $part = $plugin->_header(%opts)."[\n";
        if( defined $opts{fh} )
        {
                print {$opts{fh}} $part;
        }
        else
        {
                push @{$r}, $part;
        }

        $opts{json_indent} = 1;
        my $first = 1;
        $opts{list}->map( sub {
                my( $session, $dataset, $dataobj ) = @_;
                my $part = "";
                if( $first ) { $first = 0; } else { $part = ",\n"; }
                $part .= $plugin->_epdata_to_json( $dataobj, 1, 0, %opts );
                if( defined $opts{fh} )
                {
                        print {$opts{fh}} $part;
                }
                else
                {
                        push @{$r}, $part;
                }
        } );

        $part= "\n]\n\n".$plugin->_footer(%opts);
        if( defined $opts{fh} )
        {
                print {$opts{fh}} $part;
        }
        else
        {
                push @{$r}, $part;
        }


        if( defined $opts{fh} )
        {
                return;
        }

        return join( '', @{$r} );
}

sub _epdata_to_json
{
        my( $self, $epdata, $depth, $in_hash, %opts ) = @_;

	my $repo = $self->repository;

        my $pad = "  " x $depth;
        my $pre_pad = $in_hash ? "" : $pad;


        if( !ref( $epdata ) )
        {

                if( !defined $epdata )
                {
                        return "null"; # part of a compound field
                }

                if( $epdata =~ /^-?[0-9]*\.?[0-9]+(?:e[-+]?[0-9]+)?$/i )
                {
                        return $pre_pad . ($epdata + 0);
                }
                else
                {
                        return $pre_pad . EPrints::Utils::js_string( $epdata );
                }
        }
        elsif( ref( $epdata ) eq "ARRAY" )
        {
                return "$pre_pad\[\n" . join(",\n", grep { length $_ } map {
                        $self->_epdata_to_json( $_, $depth + 1, 0, %opts )
                } @$epdata ) . "\n$pad\]";
        }
        elsif( ref( $epdata ) eq "HASH" )
        {
                return "$pre_pad\{\n" . join(",\n", map {
                        $pad . "  \"" . $_ . "\": " . $self->_epdata_to_json( $epdata->{$_}, $depth + 1, 1, %opts )
                } keys %$epdata) . "\n$pad\}";
        }
        elsif( $epdata->isa( "EPrints::DataObj" ) )
        {
                my $subdata = {};

                return "" if(
                        $opts{hide_volatile} &&
                        $epdata->isa( "EPrints::DataObj::Document" ) &&
                        $epdata->has_relation( undef, "isVolatileVersionOf" )
                  );

                foreach my $fieldname ( @{$self->{exportfields}} )
                {
                    my @fnames = split( /\./, $fieldname );
                    if( scalar( @fnames > 1 ) ) #a field of another dataset, e.g. documents.content
                    {
				        my $field = $self->{dataset}->get_field( $fnames[0] ); #first get the field
                        if( $field->is_type( "subobject", "itemref" ) ) #if thee field belongs to another dataset
                        {
					        my $subsubdata = $subdata->{$fnames[0]} || []; #create an array for the sub ojects
                            my $dataobjs= $epdata->value( $fnames[0] ); #get the dataobjects this field represents
					        for (my $i=0; $i < scalar( @{$dataobjs} ); $i++)
					        {
						        my $obj = @{$dataobjs}[$i]; #get the value from the dataobject			
						        my $value = $obj->value( $fnames[1] );
						        next if !EPrints::Utils::is_set( $value );

						        my $subsubsubdata = $subdata->{$fnames[0]}[$i] || {};
						        $subsubsubdata->{$fnames[1]} = $value;		

						        $subdata->{$fnames[0]}[$i] = $subsubsubdata;					
                            }                                   
                        }
			        }
			        else
			        {
                        if( defined $repo->config( $self->{report}->{export_conf}, "custom_export" ) &&
					        exists $repo->config( $self->{report}->{export_conf}, "custom_export" )->{$fieldname} )
        	            {
					        my $value = $repo->config( $self->{report}->{export_conf}, "custom_export" )->{$fieldname}->( $epdata, $self->{report} );
	       	                $subdata->{$fieldname} = $value;		        
                        }
                        else
                        {
				            my $field = $self->{dataset}->get_field( $fieldname );
	                        next if !$field->get_property( "export_as_xml" );
        	                next if defined $field->{sub_name};
				            my $value = $field->get_value( $epdata );
				        	if( defined $field->{virtual} )
				            {
					            $value = EPrints::Utils::tree_to_utf8( $epdata->render_value( $field->get_name ) );
				            }
		                    next if !EPrints::Utils::is_set( $value );
        	                $subdata->{$field->get_name} = $value;
                        }
			        }
                }
                $subdata->{uri} = $epdata->uri;

                return $self->_epdata_to_json( $subdata, $depth + 1, 0, %opts );
        }
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
