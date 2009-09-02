module ActsAsCached
  module Mixin
    def acts_as_cached_with_find_hook(options = {})
      acts_as_cached_without_find_hook options
      cache_config[:finder] ||= :original_find
      if cache_config[:finder] == :find or cache_config[:finder] == :original_find
        class_eval %{
          class << self
            alias :original_find :find
            def find(*args)
              if args.first == :first or args.first == :last or args.first == :all
                original_find *args
              else
                get_cache args.first
              end
            end
          end
        }, __FILE__, __LINE__
      else
        match           = ActiveRecord::DynamicFinderMatch.match cache_config[:finder]
        attribute_names = match.attribute_names
        finder          = match.finder
        bang            = match.bang?
        class_eval %{
          def self.#{cache_config[:finder]}(*args)
            get_cache args.first do
              options = args.extract_options!
              attributes = construct_attributes_from_arguments(
                [:#{attribute_names.join(',:')}],
                args
              )
              finder_options = { :conditions => attributes }
              validate_find_options(options)
              set_readonly_option!(options)

              #{'result = ' if bang}if options[:conditions]
                with_scope(:find => finder_options) do
                  find(:#{finder}, options)
                end
              else
                find(:#{finder}, options.merge(finder_options))
              end
              #{'result || raise(RecordNotFound, "Couldn\'t find #{name} with #{attributes.to_a.collect {|pair| "#{pair.first} = #{pair.second}"}.join(\', \')}")' if bang}
            end
          end
        }, __FILE__, __LINE__
      end
    end
    alias_method_chain :acts_as_cached, :find_hook
  end
end
