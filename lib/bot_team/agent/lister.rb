# frozen_string_literal: true

module Agent
  class Lister < ChatGptAgent
    attr_reader :items

    attr_accessor :descriptions, :list_prompt

    def initialize(**args) # rubocop:disable Metrics/MethodLength
      # Set default agent configs before calling super so that
      # they can still be overridden by initialization args
      self.max_tokens = 300
      @parameters = {}
      # Pull out subclass settings / set defaults
      @list_prompt =
        args.delete(:list_prompt) ||
        "The user will make a request and expect a list in response"
      item_function_arg = args.delete(:item_function)
      @descriptions = args.delete(:descriptions) || {}
      item_function(item_function_arg, descriptions:) if item_function_arg
      super(**args)
      @items = nil
      @result = nil
    end

    def item_function(method = nil, descriptions: {}, &block)
      raise "Must supply either a method or a block to item_function" unless method || block
      raise "Only one of method or block can be supplied to item_function" if method && block

      @descriptions = descriptions.merge(@descriptions)
      set_function_with_parameters(method || block, descriptions:)
    end

    def run(message = nil, **_args)
      set_system_directives_from_options
      @result = super
      @result = JSON.parse(@result.gsub(/^```.*/, '')).map { |obj| obj.transform_keys(&:to_sym) }
      @result.each { |obj| @function.call(**obj) } if @function
      @result
    end

    private

    def set_function_with_parameters(proc, descriptions:) # rubocop:disable Metrics/MethodLength
      @function = proc

      proc.parameters.each do |param|
        case param[0]
        when :keyreq
          setup_function_parameter(param[1], descriptions[param[1]], true)
        when :key
          setup_function_parameter(param[1], descriptions[param[1]], false)
        when :keyrest
          # do nothing
        when :req, :opt, :rest, :block
          raise ArgumentError,
                "Positional arguments, splats, and blocks are not allowed in item function, " \
                "use keyword args and double splat only"
        end
      end
    end

    def setup_function_parameter(name, description, required)
      @parameters[name.to_s] = {}
      @parameters[name.to_s][:required] = required
      @parameters[name.to_s][:description] = description
    end

    def set_system_directives_from_options
      @system_directives ||= ""
      @system_directives += <<~LIST_DIRECTIVES

        #{list_prompt}

        Your response will be a JSON array of objects. Here are the attributes the object in the array can have:

        #{attributes_list}

        Please ensure that the JSON you return is parsable and that each contained object has every required attribute or this operation will fail.

        I'll repeat this because it's important: THE JSON YOU RETURN MUST PARSE. WHAT YOU RETURN WILL BE PUT DIRECTLY IN A JSON PARSER AND LOTS OF VERY CUTE CHILDREN WILL BE VERY SAD IF IT DOESN'T PARSE
      LIST_DIRECTIVES
    end

    def attributes_list # rubocop:disable Metrics/MethodLength
      if @function
        @parameters.map do |name, attrs|
          " - \"#{name}\": #{attrs[:required] ? '(required)' : '(optional)'} #{attrs[:description]}"
        end.join("\n")
      elsif @descriptions.count.positive?
        @descriptions.map do |name, desc|
          " - \"#{name}\": #{desc}"
        end.join("\n")
      else
        "Whichever attributes will best answer the user's request"
      end
    end
  end
end
