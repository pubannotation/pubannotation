class PMDoc
  
  def self.generate(pmid)
    RestClient.get "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&id=#{pmid}" do |response, request, result|
      case response.code
      when 200
        parser   = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        doc      = parser.parse
        result   = doc.find_first('/PubmedArticleSet').content.strip
        return nil if result.empty?
        title    = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle')
        abstract = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText')
        doc      = Doc.new
        doc.body = ""
        doc.body += title.content.strip if title
        doc.body += "\n" + abstract.content.strip if abstract
        doc.source = 'http://www.ncbi.nlm.nih.gov/pubmed/' + pmid
        doc.sourcedb = 'PubMed'
        doc.sourceid = pmid
        doc.serial = 0
        doc.section = 'TIAB'
        doc.save
        return doc
      else
        return nil
      end
    end
  end
  
  def self.add_to_project(project, ids, num_created, num_added, num_failed)
    pmids = ids.split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
    pmids.each do |sourceid|
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
      if doc
        unless project.docs.include?(doc)
          project.docs << doc
          num_added += 1
        end
      else
        doc = generate(sourceid)
        if doc
          project.docs << doc
          num_added += 1
        else
          num_failed += 1
        end
      end
    end  
    return [num_added, num_failed]    
  end
end