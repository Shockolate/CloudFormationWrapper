require 'cloudformation_wrapper/version'

require 'aws-sdk-cloudformation'
Aws.use_bundled_cert!
require 'active_support/core_ext/hash'

require 'cloudformation_wrapper/stack_manager'

STDOUT.sync
STDERR.sync
