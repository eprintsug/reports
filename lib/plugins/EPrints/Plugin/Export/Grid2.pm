=head1 NAME

EPrints::Plugin::Export::Grid2

=cut

package EPrints::Plugin::Export::Grid2;

use Data::Dumper;
use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export::Grid" );

use strict;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
    my( $class, %opts ) = @_;

    my $self = $class->SUPER::new( %opts );

    $self->{name} = "Grid 2 (abstract)";
    $self->{accept} = [ 'dataobj/*', 'list/*', ];
    $self->{visible} = "none";  
    $self->{advertise} = 0; 
    return $self;
}

sub fields
{
    my( $self, $dataset ) = @_;

    # skip compound, subobjects
    # return grep { !$_->is_virtual } $dataset->fields;
    
    my @fieldnames;
    foreach my $f ( $dataset->fields )
    {
        if( !$f->is_virtual )
        {
            push @fieldnames, $f->name;
        }
    }
    return \@fieldnames;
}

sub header_row
{
    my( $self, %opts ) = @_;

    my $fields = $opts{fields} ||= [$self->fields($opts{list}->{dataset})];
    my $ds = $opts{list}->{dataset};

    my @names;

    # option to not use phrases and just use field names
    my $use_ids = $opts{plugin}->{use_ids} ||= 0;
    if( $use_ids )
    {
        foreach my $f (@$fields)
        {            
            if( defined $opts{custom_export} && defined $opts{custom_export}->{$f} )
            {
                push @names, $f;
            }
            else
            {
                my $field = EPrints::Utils::field_from_config_string( $ds, $f );
                if( $field->isa( "EPrints::MetaField::Multipart" ) )
                {
                    my $name = $field->name;
                    push @names, map {
                        $name . '.' . $_->{sub_name}
                    } @{$field->property("fields_cache")};
                }
                else
                {
                    push @names, $field->name;
                }
            }
        }
        return @names;
    }

    # else we use phrases
    foreach my $f (@$fields)
    {
        if( defined $opts{custom_export} && defined $opts{custom_export}->{$f} )
        {
            push @names, $ds->repository->phrase( "exportfieldoptions:$f" );
        }
        else
        {
            my $field = EPrints::Utils::field_from_config_string( $ds, $f );

            if ($field->isa("EPrints::MetaField::Multipart"))
            {
                my $parent_name = $field->display_name( $field->repository );
                if( $field->isa( "EPrints::MetaField::Name" )) # need to deal with legacy phrase id's
                {
                    foreach my $bit ( $field->get_input_bits() )
                    {
                        $bit = "given_names" if( $bit eq "given" );
                                                $bit = "family_names" if( $bit eq "family" );
                        my $custom_phrase = $field->name . "_" . $bit;
                        if( $ds->repository->get_lang->has_phrase( $custom_phrase ) ) # allow a custom phrase to be used
                        {
                            push @names, $ds->repository->phrase( $custom_phrase );
                        }
                        else
                        {
                            push @names, $parent_name . ": " . $ds->repository->phrase( "lib/metafield:".$bit );
                        }
                    }
                }
                else
                {
                    my $name = $field->name;
                    push @names, map {
                        $name . '.' . $_->{sub_name}
                    } @{$field->property("fields_cache")};
                }
            }
            elsif( $field->isa("EPrints::MetaField::Compound" ) )
            {
                foreach my $sub_field (@{$field->property("fields_cache")})
                {
                    my $custom_phrase = $field->name . "_" . $sub_field->name;
                    if( $ds->repository->get_lang->has_phrase( $custom_phrase ) ) # allow a custom phrase to be used
                    {
                      push @names, $ds->repository->phrase( $custom_phrase );
                    }
                    else
                    {
                        push @names, $field->display_name( $field->repository ) . ": " . $sub_field->display_name( $sub_field->repository );
                    }
                }
            }
            else
            {
                push @names, $field->display_name( $field->repository );
            }
        }
    }       
    return @names;
}

sub dataobj_to_rows
{
    my( $self, $dataobj, %opts ) = @_;

    my $main_dataobj = $dataobj; # store dataobj for future reference

    my $fields = $opts{fields} || [$self->fields($dataobj->{dataset})];
    my $ds = $opts{list}->{dataset};

    my @rows = ([]);
    foreach my $fname (@$fields)
    {
        #reset dataobj to main dataobj
        $dataobj = $main_dataobj;

        # get the field from the id
        my $field;
        my @fnames = split( /\./, $fname );
        my $sub_dataobj_values = [];        
        if( scalar( @fnames > 1 ) ) # a field of another dataset, e.g. documents.content
                {
            $field = $ds->get_field( $fnames[0] ); # first get the field
            if( $field->is_type( "subobject", "itemref" ) ) # if the field belongs to another dataset
            {
                my $sub_ds_id = $field->get_property( "datasetid" );
                my $multiple = $field->get_property( "multiple" );
                if( $multiple )
                {
                    my @sub_dataobjs;
                    # get the dataobjs of this field
                    if( $sub_ds_id eq "document" ) # documents represent a special case of sub object - we don't want volatile documents (probably)
                    {
                        @sub_dataobjs = $dataobj->get_all_documents;
                    }
                    else
                    {
                        foreach my $sub_obj ( @{$dataobj->value( $fnames[0] )} )
                        {
                            push @sub_dataobjs, $field->get_item( $dataobj->repository, $sub_obj );
                        }
                    }
                    
                    # and build up an array of these sub dataobj's values
                    foreach my $obj ( @sub_dataobjs ) # get the values we are requesting of the dataobjects
                    {
                        # check for a custom renderer
                        my $value;
                        if( defined $opts{custom_export} && defined $opts{custom_export}->{$fname} )
                        {
                            $value = $opts{custom_export}->{$fname}->( $obj, $opts{plugin} );
                        }
                        else
                        {                           
                            $field = EPrints::Utils::field_from_config_string( $obj->dataset, $fnames[1] );                         
                            if( $field->get_property( "virtual" ) ) # virtual fields need rendering
                            {
                                $value = EPrints::Utils::tree_to_utf8( $obj->render_value( $fnames[1] ) );
                            }
                            else # regular field values can simply be retrieved
                            {
                                $value = $field->get_value( $obj );
                            }
                        }
                        push @{$sub_dataobj_values}, $value; 
                    }
                }
                else # we only have one sub-object, 
                {
                    my $sub_obj;
                    if( ref( $field ) eq "EPrints::MetaField::Subobject" )
                    {
                        $sub_obj = $dataobj->value( $fnames[0] );
                    }
                    else # do it the original way (assuming this ever worked...?
                    {
                        $sub_obj = $field->get_item( $dataobj->repository, $dataobj->value( $fnames[0] ) ); # get the subobject
                    }
                     
                    $field = EPrints::Utils::field_from_config_string( $sub_obj->dataset, $fnames[1] ); # get the subobjects field
                    my $value = $field->get_value( $sub_obj ); # get the subobjects value for this field
                    push @{$sub_dataobj_values}, $value;
                }
            }
        }

        my $i = @{$rows[0]};
        my $_rows;
        if( EPrints::Utils::is_set( $field ) ) # we already have our values
        {
            if( scalar @{$sub_dataobj_values} > 0 )
            {
                $_rows = $self->value_to_rows($field, $sub_dataobj_values, $dataobj);           
            }
            else # there's no results, but we still need to add an empty cell to the spreadsheet
            {
                $_rows = $self->value_to_rows($field, undef);
            }
        }
        else # we need to retrieve our values for this field from our dataobj (or sub_dataobj)
        {
            my $value;
            if( defined $opts{custom_export} && defined $opts{custom_export}->{$fname} ) # we have a custom exporter
            {
                $value = $opts{custom_export}->{$fname}->( $dataobj, $opts{plugin} );
                $_rows = $self->custom_value_to_rows( $value );
            }
            else # just get the field's usual value
            {
                $field = EPrints::Utils::field_from_config_string( $ds, $fname );
                if( $field->get_property( "virtual" ) ) # virtual fields need rendering
                {
                    $value = EPrints::Utils::tree_to_utf8( $dataobj->render_value( $fname ) );
                }
                else # regular field values can simply be retrieved
                {
                    $value = $field->get_value( $dataobj );
                }
                $_rows = $self->value_to_rows($field, $value, $dataobj);        
            }           
        }

        foreach my $j (0..$#$_rows)
        {
            foreach my $_i (0..$#{$_rows->[$j]})
            {
                $rows[$j][$i+$_i] = $_rows->[$j][$_i];
            }
        }
    }

    # generate complete rows
    if($opts{plugin}->param( "multiline_repeat" )) # we want each column to repeat for each row
    {
        foreach my $i (0..(scalar @rows)-1)
        {
            foreach my $j (0..$#{$rows[0]})
            {
                $rows[$i][$j] ||= $rows[0][$j];
            }   
        }
    }
    else # we don't want repeating values in the columns
    {   
        for(@rows) {
            $_->[0] = $rows[0][0]; # first element of this array equals the first element of the first row
            $_->[$#{$rows[0]}] ||= undef;
        }

    }

    return \@rows;
}

sub value_to_rows
{
    my ($self, $field, $value, $dataobj) = @_;

    my @rows;

    if (ref($value) eq "ARRAY")
    {
        $value = [$field->empty_value] if !@$value;
        @rows = map { $self->value_to_rows($field, $_, $dataobj)->[0] } @$value;
    }
    elsif ($field->isa("EPrints::MetaField::Multipart"))
    {
        if( $field->isa( "EPrints::MetaField::Name" )) # need to deal with legacy phrase id's
        {
            my @bit_values;
            foreach my $bit ( $field->get_input_bits() )
            {
                push @bit_values, $value->{$bit};
            }   
            push @rows, \@bit_values;
        }
        else
        {
            push @rows, [map { $value->{$_->{sub_name}} } @{$field->property("fields_cache")}];
        }
    }
    elsif ($field->isa("EPrints::MetaField::Compound"))
    {
        my @sub_values;
        foreach my $key (keys %{$value})
        {
            push @sub_values, $value->{$key};
        }
        push @rows, \@sub_values;
    }
    elsif( $field->isa("EPrints::MetaField::Subject"))
    {
        if( $value ne "" )
        {
            push @rows, [EPrints::Utils::tree_to_utf8( $field->render_single_value( $field->repository, $value ) )];
        }
        else
        {
            push @rows, [$value];
        }
    }
    elsif( !$field->isa("EPrints::MetaField::Subobject") && $field->is_virtual )
    {
        #push @rows, [$dataobj->render_value( $field->name )];
        push @rows, [$value];
    }
    else
    {
        push @rows, [$value];
    }

    return \@rows;
}

# used for custom exports that might return a field or an array (but aren't necesarily associated with a field!)
sub custom_value_to_rows
{
    my ($self, $value) = @_;

    my @rows;

    if (ref($value) eq "ARRAY")
    {
        @rows = map { $self->custom_value_to_rows($_)->[0] } @$value;
    }
    else
    {
        push @rows, [$value];
    }

    return \@rows;
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

