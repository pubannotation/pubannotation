module Rails3JQueryAutocomplete
  module Autocomplete
    def get_object(model_sym, options = {})
      # replace model_sym to options[:class_name] if present
      model_sym = options[:class_name] if options[:class_name]
      object = model_sym.to_s.camelize.constantize
    end

    module ClassMethods
      def autocomplete(object, method, options = {})
        define_method("autocomplete_#{object}_#{method}") do
          method = options[:column_name] if options.has_key?(:column_name)

          term = params[:term]

          if term && !term.blank?
            #allow specifying fully qualified class name for model object
            class_name = options[:class_name] || object
            items = get_autocomplete_items(:model => get_object(class_name, options), \
              :options => options, :term => term, :method => method, :scope_argument => params[:scope_argument])
          else
            items = {}
          end

          render :json => json_for_autocomplete(items, options[:display_value] ||= method, options[:extra_data])
        end
      end
    end
  end
  
  module Orm
    module ActiveRecord
      def get_autocomplete_items(parameters)
        model   = parameters[:model]
        term    = parameters[:term]
        method  = parameters[:method]
        options = parameters[:options]
        scopes  = Array(options[:scopes])
        where   = options[:where]
        limit   = get_autocomplete_limit(options)
        order   = get_autocomplete_order(method, options, model)

        items = model.scoped

        scopes.each { |scope| 
          if scope.class == Symbol
            items = items.send(scope)
          elsif scope.class == Hash
            scope_name = scope.keys.first
            items = items.send(scope_name, parameters[:scope_argument])
          end 
        } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
        items = items.where(get_autocomplete_where_clause(model, term, method, options)).
            limit(limit).order(order)
        items = items.where(where) unless where.blank?

        items
      end
    end
  end
end

