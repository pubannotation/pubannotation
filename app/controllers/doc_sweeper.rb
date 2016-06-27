class DocSweeper < ActionController::Caching::Sweeper
  observe Doc # This sweeper is going to keep an eye on the Doc model
 
  # If our sweeper detects that a doc was created call this
  def after_create(doc)
    expire_fragment("count_docs")
    expire_fragment("count_#{doc.sourcedb}")
    doc.projects.each do |p|
      expire_fragment("count_docs_#{p.name}")
      expire_fragment("count_#{doc.sourcedb}_#{p.name}")
    end
  end
 
  # If our sweeper detects that a doc was updated call this
  def after_update(doc)
    # expire_cache_for(doc)
  end
 
  # If our sweeper detects that a doc was deleted call this
  def after_destroy(doc)
    expire_fragment('count_docs')
    expire_fragment("count_#{doc.sourcedb}")
    doc.projects.each do |p|
      expire_fragment("count_docs_#{p.name}")
      expire_fragment("count_#{doc.sourcedb}_#{p.name}")
    end
  end
 
  private
  def expire_cache_for(doc)
    # Expire the index page now that we added a new doc
    expire_page(:controller => 'docs', :action => 'index')
   end
end