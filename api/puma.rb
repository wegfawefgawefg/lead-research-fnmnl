workers Integer(ENV.fetch("WEB_CONCURRENCY", "1"))
threads_count = Integer(ENV.fetch("RACK_MAX_THREADS", "8"))
threads threads_count, threads_count

preload_app!
port Integer(ENV.fetch("PORT", "4567"))
environment ENV.fetch("RACK_ENV", "development")

on_worker_boot do
  FnmnlDemo.connect_database if defined?(FnmnlDemo)
end
