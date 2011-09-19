module Extensions
  module HasPageTemplates
    
    # Find the most suitable template based on this page 
    # and its ancestor's slugs and assign it automatically
    def auto_select_template
      # Don't do anything if Page has a valid PageTemplate
      # and it's locked (because it was selected manually)
      unless defined?(self.page_template_path) && # Check PageTemplates migration already ran
          self.page_template_path.present? &&
          PageTemplate.find(self.page_template_path).present? &&
          self.lock_page_template
            self.page_template_path = self.guess_template_path
      end
      return true
    end
    
    def expected_template_paths
      out = []
      slugs.each do |s|
        if parent && !parent.home?
          parent.expected_template_paths.each do |parent_path|
            out << [parent_path, s.name.gsub("-","_")].compact.flatten.join("/")
          end
        else
          out << s.name.gsub("-","_")
        end
      end
      out += parent.expected_template_paths if parent
      return out
    end

    def guess_template_path
      expected_template_paths.each do |expected_path|
        if PageTemplate.find_by_path(expected_path)
          return expected_path
        end
      end
      return nil
    end

    # We should re-apply the template to the page
    # if the page is new or the template has been changed
    def should_apply_template?
      if self.id.nil? # New page
        @should_apply_template = true
      elsif not defined?(self.page_template_path) # PageTemplate migration not ran yet
        @should_apply_template = false
      else # Check if template is different from previous
        past_self = Page.find(self.id)
        @should_apply_template = (past_self.page_template_path != self.page_template_path)
      end
      return true # Note to self: no callbacks should return false, otherwise the record won't be saved
    end

    # Re-apply template
    def apply_template(force=false)
      return unless @should_apply_template || force
      # If this Page instance has a PageTemplate and the template has a 
      # page_parts sceheme, use those parts here. Otherwise, use default
      # parts from Settings.
      if page_template.present? and page_template.page_parts.present?
        template_parts = page_template.page_parts
      else
        template_parts = Page.default_parts
      end
      # Remove all parts which are empty and not defined in the current template
      parts.each do |part|
        unless template_parts.present? && template_parts.map{ |p| p['title'] }.include?(part.title)
          unless part.body.present?
            part.destroy
          else
            part.save
          end
        end
      end unless parts.nil?
      # Make sure the page has all parts defined in the template
      template_parts.each_with_index do |part, index|
        unless parts.present? && parts.map{ |p| p.title }.include?(part['title'])
          parts.create(:title => part['title'], :position => index)
        end
      end unless template_parts.nil?
    end

  end
end