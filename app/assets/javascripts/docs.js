// Initialize
$(document).ready(function(){
  selectProjectNames();
  getSelectedProjectNames();
  selectedProjectsElement = $('#selected_projects_list');
  unselectedProjectsElement = $('#unselected_projects_list');
  selectedProjectNames = new Array();
});

// Add remove project name
var selectProjectNames = function(){
  $('.project_selector').click(function(){
    projectName = $(this).data('project-name');
    isSelected = selectedProjectsElement.find("span[data-project-name='" + projectName + "']").length > 0;
    if(isSelected){
      // if already selected
      unselectedProjectsElement.append($(this));
      for(i=0;  i< selectedProjectNames.length; i++){
        if(selectedProjectNames[i] == projectName){
          selectedProjectNames.splice(i, 1);
        }
      }
    }else{
      // if not selected yet
      $('#no_projects_warning').remove();
      selectedProjectsElement.append($(this));
      selectedProjectNames.push(projectName);
    }
  })
}

// Add ?projects=project_name_1,project_name_2 to VIEW, JSON and TextAE links
var setAnnotationHref = function(){
  annotationLinkIds = ["view", "json", "textae"] 
  jQuery.each(annotationLinkIds, function(i, id) {
    linkElement = $("#annotations_" + id);
    href = linkElement.attr("href");
    linkElement.attr("href", href + "?projects=" + selectedProjectNames.join());
  });
}

// Return selected project names by array
var getSelectedProjectNames = function(){
  $('#set_selected_projects').click(function(){
    setAnnotationHref();
    showSelectedProjectNames();
    return selectedProjectNames;
  });
}


var showSelectedProjectNames = function(){
  if ( selectedProjectNames.length > 0 ) {
    // fetch by ajax
    docId = $('#set_selected_projects').data('doc-id');
    jQuery.getScript("/projects/list?doc_id=" + docId + "&projects=" + selectedProjectNames.join());
  }else{
    selectedProjectsElement.append("<span id='no_projects_warning' style='color:#f00'>Nothing selected.</span>");
  }
}

