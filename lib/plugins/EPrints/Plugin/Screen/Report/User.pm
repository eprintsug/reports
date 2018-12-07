package EPrints::Plugin::Screen::Report::User;

use EPrints::Plugin::Screen::Report;
our @ISA = ( 'EPrints::Plugin::Screen::Report' );

use HefceOA::Const;
use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{datasetid} = 'user';
	$self->{searchdatasetid} = 'user';
	$self->{appears} = [];
	$self->{report} = 'user_report';
	$self->{sconf} = 'user_report';
	$self->{export_conf} = 'user_report';
	$self->{sort_conf} = 'user_report';
        $self->{group_conf} = 'user_report';
	
	$self->{disable} = 0;

	$self->{labels} = {
                outputs => "Users"
        };

        $self->{show_compliance} = 0;


	return $self;
}

sub ajax_user
{
        my( $self ) = @_;

        my $repo = $self->repository;

        my $json = { data => [] };

        $repo->dataset( "user" )
        ->list( [$repo->param( "user" )] )
        ->map(sub {
                (undef, undef, my $user) = @_;

                return if !defined $user; # odd

                my $frag = $user->render_citation_link;
                push @{$json->{data}}, {
                        datasetid => $user->dataset->base_id,
                        dataobjid => $user->id,
                        summary => EPrints::XML::to_string( $frag ),
#                       grouping => sprintf( "%s", $user->value( SOME_FIELD ) ),
                        problems => [ $self->validate_dataobj( $user ) ],
                        bullets => [ $self->bullet_points( $user ) ],
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
