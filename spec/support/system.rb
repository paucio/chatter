RSpec.configure do |config|
  # System specs render real CSS; make sure the Tailwind build is up to date.
  config.before(:suite) do
    if RSpec.configuration.files_to_run.any? { |f| f.include?("/spec/system/") }
      print "Building Tailwind CSS for system specs... "
      system("bin/rails", "tailwindcss:build", out: File::NULL) or abort("tailwindcss:build failed")
      puts "done"
    end
  end

  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

    # Turbo Stream broadcasts run through Active Job + Action Cable. Run jobs
    # inline so the broadcast fires during the request and reaches the browser's
    # /cable connection (cable.yml uses the async adapter in test).
    ActiveJob::Base.queue_adapter = :inline
  end
end
