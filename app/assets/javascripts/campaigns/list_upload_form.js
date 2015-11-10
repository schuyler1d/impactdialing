'use strict';

var ListUploadForm = function() {
  var self    = this;
  this.action = '';

  $('input[type="radio"][name="voter_list[purpose]"]').change(function(e) {
    var val = $(this).val();
    self.toggle(val);
  });
};

ListUploadForm.prototype.purposes = ['import', 'prune_numbers', 'prune_leads'];

ListUploadForm.prototype.selectors = {
  'import': '.js_list_upload_add_option',
  'prune_numbers': '.js_list_upload_remove_numbers_option',
  'prune_leads': '.js_list_upload_remove_leads_option'
};

ListUploadForm.prototype.toggle = function(val) {
  var n = this.purposes.length;

  for( var i=0; i<=n; i++ ) {
    var purpose = this.purposes[i];
    var selector = this.selectors[purpose];

    if( purpose == val ) {
      this.purpose = purpose;
      $(selector).show();
    } else {
      $(selector).hide();
    }
  }
  this.update_action();
};

ListUploadForm.prototype.update_action = function(for_new_file) {
  var campaign_id = $('#campaign_id').val();
  var url = [
    '/client/campaigns',
    $('#campaign_id').val(),
    'voter_lists'
  ];
  if( for_new_file ) {
    url.push('column_mapping');
  } else {
    if( this.removalList() ) {
      url.push('remove');
    } 
  }
  $('#voter_list_upload').attr('action', url.join('/'));
};

ListUploadForm.prototype.validateMapping = function(selected_mapping) {
  var out = [];
  if( this.mappingRequiresPhone() ) {
    if( !this.isMapped('phone', selected_mapping) ) {
      out.push("Please map a column to the Phone field before uploading.");
    }
  }
  if( this.mappingRequiresCustomID() ) {
    if( this.isMapped('custom_id', selected_mapping) ) {
      out.push("Please map a column to the ID field before uploading.");
    }
  }

  return out;
};

ListUploadForm.prototype.isMapped = function(field, mapping) {
  return $.inArray(field, mapping) > -1;
};

ListUploadForm.prototype.mappingRequiresPhone = function() {
  return $.inArray(this.purpose, ['add', 'remove_numbers']) > -1;
};

ListUploadForm.prototype.mappingRequiresCustomID = function(usingCustomID) {
  return (
    this.purpose == 'remove_leads' ||
    (!!usingCustomID && this.purpose != 'remove_numbers')
  );
};

ListUploadForm.prototype.removalList = function() {
  return $.inArray(this.purpose, ['remove_leads', 'remove_numbers']) > -1;
};

