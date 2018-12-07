package EPrints::Plugin::Export::Report::HTML;

use EPrints::Plugin::Export::Report;
@ISA = ( "EPrints::Plugin::Export::Report" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "HTML Report";
	$self->{suffix} = ".html";
	$self->{mimetype} = "text/html; charset=utf-8";
	$self->{accept} = [ 'report/generic' ];
	$self->{advertise} = 1;
	$self->{grouped} = 1;

	return $self;
}

sub initialise_fh
{
        my( $plugin, $fh ) = @_;

        binmode($fh, ":utf8");
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

	#generate the title
	my $title_frag = $repo->make_doc_fragment;
	if( defined $plugin->param( "title_phrase" ) )
	{
		$title_frag->appendChild( $repo->html_phrase( $plugin->param( "title_phrase" ) ) );
	}
	else
	{
		$title_frag->appendChild( $repo->html_phrase( "report_html_export_title" ) );
	}

	#generate the body
	my @records;
	my $body_frag = $repo->make_doc_fragment;

	#print button
	$body_frag->appendChild( $repo->html_phrase( "report_html_print_btn" ) );
	if( ref( $opts{list} ) eq "EPrints::List" )
	{
		my $section_items_div = $repo->make_element( "div", class=>"report_html_section_items" );
		$opts{list}->map( sub {
                	my( $session, $dataset, $item ) = @_;
			$plugin->output_dataobj( $repo, $item, $section_items_div, %opts );
			$body_frag->appendChild( $section_items_div );
		});
	}
	elsif( ref( $opts{list} ) eq "ARRAY" )
	{
		my $grouped = $opts{list};		
		foreach my $group (@{$grouped})
		{
			my $section_div = $repo->make_element( "div", class=>"report_html_section" );
	
			#section header
			my $header = $repo->make_element( "h2", class=>"report_html_section_header" );
			$header->appendChild( $repo->make_text( $group->{label} ) );
			$section_div->appendChild( $header );

			#section items
			my $section_items_div = $repo->make_element( "div", class=>"report_html_section_items" );
			my @items = @{$group->{list}};
			foreach my $item( @items )
			{
				$plugin->output_dataobj( $repo, $item, $section_items_div, %opts );
			}
			$section_div->appendChild( $section_items_div );

			$body_frag->appendChild( $section_div );

			#add custom class if necessary for further CSS customisation 
			if( defined $plugin->param( "custom_class" ) )
			{
				$section_div->setAttribute( class => $section_div->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
				$header->setAttribute( class => $header->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
				$section_items_div->setAttribute( class => $section_items_div->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
			}
		}
	}

	#generate the template
	my %page_opts;
	if( defined $plugin->param( "template" ) )
	{
		$page_opts{template} = $plugin->param( "template" );
	}
	my $page = $repo->xhtml->page( { title => $title_frag, page => $body_frag }, %page_opts );
	print {$opts{fh}} $repo->xhtml->doc_type . $page->{page};
	
	return undef;
}

sub output_dataobj
{
        my( $plugin, $repo, $dataobj, $section_items, %opts ) = @_;

	my $dataobj_div = $repo->make_element( "div", class=>"report_html_dataobj" );

	#get the citation
        my $xml = $plugin->xml_dataobj( $dataobj );
	my $citation_div = $repo->make_element( "div", class=>"report_html_citation" );
	$citation_div->appendChild( $xml );
	$dataobj_div->appendChild( $citation_div );

	#now add the fields
	my $table = $repo->make_element( "table",
		class=>"ep_block report_html_details", style=>"margin-bottom: 1em",
        	border=>"0",
                cellpadding=>"3"
	);
	foreach my $f( @{$opts{fields}} )
	{
		if( defined $opts{custom_export} && defined $opts{custom_export}->{$f} )                                              
		{
			my $value = $opts{custom_export}->{$f}->( $dataobj, $opts{plugin} );
			$table->appendChild( $repo->render_row(
                                $repo->html_phrase( "exportfieldoptions:$f" ),
                                $repo->make_text( $value )
                        ) );
		}
		else #render normal value like a normal field
		{
			my $ds_id = $dataobj->get_dataset_id;
			my $ds = $repo->dataset( $ds_id );
			if( $ds->has_field( $f ) )
			{
				$table->appendChild( $repo->render_row(
        	        		$repo->html_phrase( $ds_id."_fieldname_".$f ),
		                	$dataobj->render_value( $f ) 
				) );
			}
		}
	}
	$dataobj_div->appendChild( $table );

	#add the dataobj div to the section
	$section_items->appendChild( $dataobj_div );

	#add custom class if necessary for further CSS customisation 
	if( defined $plugin->param( "custom_class" ) )
	{
		$dataobj_div->setAttribute( class => $dataobj_div->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
		$citation_div->setAttribute( class => $citation_div->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
		$table->setAttribute( class => $table->getAttribute( "class" ) . " " . $plugin->param( "custom_class" ) );
	}
}

sub xml_dataobj
{
        my( $plugin, $dataobj ) = @_;

        my $p = $plugin->{session}->make_element( "p", class=>"citation" );

        $p->appendChild( $dataobj->render_citation_link );

        return $p;
}

1;        
