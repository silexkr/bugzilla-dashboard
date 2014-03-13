$(function() {

  // only create a new bug button can submit the form
  $('#form-create-bug').submit(function(e) {
    e.preventDefault();
  });
  $('#btn-create-bug').click(function(e) {
    return $('#form-create-bug').trigger('submit');
  });

  // update product, component and version
  function update_bug_info( product, component, version ) {
    if ( product !== null && product !== undefined ) {
      $('#product').val(product);
      $('#lbl-product').html(product)
    }
    else {
      $('#product').val('');
      $('#lbl-product').html('Undef')
    }

    if ( component !== null && component !== undefined ) {
      $('#component').val(component);
      $('#lbl-component').html(component)
    }
    else {
      $('#component').val('');
      $('#lbl-component').html('Undef')
    }

    if ( version !== null && version !== undefined ) {
      $('#version').val(version);
      $('#lbl-version').html(version)
    }
    else {
      $('#version').val('');
      $('#lbl-version').html('unspecified')
    }
  }

  // redraw block buttons
  function reload_block_buttons() {
    $('#block-buttons').html(
      ' <button id="btn-clear-block" class="btn btn-warning btn-small"> Clear </button>'
    );
    $('#btn-clear-block').click(function(e) {
      update_bug_info();
    });

    var blocks = $('#blocks').val().split(/[ ,]+/);
    for ( var i = 0; i < blocks.length; ++i ) {
      $('#block-buttons').append(
        ' <button class="btn btn-success btn-small btn-sync-block">'
        + blocks[i]
        + '</button>'
      );
    }
    $('.btn-sync-block').click(function(e) {
      var block = $(this).html();

      $.ajax("/api/bug/" + block + ".json", {
        type: 'GET',
        data: {},
        success: function(data, textStatus, jqXHR) {
          update_bug_info( data.product, data.component, data.version );
        },
        error: function(jqXHR, textStatus, errorThrown) {},
        complete: function(jqXHR, textStatus) {}
      });
    });
  }

  reload_block_buttons();
  $('#blocks').change(function() {
    reload_block_buttons();
  });

});
