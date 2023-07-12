defmodule Examples.MagicNumbers do
  defmodule MobileThrottling do
    use Orb

    I32.export_global(:readonly,
      slow_3g_latency_ms: 2000,
      slow_3g_download: 50_000,
      slow_3g_upload: 50_000
    )

    I32.export_global(:readonly,
      fast_3g_latency_ms: 563,
      fast_3g_download: 180_000,
      fast_3g_upload: 84_375
    )

    wasm do
    end
  end
end
