import Config
config :konnected, Konnected,
  token: "authentication-bearer-token",
  endpoint: [
    host: :auto,
    port: 5001,
    path: "/api/konnected"
  ],
  devices: [
    [
      device_id: "807d3a3e097b",
      host: "192.168.1.235",
      port: 12065,
      sensors: [1,2,3,4,5,6],
      actuators: [out: 1],
      pwd: nil,
      notify: fn events -> IO.puts("#{inspect(events)}") end
    ],
    [
      device_id: "807d3a7f6b87",
      host: "192.168.1.234",
      port: 16350,
      sensors: [1,2,3,4],
      actuators: [],
      pwd: nil,
      notify: fn events -> IO.puts("#{inspect(events)}") end
    ]
  ]
