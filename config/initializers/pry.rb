# Stolen from https://blog.bugsnag.com/production-pry/
# Show red environment name in pry prompt
old_prompt = Pry.config.prompt
env = Pry::Helpers::Text.red(Rails.env.upcase)
Pry.config.prompt = Pry::Prompt.new(
  'custom',
  'a custom prompt for EOL',
  [
    proc { |*a| "#{env} #{old_prompt.wait_proc.call(*a)}" },
    proc { |*a| "#{env} #{old_prompt.incomplete_proc.call(*a)}" }
  ],
)
