
window.addEvent('domready', function() {


    // Datepicker zuordnen
    $$('.datepicker').each( function(dp) {

        // Element 
        var dpid = dp.get('id');
       
        dp.addClass('highlight-days-67');
        dp.addClass('no-transparency');
        dp.addClass('format-d-m-y');
        dp.addClass('divider-dot');

        if ( dpid ) {

            datePickerController.datePickers[dpid];

        } else {

            alert("Elemente ohne ID");
        }

    });


    $$('.form').addEvent('focus:relay(li)', function(event) {

        var cur = this;

        $$('.form li').each( function(el) { el.removeClass('focus') });
        cur.addClass('focus'); 
    });



}) 
