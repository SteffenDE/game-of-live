import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  app_name = System.get_env("FLY_APP_NAME")

  config :game_of_live, GameOfLiveWeb.Endpoint,
    server: true,
    http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")],
    url: [
      scheme: System.get_env("PUBLIC_SCHEME") || "http",
      host:
        if(app_name, do: "#{app_name}.fly.dev", else: System.get_env("PUBLIC_HOST") || "localhost"),
      port: String.to_integer(System.get_env("PUBLIC_PORT") || "80")
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :game_of_live, GameOfLiveWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end
