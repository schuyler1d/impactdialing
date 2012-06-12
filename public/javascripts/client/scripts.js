var Scripts = function(){}

Scripts.prototype.display_question_numbers = function(){
  var question_count = 1;    
  $.each($('.question_label'), function(){
	if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Question "+question_count++);
    }
  });

}

Scripts.prototype.mark_questions_answered = function(){
	questions_answered();

	
}

Scripts.prototype.display_text_field_numbers = function(){
  var text_field_count = 1;
  $.each($('.text_field_label'), function(){
    if ($(this).parent('fieldset').attr('deleted') != "true") {
      $(this).text("Text Field "+text_field_count++);
	}
  });
}

Scripts.prototype.add_new_response_when_question_added = function(){
  $.each($('.question'), function(){
    if ($(this).children('.possible_response').length == 0) {
      $(this).children('.add_response').trigger('click')
    }      
  });    
}

function question_delete(question_node){
if($('#script_questions').children('.nested-fields').length == 1){
      alert("You must have at least one question");
      return false;
    }
  return true;   
}

function questions_answered(){
  $.ajax({
    url : "/client/scripts/questions_answered",
    data : {id : $("#script_id").val() },
    type : "GET",
	async : false,
    success : function(response) {
		for (myKey in response["data"]){
			$('#script_questions').find('.identity').each(function(){
				if ($(this).val() == response["data"][myKey]) {
					$(this).attr('answered', true)
				}
			});
		}
	}
  });
}

function possible_response_delete(response_node){
  var question = $(response_node).parents('.question');
  if($(question).children('.possible_response').length == 1) {
    alert("You must have at least one response.");
    return false;
  }
  else{
	  return true;
  }    	
}
