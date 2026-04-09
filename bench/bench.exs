words = ~w(elixir erlang phoenix liveview ecto genserver supervisor otp beam
  functional programming concurrent distributed fault tolerant pattern matching
  immutable data structures processes messages mailbox binary tuple list map
  keyword module function macro behaviour protocol stream enum agent task
  registry pubsub telemetry plug cowboy bandit jason req mint finch
  mix hex rebar compile test release deploy cluster node monitor link
  spawn send receive trap exit signal pid reference port ets dets mnesia
  sqlite postgres redis memcached rabbitmq kafka nats mqtt grpc rest json
  xml html css javascript typescript react vue angular svelte tailwind
  docker kubernetes terraform ansible github gitlab actions workflow ci cd
  linux macos windows arm x86 wasm rust go python ruby java kotlin swift)

:rand.seed(:exsss, {42, 42, 42})

make_docs = fn count ->
  Enum.map(1..count, fn i ->
    word_count = Enum.random(10..100)
    text = Enum.map_join(1..word_count, " ", fn _ -> Enum.random(words) end)
    {"doc_#{i}", text}
  end)
end

sizes = [1_000, 10_000, 100_000]

indexes =
  Map.new(sizes, fn n ->
    docs = make_docs.(n)
    index = Cercatore.Index.add_all(Cercatore.new(), docs)
    {n, index}
  end)

fuzzy_opts = [fuzzy: [strategy: :jaro_winkler, threshold: 0.85]]

IO.puts("\n--- Indexing ---\n")

Benchee.run(
  Map.new(sizes, fn n ->
    {"index #{n} docs", fn -> Cercatore.Index.add_all(Cercatore.new(), make_docs.(n)) end}
  end),
  time: 5,
  memory_time: 2
)

IO.puts("\n--- Exact query ---\n")

Benchee.run(
  Map.new(sizes, fn n ->
    {"query #{n} docs", fn -> Cercatore.query(indexes[n], "elixir phoenix") end}
  end),
  time: 5
)

IO.puts("\n--- Fuzzy query ---\n")

Benchee.run(
  Map.new(sizes, fn n ->
    {"fuzzy #{n} docs", fn -> Cercatore.query(indexes[n], "elxir phonix", fuzzy_opts) end}
  end),
  time: 5
)
