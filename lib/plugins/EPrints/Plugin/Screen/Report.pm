package EPrints::Plugin::Screen::Report;

# Abstract class that handles the Report tools

use JSON qw(encode_json);
use EPrints::Plugin::Screen;
@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	push @{$self->{actions}}, qw( export search newsearch update );

	$self->{sconf} = "report";

        $self->{appears} = [
                {
                        place => "key_tools",
                        position => 1000,
                },
        ];

	return $self;
}

sub get_report { shift->{report} }

sub can_be_viewed
{
        my( $self ) = @_;

	return 1 if( $self->{public} ); #allow a report to be publicly available

	return 0 if( !defined $self->{repository}->current_user );
	
	return $self->allow( 'report' );
}

sub allow_export { shift->can_be_viewed }
sub action_export {}

sub wishes_to_export {
	$_[0]->repository->param( 'export' ) ||
	$_[0]->repository->param( 'ajax' );
}

sub export_mimetype
{
	my( $self ) = @_;

	my $plugin = $self->{processor}->{plugin};
	if( !defined $plugin )
	{
		if( $self->repository->param( "ajax" ) )
		{
			return "application/json; charset=utf-8";
		}
	
		return "text/html; charset=utf-8";
	}

	return $plugin->param( "mimetype" );
}

sub export
{
	my( $self ) = @_;

	my $part = $self->repository->param( "ajax" );
	my $f = "ajax_$part";

	if( $self->can( $f ) )
	{
		binmode(STDOUT, ":utf8");
		return $self->$f;
	}

	my $plugin = $self->{processor}->{plugin};
	return $self->SUPER::export if !defined $plugin;

	my $items = $self->items;
	if( $plugin->{grouped} && defined $self->{processor}->{group} ) #some export plugins can accept groupings
	{
		$items = $self->get_grouped_items( $items, 0 );
	}

	$plugin->initialise_fh( \*STDOUT );
	$plugin->output_list(
		list => $items,
		fh => \*STDOUT,
		exportfields => $self->{processor}->{exportfields},
		dataset => $self->{processor}->{dataset},
		plugin => $self,
	);
}

sub allow_search { return 1; }

#generates search config
sub _create_search
{
	my( $self ) = @_;

	my $session = $self->{session};
        my $report_plugin = $self->{processor}->screen;

	# Do not create a search config if this is not configured in the report
  	return if ! defined $report_plugin->{searchdatasetid};
	$self->{processor}->{report_plugin} = $report_plugin;

        my $searchdatasetid = $report_plugin->{searchdatasetid};
        if( defined $report_plugin->param("searchdatasetid") )
        {
            $searchdatasetid = $report_plugin->param("searchdatasetid");
        }

        my $report_ds = $session->dataset( $searchdatasetid );
        if( defined $report_ds )
        {
                $self->{processor}->{datasetid} = $report_ds->base_id;
                my $sconf = $report_ds->search_config( $report_plugin->{sconf} );
	
                my $format = "report/" . $report_ds->base_id;
                $self->{processor}->{search} = $session->plugin( "Search" )->plugins(
                        {
                                keep_cache => 1,
                                session => $self->{session},
                                dataset => $report_ds,
                                %{$sconf}
                        },
                        type => "Search",
                        can_search => $format,
                );
	}
}

sub allow_newsearch { return 1; }

sub allow_update { return 1; }

sub action_newsearch
{
        my( $self ) = @_;

        my $session = $self->{session};

        #$self->{processor}->{report} = $session->param( 'report' );
        #$self->{processor}->{screenid} = $self->{processor}->{report};
        #$self->{processor}->{action} = "newsearch";
        #$self->_create_search;
}

sub action_update
{
        my( $self ) = @_;

        my $session = $self->{session};

        #$self->{processor}->{report} = $session->param( 'report' );
        #$self->{processor}->{screenid} = $self->{processor}->{report};
        #$self->{processor}->{action} = "newsearch";
        #$self->_create_search;
}

sub action_search
{
	my( $self ) = @_;

	$self->{processor}->{action} = "search";

	#read parameters
	my $session = $self->{session};

	$self->{processor}->{report} = $session->param( 'report' );

	$self->{processor}->{screenid} = $self->{processor}->{report};
	$self->_create_search;

	my $loaded = 0;
        my $id = $session->param( "cache" );
        if( defined $id )
        {
		$loaded = $self->{processor}->{search}->from_cache( $id );
        }

        if( !$loaded )
        {
                my $exp = $session->param( "exp" );
                if( defined $exp )
                {
			$self->{processor}->{search}->from_string( $exp );
                        # cache expired...
                        $loaded = 1;
                }
        }

        my @problems;
        if( !$loaded )
        {
		for( $self->{processor}->{search}->from_form )
                        {
                                $self->{processor}->add_message( "warning", $_ );
                        }
        }
          

	#display the results
	$self->render;
}

sub properties_from
{
	my( $self ) = @_;

	my $repo = $self->repository;
	$self->SUPER::properties_from;

	if( defined ( my $dsid = $self->param( "datasetid" ) ) )
	{
		$self->{processor}->{dataset} = $self->repository->dataset( $dsid );
	}

	# sf2 - TODO - bark if dataset is not set? perhaps there are other ways to get the objects from...
	my $report = $self->get_report();

	#get a search object if we have one from a previous search action, so that we might later use it to do an export or search action
	$self->_create_search;	
	if( defined $self->repository->param( "search" ) )
	{
		$self->{processor}->{search}->from_string( $self->repository->param( "search" ) ) if defined $self->{processor}->{search};
		$self->{processor}->{export_search} = 1;
	}
	
	my $format = $self->repository->param( "export" );
	if( $format && $report )
	{
		my $plugin = $self->repository->plugin( "Export::$format", report => $report );
		if( defined $plugin && ( $plugin->can_accept( "report/$report" ) || ($plugin->can_accept( "report/generic" ) ) ) )
		{
			$self->{processor}->{plugin} = $plugin;
		}
	}

	#list of export fields retrieved from non-abstract instances of reports
	my @exportfields;
	if( defined $repo->config( $self->{export_conf}, "exportfields" ) )
	{
		my @keys;
		if( defined $repo->config( $self->{export_conf}, "exportfield_order" ) )
		{
			@keys = @{$repo->config( $self->{export_conf}, "exportfield_order" )};
		}
		else
		{
			@keys = keys %{$repo->config( $self->{export_conf}, "exportfields" )}; 
		}
		foreach my $key ( @keys )
		{
			foreach my $fieldname ( @{$repo->config( $self->{export_conf}, "exportfields" )->{$key}} )
			{
				push @exportfields, $fieldname if defined $self->repository->param( $fieldname ); 
			}
		}
	}

	my $sort = $self->repository->param( "sort" );
	if( defined $sort )
	{
		$self->{processor}->{sort} = $sort;
	}

	my $group = $self->repository->param( "group" );
	$self->{processor}->{group_exp} = $group; #store the group expression for later use
	
	#decode the group expression
	my %group_opts;
	if( defined $group )
	{
		#get field and associated configuration about the group, e.g. res, truncate, reverse_order etc.
		my @group = split(/;/, $group );
		my $first = 1;
		foreach my $g (@group)
		{
			if( $first )
			{
				$group = $g;
			}
			else
			{
				my @opts = split(/=/, $g );
				$group_opts{$opts[0]} = $opts[1];		
			}
			$first = 0;
		}
		$self->{processor}->{group} = $group;
		$self->{processor}->{group_opts} = \%group_opts;
	}

	$self->{processor}->{exportfields} = \@exportfields;
}
		
# \@({meta_fields=>[ "field1", "field2" "document.field3" ], merge=>"ANY", match=>"EX", value=>"bees"}, {meta_fields=>[ "field4" ], value=>"honey"});
# e.g.
# return [ { meta_fields => [ 'type' ], value => 'article' } ]
sub filters
{
	return [];
}

# how to select items i.e. the slice of data we want to validate/export?
# 
sub items
{
	my( $self ) = @_;
	if( $self->{processor}->{action} eq "search" || $self->{processor}->{export_search} )
       	{
		my $report = $self->{processor}->{report_plugin};	
		$report->apply_filters if $report->can( 'apply_filters' );

		my $items = $self->{processor}->{search}->perform_search;

		if( defined $self->{processor}->{sort} )
		{	
			$items = $items->reorder( $self->{processor}->{sort} );
		}
		return $items;
	}
	elsif( defined $self->{processor}->{dataset} ) 
	{
		my %search_opts = ( filters => $self->filters, satisfy_all => 1 );
		if( defined $self->param( 'custom_order' ) )
		{
			$search_opts{custom_order} = $self->param( 'custom_order' );
		}

		if( defined $self->{processor}->{sort} ) #an ordering specified by the user should trump the reports custom order
		{
			$search_opts{custom_order} = $self->{processor}->{sort};
		}	
		return $self->{processor}->{dataset}->search( %search_opts );
	}
	# we can't return an EPrints::List if {dataset} is not defined
	return undef;
}

# from Reports/ROS/Journals.pm
# TODO Note quite a lot of replication between this and Export::Report::CSV::output_dataobj
sub validate_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $repo = $plugin->repository;

	my $report_fields = $plugin->report_fields( $dataobj );
	my $val_fields = $plugin->validate_fields( $dataobj );

	# related objects and their datasets
	my $objects = $plugin->get_related_objects( $dataobj );
	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $repo->dataset( $dsid );
	}

	my @problems;

	foreach my $field ( @{ $plugin->report_fields_order( $dataobj ) || [] } )
	{
		# validation action
		my $v_field = $val_fields->{$field};
		next unless defined $v_field; # no validation required

		# simple case - code handles validation
		if( ref( $v_field ) eq 'CODE' )
		{
			# a sub{} we need to run
			eval {
				&$v_field( $plugin, $objects, \@problems );
			};
			if( $@ )
			{
				$repo->log( "Validation Runtime error: $@" );
			}
			next;
		}
		elsif( lc $v_field ne "required" )
		{
			$repo->log( "Validation Runtime error: $v_field must be code ref or 'required'" );
			next;
		}

		# check required values

		my $value; # the value to validate
		my $ep_field = $report_fields->{$field};
		if( ref( $ep_field ) eq 'CODE' )
		{
			# a sub{} we need to run
			eval {
				$value = &$ep_field( $plugin, $objects );
			};
			if( $@ )
			{
				$repo->log( "Validation Runtime error: $@" );
			}
		}
		elsif( $ep_field =~ /^([a-z_]+)\.([0-9a-z_]+)$/ )
		{
			# a straight mapping with an EPrints field
			my( $ds_id, $ep_fieldname ) = ( $1, $2 );
			my $ds = $valid_ds->{$ds_id};

			if( defined $ds && $ds->has_field( $ep_fieldname ) )
			{
				$value = $objects->{$ds_id}->value( $ep_fieldname );
			}
			else
			{
				# dataset or field doesn't exist
				$repo->log( "Validation Runtime error: dataset $ds_id or field $ep_fieldname doesn't exist" );
			}
		}

		# is field set?
		if( !EPrints::Utils::is_set( $value ) )
		{
			push @problems, "Missing required field $field";
		}
	}

	return @problems;
}

# TODO Note copy of Export::Report::get_related_objects
sub get_related_objects
{
	my( $plugin, $dataobj ) = @_;

	my $cmd = [ 'reports', $plugin->get_report, 'get_related_objects' ];
        if( $plugin->repository->can_call( @$cmd ) )
        {
		return $plugin->repository->call( $cmd, $plugin->repository, $dataobj ) || {};
        }

	# just pass the dataobj itself
	return {
		$dataobj->dataset->confid => $dataobj,
	};
}

# TODO Note copy of Export::Report::report_fields_order
sub report_fields_order
{
	my( $plugin ) = @_;

	return $plugin->{report_fields_order} if( defined $plugin->{report_fields_order} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{report_fields_order} = $plugin->repository->config( 'reports', $report, 'fields' );

	return $plugin->{report_fields_order};
}

# TODO Note copy of Export::Report::report_fields
sub report_fields
{
	my( $plugin ) = @_;

	return $plugin->{report_fields} if( defined $plugin->{report_fields} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{report_fields} = $plugin->repository->config( 'reports', $report, 'mappings' );

	return $plugin->{report_fields};
}

sub validate_fields
{
	my( $plugin ) = @_;

	return $plugin->{validate_fields} if( defined $plugin->{validate_fields} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{validate_fields} = $plugin->repository->config( 'reports', $report, 'validate' );

	return $plugin->{validate_fields};
}

## rendering

# The "splash page"
sub render_splash_page
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my @plugins = $self->report_plugins;

	if( !scalar( @plugins ) )
	{
		return $self->html_phrase( "no_reports" );
	}

	my @labels;
	my @panels;

	#preset reports
	push @labels, $repo->html_phrase( "reports_preset" );
	my $preset = $repo->make_element( "div" );
	my $presets_added = 0;

	# top category: by classname > Report::ROS::SomeReport1, Report::ROS::SomeReport2

	my $ul = $self->repository->make_element( 'ul', class => 'ep_report_category' );

	# cat ~ category - !meeow
	my $cat = "";
	my $cat_li = undef; 
	my $cat_ul = undef;
	
	#prepare hash of reporting plugins
	my %report_hash;
	foreach my $report_plugin ( sort { $a->get_subtype cmp $b->get_subtype } @plugins )
	{
		my $plugin_cat = $report_plugin->get_subtype;
		$plugin_cat =~ s/^Report::([^:]+):?:?(.*)$/$1/g;	

		if( $cat ne $plugin_cat ) #we have a top-category
		{
			$cat = $plugin_cat;
			$report_hash{$cat} = [];
		}

		if( EPrints::Utils::is_set( $2 ) )
		{
			push @{$report_hash{$cat}}, $report_plugin;
		}
	}
	
	for my $top_cat( sort keys %report_hash )
	{
		my @report_plugins = @{$report_hash{$top_cat}};
		if( scalar( @report_plugins ) > 0 )
		{
			#render top-category
			$cat_li = $ul->appendChild( $self->repository->make_element( 'li' ) );
			$cat_li->appendChild( $self->repository->html_phrase( "Plugin/Screen/Report/$top_cat:title" ) );

			$cat_ul = $cat_li->appendChild( $self->repository->make_element( 'ul', class => 'ep_report_items' ) );

			foreach my $r ( @report_plugins )
			{
				my $sub_li = $cat_ul->appendChild( $self->repository->make_element( 'li' ) );
				$sub_li->appendChild( $r->render_action_link );
				$presets_added++;
			}
		}
	}

	$preset->appendChild( $ul );
	push @panels, $preset;

	#custom reports
	push @labels, $repo->html_phrase( "reports_custom" );

	my $custom = $repo->make_element( "div", id=>"custom_report" );
	my $form = $repo->render_form( "get" );

	$form->appendChild( $self->render_controls( 1 ) );

	#add each report to the select component and generate search form if required
	my $report_select = $repo->make_element( "select", name=>"report", id=>"select_report", 'aria-labelledby' => "report_select_label" );
	my @search_forms;
	my $custom_reports = 0;
	#foreach my $report_plugin ( @plugins )
	foreach my $report_plugin ( sort { $a->get_subtype cmp $b->get_subtype } @plugins )
	{
		if( $report_plugin->param( "custom" ) )
		{	
			$custom_reports++;
			my $formid = $report_plugin->{sconf};

			#add to select component
			my $id = $report_plugin->{report};
			my $option = $repo->make_element( "option", value => $report_plugin->get_subtype, form => $formid );

			#set default option for select component if required (i.e. we have come from a refine search or new search link)
			my $refine_sconf = $self->{session}->param( "sconf" );
			if( ( $self->{processor}->{action} eq "update" || $self->{processor}->{action} eq "newsearch" ) && defined $refine_sconf && $refine_sconf eq $formid )
			{
				$option->setAttribute( selected => "selected" );
			}

			#set option text and add to select
  			$option->appendChild( $report_plugin->render_title );
			$report_select->appendChild( $option );

            # now we've added to the select, do we need to render a search form
            next if (grep { $formid eq $_ } @search_forms );     

			#create search form			
			#get report dataset and appropriate search config
            my $searchdatasetid = $report_plugin->{searchdatasetid};
            if( defined $report_plugin->param("searchdatasetid") )
            {
                $searchdatasetid = $report_plugin->param("searchdatasetid");
            }    
			my $report_ds = $repo->dataset( $searchdatasetid );
			my $sconf = $report_ds->search_config( $report_plugin->{sconf} ) ;
			#my $search = EPrints::Search->new(
		        #        keep_cache => 1,
	                #	session => $repo,
		        #        dataset => $report_ds,
		        #        %{$sconf}
			#);

			my $format = "report/" . $report_ds->base_id;
	                my $searchexp = $repo->plugin( "Search" )->plugins(
                        	{
                                	keep_cache => 1,
	                                session => $self->{session},
        	                        dataset => $report_ds,
                	                %{$sconf}
                        	},
                        type => "Search",
                        can_search => $format,
                	);	
			$searchexp->from_form;

			#generate the form
			my $frag = $self->render_search_fields( $searchexp, $formid );

            my $template = $repo->make_element( "template", id => $formid );
            my $table = $repo->make_element( "div", class=>"ep_table ep_search_fields", id=>"form_$formid" );
            $table->appendChild( $frag );
            $template->appendChild( $table );
            $custom->appendChild( $template );

            # keep a record of this search form to save us from rendering it again
            push @search_forms, $formid;
		}	
	}

    # label for form select drop down
    my $report_label = $repo->make_element( "label", id=>"report_select_label" );
    $report_label->appendChild( $repo->html_phrase( "report_select_label" ) );
    $form->appendChild( $report_label );
	$form->appendChild( $report_select );
	
    $form->appendChild( $repo->render_hidden_field( "screen", $self->{screenid} ) );
    $form->appendChild( $repo->make_element( "div", id=>"form_container" ) );
	
    $form->appendChild( $self->render_controls );
	
    $custom->appendChild( $form );

	#javascript for changing forms based on report selection
	$custom->appendChild( $repo->make_javascript( 'initReportForm();' ) );

	if( $custom_reports && $presets_added > 0 ) #set up tab interface
	{
		my @labels;
	        my @panels;

		push @labels, $repo->html_phrase( "reports_preset" );
		push @labels, $repo->html_phrase( "reports_custom" );

		push @panels, $preset;
		push @panels, $custom;

		my %opts;
		if( $self->{processor}->{action} eq "newsearch" || $self->{processor}->{action} eq "update"  )
		{
			$opts{current} = 1;
		}

		return $repo->xhtml->tabs(\@labels, \@panels, %opts );
	}
	elsif( $presets_added > 0 )
	{	
		return $preset;
	}
	else
	{
		return $custom;
	}
}

sub render_search_fields
{
    my( $self, $search, $formid ) = @_;

	my $exp = $self->{session}->param( "exp" );
	my $sconf = $self->{session}->param( "sconf" );
    if( defined $exp && defined $sconf && $sconf eq $formid )
	{
        $search->from_string( $exp );
  	}

    my $frag = $self->{session}->make_doc_fragment;
    foreach my $sf ( $search->get_non_filter_searchfields )
    {
        my $label;
        my $field;
        if ( $sf->{"field"}->get_type() eq "namedset" )
        {
            # we want a legend and a label
            $label = $self->{session}->make_element( "span", id=>$sf->get_form_prefix."_label" );
            $label->appendChild( $sf->render_name );

            my $legend = EPrints::Utils::tree_to_utf8( $sf->render_name );
            $field = $sf->render( legend => $legend );
        }
        else {
            $label = $self->{session}->make_element( "span", id=>$sf->get_form_prefix."_label" );
            $label->appendChild( $sf->render_name );
            $field = $sf->render();
        }

	    $frag->appendChild(
            $self->{session}->render_row_with_help(
                help_prefix => $sf->get_form_prefix."_help",
                help => $sf->render_help,
                label => $label,
                field => $field,
                no_toggle => ( $sf->{show_help} eq "always" ),
                no_help => ( $sf->{show_help} eq "never" ),
        ) );
    }

    return $frag;
}

sub render_controls
{
	my( $self, $with_js ) = @_;

    my $div = $self->{session}->make_element(
        "div" ,
        class => "ep_search_buttons" );
        
    $div->appendChild( $self->{session}->render_action_buttons(
        _order => [ "search" ],
        #newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
        search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
    );
	
	my $xml = $self->{session}->xml;

	if( $with_js )
	{
		my $clear_form = $div->appendChild( $self->render_clearform( $xml ) );
	}

    my $clear_btn = $div->appendChild( $xml->create_element( "button",
        type => "button",
        onclick => "clearForm();",
        class => "ep_form_action_button clear_button",
    ) );
    $clear_btn->appendChild( $xml->create_text_node( $self->{session}->phrase( "lib/searchexpression:action_reset" ) ) );
	return $div;
}

sub render
{
	my( $self ) = @_;

	# if users access Screen::Report directly we want to display some sort of menu
	# where users can select viewable reports
	if( ( "EPrints::Plugin::".$self->get_id eq __PACKAGE__ && $self->{processor}->{action} ne "search" ) || $self->{processor}->{action} eq "newsearch" )
	{	
		return $self->render_splash_page;
	}

	my $repo = $self->repository;

	my $chunk = $repo->make_doc_fragment;

	$chunk->appendChild( $self->render_export_bar );
	$chunk->appendChild( $self->render_group_options );
	$chunk->appendChild( $self->render_sort_options );

	if( $self->{processor}->{action} eq "search" )
	{
		$chunk->appendChild( $self->render_refine_search );
	}

	my $items = $self->items;
	if( !defined $items || $items->count == 0 )
	{
		# No items message
	}

	my $json;

	if( defined $self->{processor}->{group} && $self->{processor}->{group} ne "" )
	{
		my $grouped = $self->get_grouped_items( $items, 1 );
		$json = encode_json $grouped;
	}
	else
	{
		my $item_ids = defined $items ? $items->ids : [];
		$json = "[".join(',',@$item_ids)."]";
	}

        my $url = $repo->current_url( host => 1 );
        my $parameters = URI->new;
        $parameters->query_form(
                $self->hidden_bits,
        );
        $parameters = $parameters->query;
		
	my $ds = $repo->dataset( $self->param( 'datasetid' ) ) if defined $self->param( 'datasetid' );
	my $prefix = $ds->base_id if defined $ds;

	# the main <div>
	my $container_id = sprintf( "ep_report_%s\_container", $self->get_report );

	#update javascript parameters if coming from a search request
	if( $self->{processor}->{action} eq "search" )
	{
		my $plugin = $self->{processor}->{report};
		$plugin =~ s/:/%3A/g;
		$parameters = "screen=$plugin";
		$prefix = $self->{processor}->{datasetid};
		$container_id = sprintf( "ep_report_%s\_container", $self->{processor}->{report_plugin}->{report} );
	}
	
	#show/hide compliance
	my $show_compliance = 1;
	$show_compliance = $self->{show_compliance} if defined $self->{show_compliance};

	#custom labels
	my $labels = 0;
	$labels = encode_json $self->{labels} if defined $self->{labels};

	$chunk->appendChild( $repo->make_javascript( <<"EOJ" ) );
document.observe("dom:loaded", function() {
	new EPrints_Screen_Report_Loader( {
		ids: $json,
		step: 20,
		prefix: '$prefix',
		url: '$url',
		parameters: '$parameters',		
		container_id: '$container_id',
		show_compliance: $show_compliance,
		labels: $labels
	} ).execute();

});
EOJ
	$chunk->appendChild( $repo->make_element( 'div', class => 'ep_report_page', id => $container_id ) );

	#show search controls after the results too
	if( $self->{processor}->{action} eq "search" )
        {
                $chunk->appendChild( $self->render_refine_search );
        }

	return $chunk;
}


sub render_export_bar
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $chunk = $repo->make_doc_fragment;

	my @plugins = $self->export_plugins;
	return $chunk unless( scalar( @plugins ) || defined( $repo->config( $self->{export_conf}, "exportfields" ) ) );

	my $report_ds = $repo->dataset( $self->{datasetid} );
	my $form = $self->render_form;
	$form->setAttribute( method => "get" );

	if( defined $self->repository->param( "search" ) || $self->{processor}->{action} eq "search" )
	{
		$form->appendChild( $repo->render_hidden_field( "search",  $self->{processor}->{search}->serialise) );
	}
		
	if( defined $self->{processor}->{sort} )
	{
		$form->appendChild( $repo->render_hidden_field( "sort",  $self->{processor}->{sort} ) );
	}	

	if( defined $self->{processor}->{group_exp} )
	{
		$form->appendChild( $repo->render_hidden_field( "group",  $self->{processor}->{group_exp} ) );
	}	

    my $export_label = $repo->make_element( "label", id=>"export_select_label" );
    $export_label->appendChild( $repo->html_phrase( "export_select_label" ) );
    $form->appendChild( $export_label );

	if( !defined( $repo->config( $self->{export_conf}, "exportfields" ) ) )
	{
		#no custom export fields defined, use export plugins designed for this report
		my $select = $form->appendChild( $repo->render_option_list(
			name => 'export',
			values => [map { $_->get_subtype } @plugins],
			labels => {map { $_->get_subtype => $_->get_name } @plugins},
            'aria-labelledby' => "export_select_label",
		) );
	}
	else
	{
		#provide list of default export plugins for reports
		@plugins = $self->export_plugins( "generic" );
		my $select = $form->appendChild( $repo->render_option_list(
			name => 'export',
			values => [map { $_->get_subtype } @plugins],
			labels => {map { $_->get_subtype => $_->get_name } @plugins},
            'aria-labelledby' => "export_select_label",
		) );

		#create labels and panels for tabbed interfaced
		my $xml = $repo->xml;
		my $xhtml = $repo->xhtml;

		my $select_all = $form->appendChild( $self->render_selectall( $xml ) );
		my $select_btn = $form->appendChild( $xml->create_element( "button",
	                    type => "button",
	                    onclick => "toggleCheckboxes();",
	                    class => "ep_form_action_button select_button",
		) );
	    $select_btn->appendChild( $xml->create_text_node( $repo->phrase( "report_select" ) ) );

		#allow user to choose which fields they want to export
		my $export_options = $repo->make_element( "div" );

		my @keys;
		if( defined $repo->config( $self->{export_conf}, "exportfield_order" ) )
		{
			@keys = @{$repo->config( $self->{export_conf}, "exportfield_order" )};
		}
		else
		{
			@keys = keys %{$repo->config( $self->{export_conf}, "exportfields" )}; 
		}
		foreach my $key ( @keys )
		{
			#create a new list			
			my $ul = $repo->make_element( "ul",
	                	style => "list-style-type: none"
	        	);
			
			my $count = 0; #count how many fields we add
			foreach my $fieldname( @{$repo->config( $self->{export_conf}, "exportfields" )->{$key}} )
			{
				if( defined $repo->config( $self->{export_conf}, "custom_export" ) && exists ${$repo->config( $self->{export_conf}, "custom_export" )}{$fieldname} ) #we have a custom export function instead 
				{
					$count++;
					$self->_export_field_checkbox( $repo, $fieldname, $ul, $repo->html_phrase( "exportfieldoptions:$fieldname" ) ); 
				}
				elsif( defined EPrints::Utils::field_from_config_string( $report_ds, $fieldname ) )
				{
					my $field = EPrints::Utils::field_from_config_string( $report_ds, $fieldname );
					$count++;
       			        	$self->_export_field_checkbox( $repo, $fieldname, $ul, $field->render_name );

				}
			}
			if( $count ) #only add options if we have any fields to show
			{
				my $div = $repo->make_element( "div", class=>"report_export_options" );
				$div->appendChild( my $h = $repo->make_element( "div", class=>"custom_export_header" ) );
				$h->appendChild( $repo->html_phrase( "exportfields:$key" ) );	
				$div->appendChild( $ul );
				$export_options->appendChild( $div );
			}
       		}
		$form->appendChild( $export_options );
	}

	$form->appendChild( 
		$repo->render_button(
			name => "_action_export",
			class => "ep_form_action_button",
			value => $repo->phrase( 'cgi/users/edit_eprint:export' )
	) );

	#create a collapsible box
	my $imagesurl = $repo->current_url( path => "static", "style/images" );
	my %options;
	$options{session} = $repo;
        $options{id} = "ep_report_export";
        $options{title} = $repo->html_phrase( "export_title" );
        $options{collapsed} = 1;
	$options{content} = $form;
        $options{show_icon_url} = "$imagesurl/multi_down.png";
	$options{hide_icon_url} = "$imagesurl/multi_up.png";

	my $box = $repo->make_element( "div", style=>"text-align: left", class=>$self->{report} );
	$box->appendChild( EPrints::Box::render( %options ) );
	$chunk->appendChild( $box );

	return $chunk;
}

sub render_sort_options
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $chunk = $repo->make_doc_fragment;

	return $chunk unless( defined( $repo->config( $self->{sort_conf}, "sortfields" ) ) );

	my $sort_conf = $repo->config( $self->{sort_conf}, "sortfields" );

	#build the form
	my $form = $self->render_form;
	$form->setAttribute( name => "sort_report" );
        $form->setAttribute( method => "get" );
	$chunk->appendChild( $form );
	
	if( defined $repo->param( "search" ) || $self->{processor}->{action} eq "search" )
	{
		$form->appendChild( $repo->render_hidden_field( "search",  $self->{processor}->{search}->serialise) );
	}

	if( defined $self->{processor}->{group_exp} )
	{
		$form->appendChild( $repo->render_hidden_field( "group",  $self->{processor}->{group_exp} ) );
	}

	#display the links that will trigger the form
	my $first = 1;
	my $sort_links = $repo->make_doc_fragment;
	foreach my $sort_name ( keys %{$sort_conf} )
        {
		my $sort_value = $sort_conf->{$sort_name};
		if( $first )
		{
			$form->appendChild( $repo->render_hidden_field( "sort", $sort_value) );
		}

		if( !$first )
                {
                	$sort_links->appendChild( $repo->html_phrase( "Update/Views:group_separator" ) );
                }
		
		if( defined $self->{processor}->{sort} && $self->{processor}->{sort} eq $sort_value )
		{
			my $strong = $repo->make_element( "strong" );
			$strong->appendChild( $repo->html_phrase( $self->{sort_conf} . ":sort:" . $sort_name ) );
			$sort_links->appendChild( $strong );
		}
		else
		{
			my $link = $repo->render_link( 'javascript:sort_report("'.$sort_value.'")' );	
			$link->appendChild( $repo->html_phrase( $self->{sort_conf} . ":sort:" . $sort_name ) );
			$sort_links->appendChild( $link );
		}
		$first = 0;
        }           
	$chunk->appendChild( $repo->html_phrase( "Report:sort_links", links=>$sort_links ) );
	return $chunk;
}

sub render_group_options
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $chunk = $repo->make_doc_fragment;

	return $chunk unless( defined( $repo->config( $self->{group_conf}, "groupfields" ) ) );

	my $group_conf = $repo->config( $self->{group_conf}, "groupfields" );

	#build the form
	my $form = $self->render_form;
	$form->setAttribute( name => "group_report" );
        $form->setAttribute( method => "get" );
	$chunk->appendChild( $form );
	
	if( defined $repo->param( "search" ) || $self->{processor}->{action} eq "search" )
	{
		$form->appendChild( $repo->render_hidden_field( "search",  $self->{processor}->{search}->serialise) );
	}

	if( defined $self->{processor}->{sort} )
	{
		$form->appendChild( $repo->render_hidden_field( "sort",  $self->{processor}->{sort} ) );
	}

	#display the links that will trigger the form
	my $first = 1;
	my $group_links = $repo->make_doc_fragment;
	foreach my $group_value ( @{$group_conf} )
        {
		my ($group_field) = split(/;/, $group_value );
		if( $first )
		{
			$form->appendChild( $repo->render_hidden_field( "group", $group_value) );
		}

		if( !$first )
                {
                	$group_links->appendChild( $repo->html_phrase( "Update/Views:group_separator" ) );
                }
		
		if( defined $self->{processor}->{group} && $self->{processor}->{group} eq $group_field )
		{
			my $strong = $repo->make_element( "strong" );
			$strong->appendChild( $repo->html_phrase( $self->{group_conf} . ":group:" . $group_field ) );
			$group_links->appendChild( $strong );
		}
		else
		{
			my $link = $repo->render_link( 'javascript:group_report("'.$group_value.'")' );	
			$link->appendChild( $repo->html_phrase( $self->{group_conf} . ":group:" . $group_field ) );
			$group_links->appendChild( $link );
		}
		$first = 0;
        }           
	
	#no grouping link at the end
	$group_links->appendChild( $repo->html_phrase( "Update/Views:group_separator" ) );
	if( defined $self->{processor}->{group} && $self->{processor}->{group} ne "" )
	{
		my $link = $repo->render_link( 'javascript:group_report("")' );	
		$link->appendChild( $repo->html_phrase( "report:no_grouping" ) );
		$group_links->appendChild( $link );
	}
	else
	{
		my $strong = $repo->make_element( "strong" );
 		$strong->appendChild( $repo->html_phrase( "report:no_grouping" ) );
		$group_links->appendChild( $strong );
	}
	
	$chunk->appendChild( $repo->html_phrase( "Report:group_links", links=>$group_links ) );

	return $chunk;
}

sub render_refine_search
{
	my( $self ) = @_;

	my $repo = $self->repository;

	my $chunk = $repo->make_doc_fragment;
	
	if( defined $repo->param( "search" ) || $self->{processor}->{action} eq "search" )
	{
		my $escexp = $self->{processor}->{search}->serialise;
		my $cacheid = $repo->param( "cache" );
		my $sconf = $self->{sconf};	

		#set up new search link
		my $new_baseurl = URI->new( $self->{session}->get_uri );
        	$new_baseurl->query_form(
	                screen => "Report",
			sconf => $sconf,
        	);

		my $search_links = $repo->make_doc_fragment;
		my $new_link = $repo->render_link( "$new_baseurl&_action_newsearch=1" );
	   	$new_link->appendChild( $repo->html_phrase( "lib/searchexpression:new" ) );
		$search_links->appendChild( $new_link );

		#add a separator...
		$search_links->appendChild( $repo->html_phrase( "Update/Views:group_separator" ) );

		#set up refine search link
		my $refine_baseurl = URI->new( $self->{session}->get_uri );
        	$refine_baseurl->query_form(
	        	cache => $cacheid,
	                exp => $escexp,
        	        screen => "Report",
                	dataset => $self->{datasetid},
                	order => $self->{processor}->{search}->{custom_order},
			sconf => $sconf,
        	);

		my $refine_link = $repo->render_link( "$refine_baseurl&_action_update=1" );
      		$refine_link->appendChild( $repo->html_phrase( "lib/searchexpression:refine" ) );   	         
	        $search_links->appendChild( $refine_link );

		$chunk->appendChild( $repo->html_phrase( "Report:search_links", links=>$search_links ) );
	}

	return $chunk;
}


#adds a new checkbox to allow the user to choose which fields to export
sub _export_field_checkbox
{
	my( $self, $repo, $fieldname, $ul, $fieldlabel ) = @_;

	my $li = $repo->make_element( "li" );
	$ul->appendChild( $li );

        my $checkbox = $repo->make_element( "input", type => "checkbox", id => $fieldname, name => $fieldname, value => $fieldname );
	if( defined $repo->config( $self->{export_conf}, "exportfield_defaults" ) )
	{
		if( ( grep { $fieldname eq $_ } @{$repo->config( $self->{export_conf}, "exportfield_defaults" )} ) || ( scalar( @{$repo->config( $self->{export_conf}, "exportfield_defaults" )} ) == 0 ) )
		{
			# check defaults as specified
			$checkbox->setAttribute( "checked", "yes" );
		}
	}
    else # defaults not defined
    {
        $checkbox->setAttribute( "checked", "yes" );
    }

	my $label = $repo->make_element( "label", for => $fieldname );
	$label->appendChild( $fieldlabel );

	$li->appendChild( $checkbox );
	$li->appendChild( $label );
}

### utility methods

# TODO should use "JSON" package
sub to_json
{
        my( $self, $object ) = @_;

	return "" if( !defined $object );

# UTF-8 issues:
#	return JSON->new->utf8(1)->encode( $object );

        if( ref( $object ) eq 'HASH' )
        {
                my @stuff;
                while( my( $k, $v ) = each( %$object ) )
                {
                        next if( !EPrints::Utils::is_set( $v ) );       # or 'null' ?
                        push @stuff, EPrints::Utils::js_string( $k ).':'.$self->to_json( $v )
                }
                return '{' . join( ",", @stuff ) . '}';
        }
        elsif( ref( $object ) eq 'ARRAY' )
        {
                my @stuff;
                foreach( @$object )
                {
                        next if( !EPrints::Utils::is_set( $_ ) );
                        push @stuff, $self->to_json( $_ );
                }
                return '[' . join( ",", @stuff ) . ']';
        }

        return EPrints::Utils::js_string( $object );
}

sub export_plugins
{
        my( $self, $generic ) = @_;

	my @plugin_ids;
	
	my $repo = $self->repository;

	if( defined $repo->config( $self->{export_conf}, "export_plugins" ) )
	{
		@plugin_ids = @{$repo->config( $self->{export_conf}, "export_plugins" )};
	}	
	elsif( $generic )
	{
 		@plugin_ids = $repo->plugin_list(
                	type => "Export",
	                can_accept => "report/generic",
        	        is_visible => "staff",
			is_advertised => 1,
	        );
	}
	else
	{
        	@plugin_ids = $repo->plugin_list(
                	type => "Export",
	                can_accept => "report/".$self->get_report,
        	        is_visible => "staff",
			is_advertised => 1,
	        );
        }
	my @plugins;
	foreach my $id ( @plugin_ids )
        {
                my $p = $repo->plugin( "$id" ) or next;
                push @plugins, $p;
        }

        return @plugins;
}

sub report_plugins
{
	my( $self ) = @_;

	# sf2 - can't list via type => "Search::Report" ? 
        my @plugin_ids = $self->repository->plugin_list(
                type => "Screen",
        );

        my @plugins;
	foreach my $id ( @plugin_ids )
        {
		next if( $id !~ /^Screen::Report::/ );	# note this also filters out $self (aka Screen::Report)

                my $p = $self->repository->plugin( "$id" );
		next if( !defined $p || !$p->can_be_viewed );

                push @plugins, $p;
        }

        return @plugins;
}

#returns a hash of values mapped to a label and a list
#if ids_only is set the list of items are just represented by their id (used by report JS)
sub get_grouped_items
{
	my( $self, $items, $ids_only ) = @_;
	my $session = $self->{session};
	my %grouped;

	my $grouping = $self->{processor}->{group};

	my $metafield = $items->get_dataset->field( $grouping );

	#set group_opts if appropriate
	if( defined $self->{processor}->{group_opts} )
	{
		if( $metafield->type eq "date" )
		{
			$metafield->{render_res} = $self->{processor}->{group_opts}->{res} if exists $self->{processor}->{group_opts}->{res};
		}
	}

	#create a hash of field values to items (or item ids)
	$items->map( sub {
	       	my( $session, $dataset, $item ) = @_;
		
		my $multiple = $metafield->get_property( "multiple" );
		my @group_values;
		if( $multiple )
                {
			@group_values = @{$item->value( $grouping )};
		}
		else
		{			
			@group_values = ($item->value( $grouping ));
		}
	
		if( scalar @group_values > 0 )
		{
			foreach my $group_value ( @group_values )
			{
				my $group_id = $metafield->get_id_from_value( $session, $group_value );
				#truncate group if appropriate
				if( defined $self->{processor}->{group_opts} )
				{
					$group_id =  substr( "\u$group_id", 0, $self->{processor}->{group_opts}->{truncate} ) if exists $self->{processor}->{group_opts}->{truncate};
				}

		        	if( exists $grouped{$group_id} ) #we've already set this list up, push a new item on to the list
		               	{
					if( $ids_only ) #sometimes we only want ids rather than the whole item
					{
						push @{$grouped{$group_id}}, $item->id;
					}
					else
					{
						push @{$grouped{$group_id}}, $item;
					}
	       		        }
        	      		else #set up a list for this group
	        	       	{
					my @grouped_items;
					if( $ids_only ) #sometimes we only want ids rather than the whole item
		                        {	
        		                        @grouped_items = ($item->id);
                		        }
	                	        else
        	                	{
	                	                @grouped_items = ($item);
        		               	}
	                	        $grouped{$group_id} = [@grouped_items];
				}
               		}
		}
		else
		{
			my $group_id = "Unspecified " . $metafield->name;
  	    		if( exists $grouped{$group_id} ) #we've already set this list up, push a new item on to the list
		  	{
				if( $ids_only ) #sometimes we only want ids rather than the whole item
				{
					push @{$grouped{$group_id}}, $item->id;
				}
				else
				{
					push @{$grouped{$group_id}}, $item;
				}
	       		}
        	      	else #set up a list for this group
	        	{
				my @grouped_items;
				if( $ids_only ) #sometimes we only want ids rather than the whole item
		                {	
        				@grouped_items = ($item->id);
                		}
	                	else
        	                {
	               	                @grouped_items = ($item);
        	               	}
	              	        $grouped{$group_id} = [@grouped_items];
			}
		}
       	} );

	#now sort the groups and add human readable labels
	my @sorted_groups;
	
	my $reverse = 0;
	$reverse = $self->{processor}->{group_opts}->{reverse_order} if exists $self->{processor}->{group_opts}->{reverse_order};
	if( $metafield->type eq "namedset" )
	{
		my( $tags, $labels ) = $metafield->tags_and_labels( $session );
		#convert tags to a hash of values and a priority (for ordering)
		my %priority;
		my $index = 1;
		foreach my $tag (@{$tags} )
		{
			$priority{$tag} = $index;
			$index++;
		}
		foreach my $key (sort {$priority{$a} <=> $priority{$b}} keys %grouped)
        	{
			push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, $labels->{$key} );
		}
	}
	elsif( $metafield->type eq "subject" )
	{		
		my $ds = $session->dataset( "subject" );
		my @values = keys %grouped;
		my $sorted = $metafield->sort_values( $session, \@values );
		my %priority;
		my $index = 1;
                foreach my $value (@{$sorted} )
                {
                        $priority{$value} = $index;
                        $index++;
                }
		foreach my $key (sort {$priority{$a} <=> $priority{$b}} keys %grouped)
                {
			my $subj = $ds->dataobj( $key );
                        push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, EPrints::Utils::tree_to_utf8( $subj->render_description ) ) if defined $subj;
                }
	}
	elsif( $metafield->type eq "date" )
	{
		if( $reverse )
		{
			foreach my $key ( sort {$b <=> $a} keys %grouped )
			{
				push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, $key );
			}
		}
		else
		{
			foreach my $key ( sort {$a <=> $b} keys %grouped )
			{
				push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, $key );
			}
		}
	}
	else
	{	
		if( $reverse )
		{
			foreach my $key ( sort {$b cmp $a} keys %grouped )
			{
				push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, $key );
			}
		}
		else
		{
			foreach my $key ( sort keys %grouped )
			{
				push @sorted_groups, $self->_make_grouped_item( $grouped{$key}, $key );
			}
		}
	}

	#check for any unspecified groups
	my $group_id = "Unspecified " . $metafield->name;
	if( exists $grouped{$group_id} )
	{
		push @sorted_groups, $self->_make_grouped_item( $grouped{$group_id}, $group_id );
	}

	return \@sorted_groups;
}	


sub _make_grouped_item
{
	my( $self, $list, $label ) = @_;
	my %group;
	$group{list} = $list;
	$group{label} = $label;
	return \%group;
}

sub render_selectall
{
	my( $self, $xml ) = @_;

	my $toggle_function = '
		var isChecked = true;
		function toggleCheckboxes() {
	        	var export_options = document.getElementsByClassName("report_export_options");
			for( export_option of export_options )
			{
				var checkboxes = export_option.getElementsByTagName( "input" )
				for( checkbox of checkboxes )
				{
					if(isChecked)
					{
	                			checkbox.checked = "";
		  	        	}
					else
					{
				                checkbox.checked = "checked";
					}
	         		}
			}
			isChecked = !isChecked;
		}';
	
	my $js_tag = $xml->create_element( "script" );
	$js_tag->appendChild( $xml->create_text_node( $toggle_function ) );
	return $js_tag;
}

sub render_clearform
{
	my( $self, $xml ) = @_;

	my $clear_function = '
		function clearForm(){
			var report = document.getElementById( "custom_report" );
			var form = report.getElementsByClassName("selected_form")[0];
			var inputs = form.getElementsByTagName( "input" );
			for( input of inputs )
			{
				field_type = input.type.toLowerCase();	
				switch (field_type)
				{
				case "text":
				case "textarea":
					input.value = "";
					break;
				case "radio":
				case "checkbox":
					if (input.checked)
					{
        					input.checked = false;
					}
					break;
				case "select-one":
				case "select-multi":
					input.selectedIndex = -1;
					break;
				default:
					break;
				}
			}	
		        var selects = form.getElementsByTagName( "select" );
			for( select of selects )
			{	
				if( select.hasAttribute("multiple") )
				{
					select.selectedIndex = -1;
				}
			}		

		}';		

	my $js_tag = $xml->create_element( "script" );
        $js_tag->appendChild( $xml->create_text_node( $clear_function ) );
        return $js_tag;
}

1;
