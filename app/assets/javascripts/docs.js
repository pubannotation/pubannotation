// Initialize
$(document).ready(function(){
  selectProjectNames();
  selectedProjectsElement = $('#selected_projects_list');
  unselectedProjectsElement = $('#unselected_projects_list');
  toggleProjectsSelection();
  switchProjectSelection();
  sortSelectedProjectsByName(); 
  sortSelectedProjectsByAnnotationsCount();
  selectedProjectNames = new Array();
  countProjectAnnotations();
  countProjects();
  $( function() {
    $( "#selected_projects_list" ).sortable({
      placeholder: "ui-state-highlight",
      update: function(){
        getSelectedProjectNames();
        setAnnotationHref();
      }
    });
    $( "#selected_projects_list" ).disableSelection();
} );
});

// Add remove project name
var selectProjectNames = function(){
  $('.project_selector').click(function(){
    projectName = $(this).data('project-name');
    isSelected = selectedProjectsElement.find("span[data-project-name='" + projectName + "']").length > 0;
    if(isSelected){
      // if already selected
      unselectedProjectsElement.append($(this).parent());
    }else{
      // if not selected yet
      $('#no_projects_warning').remove();
      selectedProjectsElement.append($(this).parent());
    }
    getSelectedProjectNames();
    switchButtonClass();
    setAnnotationHref();
    countProjectAnnotations();
    countProjects();
  })
}

// Add ?projects=project_name_1,project_name_2 to VIEW, JSON and TextAE links
var setAnnotationHref = function(){
  annotationLinkIds = ["view", "json", "textae"] 
  jQuery.each(annotationLinkIds, function(i, id) {
    linkElement = $("#annotations_" + id);
    href = linkElement.attr("href");
    if ( selectedProjectNames.length > 0 ){
      linkElement.attr("href", href.split('?')[0] + "?projects=" + selectedProjectNames.join());
    }else{
      linkElement.attr("href", href.split('?')[0]);
    };
  });
}

// Return selected project names by array
var getSelectedProjectNames = function(){
  selectedProjectNames = [];
  selectedProjectElements = selectedProjectsElement.find('.project_wrapper');
  jQuery.each(selectedProjectElements, function(i, selectedProjectElement) {
    projectName = $( selectedProjectElement ).data('project-name');
    selectedProjectNames.push(projectName);
  });
}

var switchButtonClass = function(){
  jQuery.each(selectedProjectsElement.find('.fa'), function(i, selectedProjectElement){
    $(selectedProjectElement).switchClass('fa-plus', 'fa-minus');
  });
  jQuery.each(unselectedProjectsElement.find('.fa'), function(i, unselectedProjectElement){
    $(unselectedProjectElement).switchClass('fa-minus', 'fa-plus');
  });
}

var toggleProjectsSelection = function(selectFlag){
  $('.move_projects').click(function(e){
    if (e.target.id == 'move_to_selected') {
      // move to selected
      currentElement = unselectedProjectsElement;
      moveToElement = selectedProjectsElement;
    }else{
      // move to unselected
      currentElement = unselectedProjectsElement;
      currentElement = selectedProjectsElement;
      moveToElement = unselectedProjectsElement;
      selectedProjectNames = [];

    }
    projectElements = currentElement.find('.project_wrapper');
    moveToElement.append(projectElements);
    getSelectedProjectNames();
    switchButtonClass(); 
    setAnnotationHref();
    countProjectAnnotations();
    countProjects();
  })
}

var switchProjectSelection = function(){
  $('#switch_selection').click(function(){
    selectedProjectElements = selectedProjectsElement.find('.project_wrapper');
    unselectedProjectElements = unselectedProjectsElement.find('.project_wrapper');
    unselectedProjectsElement.append(selectedProjectElements);
    selectedProjectsElement.append(unselectedProjectElements);
    getSelectedProjectNames();
    switchButtonClass(); 
    setAnnotationHref();
    countProjectAnnotations();
    countProjects();
  });
}

var sortSelectedProjectsByName = function(){
  $('.fa-sort-alpha-asc').click(function(){
    sortSelectedProjects('project-name');
  });
}

var sortSelectedProjectsByAnnotationsCount = function(){
  $('.fa-sort-numeric-desc').click(function(){
    sortSelectedProjects('annotations-count');
  });
}

var sortSelectedProjects = function(sortKey){
  selectedProjectElements = selectedProjectsElement.find('.project_wrapper');
  if(sortKey == 'project-name'){
    greaterVal = 1;
    lessVal = -1
  }else{
    greaterVal = -1;
    lessVal = 1
  }
  selectedProjectElements.sort(function(a, b){
    var an = $( a ).data(sortKey), bn = $( b ).data(sortKey);
    if(an > bn) {
      return greaterVal;
    }
    if(an < bn) {
      return lessVal;
    }
    return 0;
  });
  selectedProjectsElement.append(selectedProjectElements);
  getSelectedProjectNames();
  setAnnotationHref();
}

var countProjects = function(){
  unselectProjectsCount = unselectedProjectsElement.find('.project_wrapper').length;
  $('#unselected_projects_count').text('(' + unselectProjectsCount + ')');
  selectProjectsCount = selectedProjectsElement.find('.project_wrapper').length;
  $('#selected_projects_count').text('(' + selectProjectsCount + ')');
};

var countProjectAnnotations = function(){
  var selectedProjectsAnnotaionsCount = 0;
  var unselectedProjectsAnnotaionsCount = 0;
  jQuery.each(selectedProjectsElement.find('.project_wrapper'), function(i, selectedProjectElement){
    annotationsCount = $(selectedProjectElement).data('annotations-count');
    selectedProjectsAnnotaionsCount += parseInt( annotationsCount );
  });
  jQuery.each(unselectedProjectsElement.find('.project_wrapper'), function(i, unselectedProjectElement){
    annotationsCount = $(unselectedProjectElement).data('annotations-count');
    unselectedProjectsAnnotaionsCount += parseInt( annotationsCount );
  });
  if (selectedProjectsAnnotaionsCount >= 100) {
    $('#annotations_textae').attr('href', '');
    $('#annotations_textae').attr('title', 'Annotations too many');
    $('#annotations_textae').addClass('disabled_textae_link');
    $('#annotations_textae').on("click", function (e) {
        e.preventDefault();
    });
  }else{
    $('#annotations_textae').removeClass('disabled_textae_link');
  };
  $('#selected_projects_annotations_count').text('(' + selectedProjectsAnnotaionsCount + ')');
  $('#unselected_projects_annotations_count').text('(' + unselectedProjectsAnnotaionsCount + ')');
}
