import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :game_of_live, GameOfLiveWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "2Lcw2+IZlmNSDiMBc3GyFo72K5SgobkNND2Fs7yTMyyTjgtDoJruJmQfKt05GXzN",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
