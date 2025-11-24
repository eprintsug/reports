var initReportForm = function(){

        //polyfill for IE
        (function () {
                if ( typeof window.CustomEvent === "function" ) return false; //If not IE
                function CustomEvent ( event, params ) {
                    params = params || { bubbles: false, cancelable: false, detail: undefined };
                    var evt = document.createEvent( 'CustomEvent' );
                    evt.initCustomEvent( event, params.bubbles, params.cancelable, params.detail );
                    return evt;
                }

                CustomEvent.prototype = window.Event.prototype;

                window.CustomEvent = CustomEvent;
        })();


        var select = document.getElementById('select_report');
        select.addEventListener('change', onFormSelect);

        document.observe("dom:loaded", function() {
                var changeSelect = new CustomEvent("change");
                select.dispatchEvent(changeSelect);
        });
};


var onFormSelect = function(){
    //get form id
    var formid = this.options[this.selectedIndex].getAttribute('form');
    const container = document.getElementById("form_container");
    container.innerHTML = '';
    const clone = $(formid).content.cloneNode(true);
    container.appendChild(clone);
};

// Used by the Screen::Report::render method

var EPrints_Screen_Report_Loader = Class.create({
    has_problems: 0,
    count: 0,
    runs: 0,
    progress: null,
    ids: Array(),
    seen_ids: {},
    step: 20,
    batch: 0,
    grouped: false,
    prefix: '',
    onProblems: function() {},
    onFinish: function() {},
    url: "",
    parameters: "",
    container: null,
    show_compliance: 1, 

    // to show a pretty progress bar (% compliance):
    total_dataobjs: 0,
    total_noncompliant: 0,


    initialize: function(opts) {
        if( opts.ids )
            this.ids = opts.ids;
        if( opts.step )
            this.step = opts.step;
        if( opts.prefix )
            this.prefix = opts.prefix;
        if( opts.onFinish )
            this.onFinish = opts.onFinish;
        if( opts.onProblems )
            this.onProblems = opts.onProblems;
        if( opts.url )
        {
            this.url = opts.url;
        }
        if( opts.parameters )
            this.parameters = opts.parameters;
        if( opts.container_id )
            this.container = $( opts.container_id );    // should fail if container doesn't exist...
        if( opts.hasOwnProperty('show_compliance') )
        {
            this.show_compliance = opts.show_compliance;
        }
        if( opts.labels )
        {
            this.labels = opts.labels;
        }
    },

    // break down the requests into batches as defined by the step size
    // don't move on to the next batch until we've handled the previous one
    runBatch: function() {
    
        var dataobjs = {};

        var i = this.batch * this.step;
        
        // arguments for Ajax query AND creates the HTML placeholders <div>'s (that will receive the content of the Ajax query...)              
        var args = '&ajax='+this.prefix

        // build up our request for this step's results
        for(var j = 0; j < this.step && i+j < this.ids.length; j++)
        {
            args += '&' + this.prefix + '=' + this.ids[i+j];
            var id = this.prefix + '_' + this.ids[i+j];
            var target_el = $( id );
            if( target_el != null )
            {
                //store a record of this in seen_ids to ensure each placeholder has a unique id
                if( !(id in this.seen_ids) )
                {
                    this.seen_ids[id] = 1;
                }
                else
                {
                    this.seen_ids[id] = this.seen_ids[id] + 1;
                }
                id = id + "_" + this.seen_ids[id];
            }
            
            // set up an element for this result        
            this.container.insert( new Element( 'div', { 'class': 'ep_report_row', 'id': id, 'position': i+j } ), { 'position': 'after' } );
        }

        new Ajax.Request( this.url, {
            method: 'get',
            parameters: this.parameters + args,
            onSuccess: (function(transport) {

                // we got our report data back from the plugin
                var json = transport.responseText.evalJSON();
                var data = json.data;
                if( data == null )
                {
                    data = new Array();
                }
        
                for( var n = 0; n < data.length; n++ )
                {                       
                    var entry = data[n];
        
                    // no entry - awkward        
                    if( entry == null )
                    {
                        continue;
                    }

                    // no dataobj id - also awkward
                    var dataobjid = entry.dataobjid;
                    if( dataobjid == null )
                    {
                        continue;
                    }

                    // we have a dataobj, let's record it...
                    if( !(dataobjid in dataobjs) )
                    {
                        this.count++;
                        dataobjs[dataobjid] = entry;
                    }
                }

                //add the eprint summaries for this step
                var added_ids = {}; 

                //for( var c = this.batch * this.step; c < (this.batch * this.step) + this.step; c++ )
                for( var c = 0; c < this.step && i+c < this.ids.length; c++ )
                {
                    var dataobjid = this.ids[i+c];
                    var entry = dataobjs[dataobjid];

                    //store that we have added this objectid
                    if( !(dataobjid in added_ids) )
                    {
                        added_ids[dataobjid] = 0;
                    }
                    else
                    {
                        added_ids[dataobjid] = added_ids[dataobjid] + 1;
                    }
                    this.total_dataobjs++;

                    var summary = entry.summary;

                    var target_id = this.prefix + '_' + dataobjid;
                    if( added_ids[dataobjid] > 0 )
                    {
                        target_id = target_id + '_' + added_ids[dataobjid];
                    }
                    var target_el = $( target_id );

                    if( target_el != null && summary != null )
                    {
                        var summary_el = target_el.appendChild( new Element( 'div', { 'class': 'ep_report_row_summary' } ) );
                        summary_el.update( summary );

                        //total up non compliant records
                        if( entry.is_compliant == null && entry.problems && entry.problems.length )
                        {
                            this.total_noncompliant++;
                        }
                                
                        if( entry.problems && entry.problems.length )
                        {
                            var problems_el = target_el.appendChild( new Element( 'ul', { 'class': 'ep_report_row_problems' } ) );

                            for( var p = 0; p < entry.problems.length; p++ )
                            {
                                var li = problems_el.appendChild( new Element( 'li' ));
                                li.update( entry.problems[p] );
                            }                               
                        }
                        else
                        {
                            //add support for compliant items to include bullet points too
                            if( entry.bullets && entry.bullets.length )
                            {
                                var bullets_el = target_el.appendChild( new Element( 'ul', { 'class': 'ep_report_row_bullets' } ) );

                                for( var b = 0; b < entry.bullets.length; b++ )
                                {
                                    var li = bullets_el.appendChild( new Element( 'li' ));
                                    li.update( entry.bullets[b] );
                                }
                            }
                        }

                        //display state
                        var re = new RegExp("^#(?:[0-9a-fA-F]{3}){1,2}$");
                        if( entry.state && re.test(entry.state) )
                        {
                            target_el.style.borderLeftWidth = '7px';
                            target_el.style.borderLeftStyle = 'solid';
                            target_el.style.borderLeftColor = entry.state;
                        }
                        else //no state provided, so derive one from existence of problems
                        {
                            if( entry.problems && entry.problems.length )
                            {
                                target_el.addClassName( 'ep_report_row_problems' );
                            }
                            else
                            {
                                target_el.addClassName( 'ep_report_row_ok' );
                            }

                            if( !this.show_compliance )
                            {
                                target_el.addClassName( 'ep_report_row_no_compliance' );
                            }
                        }                               
                        target_el.show();

                        var grouping = entry.grouping;
                        if( grouping != null )
                        {
                            if( current_grouping == null || current_grouping != grouping)
                            {
                                current_grouping = grouping;
                                var grouping_container = new Element( 'div', { 'class': 'ep_report_grouping' } );
                                target_el.insert( { 'before' : grouping_container } );
                                grouping_container.update( current_grouping );
                            }
                        }
                    }
                }
             
                // we've retrieved all the records - this is the final step so tidy things up
                if( this.count == this.no_items )
                {
                    $( this.prefix + '_progress_bar' ).remove();
                    if( this.has_problems )
                    {
                        this.onProblems(this);
                    }
                    this.onFinish(this);
                            
                    //add the group headings
                    if(this.grouped)
                    {
                        var position = 0;
                        for( var m = 0; m < this.grouped_ids.length; m++ )
                        {   
                            var target_el = document.querySelectorAll('[position="' + position + '"]')[0];
                            position = position + this.grouped_ids[m].list.length;  
                            var grouping_container = new Element( 'div', { 'class': 'ep_report_grouping' } );
                            target_el.insert( { 'before' : grouping_container } );
                            grouping_container.update( this.grouped_ids[m].label );
                        }
                    }

                    this.container.insertBefore( new Element( 'div', { 'class': 'ep_report_compliance_container', 'id': this.prefix + "_compliance_container" } ), this.container.firstChild );
                    
                    //set up text container
                    $( this.prefix + "_compliance_container" ).appendChild( new Element( 'div', { 'class': 'ep_report_compliance_text', 'id': this.prefix + "_compliance_text",  } ));

                    //set up outputs label
                    var outputs;
                    if( this.labels )
                    {
                        outputs = this.labels.outputs;
                    }
                    else
                    {
                        outputs = "output";
                        if( this.total_dataobjs > 1 )
                        {
                            outputs = outputs + "s";
                        }
                    }

                    if( this.show_compliance )
                    {
                        var ref_width = 200;
                        var compliance = ( this.total_dataobjs - this.total_noncompliant ) / this.total_dataobjs;

                        $( this.prefix + "_compliance_container" ).appendChild( new Element( 'div', { 'class': 'ep_report_compliance_wrapper', 'id': this.prefix + "_compliance", 'style': 'width: '+ref_width + 'px' } ) );

                        var compliance_width = Math.floor( 200 * compliance );
    
                        $( this.prefix + "_compliance" ).appendChild( new Element( 'div', { 'class': 'ep_report_compliance', 'style': 'width:'+compliance_width + 'px' } ) );
    
                        $( this.prefix + "_compliance_text" ).update( this.total_dataobjs + " " + outputs + " - " + Math.floor( compliance * 100 ) + "% compliance");
                    }
                    else
                    {
                        $( this.prefix + "_compliance_text" ).update( this.total_dataobjs + " " + outputs );
                    }



                }
                else
                {
                    // update progress bar
                    var width = 200;
                    $( this.prefix + '_progress_bar' ).style.backgroundPosition = Math.round(-width + width * this.count / this.ids.length) + "px 0px";

                    // and run another batch
                    this.batch++;
                    this.runBatch();
                }

                // nothing to show... 
                if( this.runs == 0 && this.count == 0 )
                {
                    var pNode = $( this.prefix + '_progress_bar' ).parentNode;
                    $(this.prefix + '_progress_bar').remove();
                    var span = new Element( 'span', { 'class': 'ep_ref_report_empty' } );
                    span.update( 'Report empty' );
                    pNode.insert( span );
                }
                this.runs++;
            }).bind(this)
        });        
    },
    execute: function() {
        // progress-bar
        this.container.insert( new Element( 'div', { 'class': 'ep_report_progress_bar', 'id': this.prefix + "_progress_bar" } ) );  

        var current_grouping = null;    // might not be set in the returned value but that's allowed/OK
        this.no_items = this.ids.length;
        this.retrieved = [];
        if( !isInteger(this.ids[0]) ) //ids have been grouped
        {   
            this.grouped = true;
            this.grouped_ids = this.ids;
            this.ids = [];
            for( var i = 0; i < this.grouped_ids.length; i++ )
            {
                this.ids = this.ids.concat(this.grouped_ids[i].list);
            }
            //the grouping may have created duplicate records (i.e. a record can appear in more than one group) - it's handy to have an array of all the unique records
            this.unique = this.ids.filter(function(item, i, ar){ return ar.indexOf(item) === i; });
            this.no_items = this.unique.length;
        }

        if( this.ids == null || this.ids.length == 0 )
        {
            var pNode = $(this.prefix + '_progress_bar').parentNode;
            $(this.prefix + '_progress_bar').hide();
            var span = new Element( 'span', { 'class': 'ep_ref_report_empty' } );
            span.update( 'Report empty' );
            pNode.insert( span );
        }
        this.runBatch();
    }


});

function group_report(group)
{
    document.group_report.group.value = group;
    document.group_report.submit();
}

function sort_report(sort)
{
    document.sort_report.sort.value = sort;
    document.sort_report.submit();
}

function isInteger(num) {
  return (num ^ 0) === num;
}
