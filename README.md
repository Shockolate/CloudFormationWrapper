# CloudFormation Wrapper

A ruby library to simplify management and deployments of AWS CloudFormation Stacks.

## Description

This gem provides helper methods for deployments of CloudFormation Stacks.

## Installation

_Recommended:_ Use Bundler for all your Ruby projects!
Add the cloudformation_wrapper to your Gemfile:

```ruby
  gem 'cloudformation_wrapper'
```

Or install globally using RubyGems:

```bash
gem install cloudformation_wrapper
```

## Using CloudFormationWrapper

Use the static deploy method within the `CloudFormationWrapper::StackManager` to deploy a CloudFormation Stack.

CloudFormationWrapper uses the AWS SDK to manage CloudFormation stacks. Therefore, it utilizes the `Aws::CloudFormation::Client` for integration. You can provide the client yourself, pass in the credentials, or it will try to read them from Environment Variables. See the [Credential Provider Chain](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html) for more details.

```ruby
CloudFormationWrapper::StackManager.deploy(
  region: 'us-east-1',
  template_path: '/path/to/template/file',
  name: 'MyCloudFormationStack',
  parameters: {
    StackEnvironment: 'production',
    CreateS3Bucket: true,
    OtherTemplateParameter: 'TemplateParameterValue'
  },
  wait_for_stack: true
)
```