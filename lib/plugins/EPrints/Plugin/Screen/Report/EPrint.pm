package EPrints::Plugin::Screen::Report::EPrint;

use EPrints::Plugin::Screen::Report;
our @ISA = ( 'EPrints::Plugin::Screen::Report' );

use HefceOA::Const;
use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{datasetid} = 'eprint';
	$self->{searchdatasetid} = 'archive';
	$self->{custom_order} = '-title/creators_name';
	$self->{appears} = [];
	$self->{report} = 'eprint_report';
	$self->{sconf} = 'eprint_report';
	$self->{export_conf} = 'eprint_report';
	$self->{sort_conf} = 'eprint_report';
        $self->{group_conf} = 'eprint_report';
	
	$self->{disable} = 0;

	$self->{labels} = {
                outputs => "Records"
        };

        $self->{show_compliance} = 0;


	return $self;
}

sub ajax_eprint
{
        my( $self ) = @_;

        my $repo = $self->repository;

        my $json = { data => [] };

        $repo->dataset( "eprint" )
        ->list( [$repo->param( "eprint" )] )
        ->map(sub {
                (undef, undef, my $eprint) = @_;

                return if !defined $eprint; # odd

                my $frag = $eprint->render_citation_link;
                push @{$json->{data}}, {
                        datasetid => $eprint->dataset->base_id,
                        dataobjid => $eprint->id,
                        summary => EPrints::XML::to_string( $frag ),
#                       grouping => sprintf( "%s", $user->value( SOME_FIELD ) ),
                        problems => [ $self->validate_dataobj( $eprint ) ],
                        bullets => [ $self->bullet_points( $eprint ) ],
                };
        });
        print $self->to_json( $json );
}
                       
sub validate_dataobj
{
        my( $self, $eprint ) = @_;

        my $repo = $self->{repository};

        my @problems;

        return @problems;
}

sub bullet_points
{
        my( $self, $eprint ) = @_;

        my $repo = $self->{repository};

        my @bullets;

        return @bullets;
}

1;
