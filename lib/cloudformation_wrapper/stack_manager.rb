module CloudFormationWrapper
  # Stack Manager Class
  # Class containing static convenience methods for deploying and managing CloudFormation Stacks.
  # @since 1.0
  class StackManager
    def self.self.deploy(options)
      unless options[:client]
        access_key_id = options[:access_key_id] || ENV['AWS_ACCESS_KEY_ID'] || ENV['ACCESS_KEY'] ||
                        raise(ArgumentError, 'Cannot find AWS Access Key ID.')

        secret_access_key = options[:secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY'] || ENV['SECRET_KEY'] ||
                            raise(ArgumentError, 'Cannot find AWS Secret Key.')

        credentials = Aws::Credentials.new(access_key_id, secret_access_key)
      end

      region = options[:region] || ENV['AWS_REGION'] || ENV['AMAZON_REGION'] || ENV['AWS_DEFAULT_REGION'] ||
               raise(ArgumentError, 'Cannot find AWS Region.')

      verified_options = verify_options(options)

      cf_client = verified_options[:client] || Aws::CloudFormation::Client.new(credentials: credentials, region: region)

      ensure_template_file_exists(verified_options[:template_path], cf_client)

      deploy_stack(
        verified_options[:parameters],
        verified_options[:name],
        verified_options[:template_path],
        verified_options[:wait_for_stack],
        cf_client
      )
    end

    private

    def self.verify_options(options)
      defaults = {
        description: 'Deployed with CloudFormation Wrapper.', parameters: {}, wait_for_stack: true
      }

      options_with_defaults = options.reverse_merge(defaults)

      unless options_with_defaults[:template_path] && (options_with_defaults[:template_path].is_a? String)
        raise ArgumentError, 'template_path must be provided (String)'
      end

      unless options_with_defaults[:parameters] && (options_with_defaults[:parameters].is_a? Hash)
        raise ArgumentError, 'parameters must be provided (Hash)'
      end

      unless options_with_defaults[:client] && (options_with_defaults[:client].is_a? Aws::CloudFormation::Client)
        raise ArgumentError, 'If you\'re providing a client, it must be an Aws::CloudFormation::Client.'
      end

      return if options_with_defaults[:name] && (options_with_defaults[:name].is_a? String)
      raise ArgumentError, 'name must be provided (String)'
    end

    def self.ensure_template_file_exists(template_path, cf_client)
      raise ArgumentError, 'CF Template File does not exist.' unless File.file?(template_path)
      cf_client.validate_template(template_body: File.read(template_path))
      puts 'Valid Template File.'
    end

    def self.deploy_stack(parameters, stack_name, template_path, cf_client, _wait)
      template_parameters = construct_template_parameters(parameters)
      client_token = ENV.fetch('BUILD_NUMBER', SecureRandom.uuid.delete('-'))
      old_stack = describe_stack(stack_name, cf_client)
      change_set_type = old_stack ? 'UPDATE' : 'CREATE'

      create_change_set_params = {
        stack_name: stack_name,
        template_body: File.read(template_path),
        parameters: template_parameters,
        change_set_name: "ChangeSet-#{client_token}",
        client_token: client_token,
        description: ENV.fetch('BUILD_TAG', 'Stack Updates.'),
        change_set_type: change_set_type
      }

      change_set_id = cf_client.create_change_set(create_change_set_params).id

      unless wait_for_stack_change_set_creation(change_set_id, cf_client)
        puts "No changes required for #{stack_name}"
        delete_change_set(change_set_id, cf_client)
        return return_outputs(old_stack)
      end

      list_changes(change_set_id, cf_client)
      time_change_set_executed = Time.now
      execute_change_set(change_set_id, cf_client)
      updated_stack = wait_for_stack_to_complete(stack_name, time_change_set_executed, cf_client)
      if updated_stack.stack_status == 'CREATE_COMPLETE' || updated_stack.stack_status == 'UPDATE_COMPLETE'
        puts "Stack finished updating: #{updated_stack.stack_status}"
      else
        puts "Stack failed to update: #{updated_stack.stack_status} (#{updated_stack.stack_status_reason})"
        return false
      end
      return_outputs(updated_stack)
    end

    def self.construct_template_parameters(parameters)
      template_parameters = []
      parameters.each do |k, v|
        template_parameters.push(
          parameter_key: k.to_s,
          parameter_value: v.to_s
        )
      end
      template_parameters
    end

    def self.describe_stack(stack_name, cf_client)
      response = cf_client.describe_stacks(stack_name: stack_name)
      return false if response.stacks.length != 1
      return response.stacks[0]
    rescue Aws::CloudFormation::Errors::ServiceError
      return false
    end

    def self.wait_for_stack_change_set_creation(change_set_id, cf_client)
      polling_period = 1 # second

      puts "Waiting for the Change Set (#{change_set_id}) to be reviewed..."

      loop do
        sleep(polling_period)
        response = cf_client.describe_change_set(change_set_name: change_set_id)
        if response.status == 'CREATE_COMPLETE'
          puts "Change Set (#{change_set_id}) created."
          return true
        end
        if response.status == 'FAILED'
          puts "Change Set (#{change_set_id}) creation failed: #{response.status_reason}"
          return false
        end
        puts '...'
      end
    end

    def self.list_changes(change_set_id, cf_client)
      response = cf_client.describe_change_set(change_set_name: change_set_id)
      puts
      puts 'Stack Set Changes:'
      response.changes.each do |change|
        resource_change = change.resource_change
        puts "\t#{resource_change.action} - " \
          "#{resource_change.logical_resource_id} " \
          "aka #{resource_change.physical_resource_id} " \
          "(#{resource_change.resource_type})"
        puts "\t\tScope: #{resource_change.scope}"
        puts "\t\tReplacment: #{resource_change.replacement}"
        puts "\t\tDetails:"
        resource_change.details.each do |detail|
          puts "\t\t\tTarget: #{detail.target.attribute} - " \
            "#{detail.target.name} - " \
            "recreate:#{detail.target.requires_recreation}"
          puts "\t\t\tCaused By: #{detail.causing_entity}"
          puts "\t\t\tChange Source: #{detail.change_source}"
        end
      end
      puts
    end

    def self.execute_change_set(change_set_id, cf_client)
      puts 'Executing Change Set...'

      client_token = ENV.fetch('BUILD_NUMBER', SecureRandom.uuid.delete('-'))

      cf_client.execute_change_set(change_set_name: change_set_id, client_request_token: client_token)
    end

    def self.wait_for_stack_to_complete(stack_name, minimum_timestamp_for_events, cf_client)
      timestamp_width = 30
      logical_resource_width = 40
      resource_status_width = 40
      polling_period = 3 # seconds
      most_recent_event_id = ''

      puts
      puts "#{'Timestamp'.ljust(timestamp_width)} " \
      "#{'Logical Resource Id'.ljust(logical_resource_width)} " \
      "#{'Status'.ljust(resource_status_width)} "

      puts "#{'-'.center(timestamp_width, '-')} " \
        "#{'-'.center(logical_resource_width, '-')} " \
        "#{'-'.center(resource_status_width, '-')}"

      stack = {}
      loop do
        sleep(polling_period)
        stack = describe_stack(stack_name, cf_client)
        events = get_latest_events(stack_name, minimum_timestamp_for_events, most_recent_event_id, cf_client)
        most_recent_event_id = events[0].event_id unless events.empty?
        events.reverse_each do |event|
          line = "#{event.timestamp.to_s.ljust(timestamp_width)} " \
          "#{event.logical_resource_id.ljust(logical_resource_width)} " \
          "#{event.resource_status.ljust(resource_status_width)} "
          if !event.resource_status.end_with?('IN_PROGRESS') && !event.resource_status_reason.nil?
            line << event.resource_status_reason
          end
          puts line
        end
        break unless stack.stack_status.end_with?('IN_PROGRESS')
      end
      stack
    end

    def self.get_latest_events(stack_name, minimum_timestamp_for_events, most_recent_event_id, cf_client)
      no_new_events = false
      response = nil
      events = []
      loop do
        params = {
          stack_name: stack_name
        }

        params[:next_token] = response.next_token unless response.nil?

        response = cf_client.describe_stack_events(params)

        response.stack_events.each do |event|
          if (event.event_id == most_recent_event_id) || (event.timestamp < minimum_timestamp_for_events)
            no_new_events = true
            break
          end
          events << event
        end

        break if no_new_events || !response.next_token
      end
      events
    end

    def self.return_outputs(stack)
      return if stack.outputs.empty?

      output_name_width = 30
      output_value_width = 50

      outputs = {}

      puts '   '
      puts "#{'Output Name'.ljust(output_name_width)} " \
        "#{'Value'.ljust(output_value_width)} "
      puts "#{'-'.center(output_name_width, '-')} #{'-'.center(output_value_width, '-')}"

      stack.outputs.each do |output|
        outputs[output.output_key.to_sym] = output.output_value
        puts "#{output.output_key.ljust(output_name_width)} #{output.output_value.ljust(output_value_width)}"
      end

      puts '   '
      outputs
    end
  end
end
