# frozen_string_literal: true

# Legacy elasticsearch.rake - redirects to new elasticsearch_v8.rake tasks
#
# The old elasticsearch-rails import tasks are no longer available.
# Use the new elasticsearch namespace tasks instead:
#
#   rake elasticsearch:status
#   rake elasticsearch:full_reindex
#   rake elasticsearch:verify_sync
#
# See lib/tasks/elasticsearch_v8.rake for all available tasks.
