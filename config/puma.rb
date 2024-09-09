# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# to prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Rails server with SSL configuration
if Rails.env.development? && Socket.gethostname == 'pop-os'
  key_file = Rails.root.join("config", "certs", "localhost.key")
  cert_file = Rails.root.join("config", "certs", "localhost.cert")

  unless key_file.exist?
    root_key = OpenSSL::PKey::RSA.new(2048)
    key_file.write(root_key)

    root_cert = OpenSSL::X509::Certificate.new.tap do |root_ca|
      root_ca.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
      root_ca.serial = 0x0
      root_ca.subject = OpenSSL::X509::Name.parse "/C=BE/O=A1/OU=A/CN=localhost"
      root_ca.issuer = root_ca.subject # root CA"s are "self-signed"
      root_ca.public_key = root_key.public_key
      root_ca.not_before = Time.now
      root_ca.not_after = root_ca.not_before + 2 * 365 * 24 * 60 * 60 # 2 years validity
      root_ca.sign(root_key, OpenSSL::Digest::SHA256.new)
    end
    cert_file.write(root_cert)
  end

  ssl_bind "0.0.0.0", "8443", {
    key: key_file.to_path,
    cert: cert_file.to_path
  }
end

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
