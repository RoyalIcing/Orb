defmodule Examples.MagicNumbers do
  defmodule MobileThrottling do
    use Orb

    # TODO: should it be called `const :export do` ?
    global :export_readonly do
      @slow_3g_latency_ms 2000
      @slow_3g_download 50_000
      @slow_3g_upload 50_000
    end

    global :export_readonly do
      @fast_3g_latency_ms 563
      @fast_3g_download 180_000
      @fast_3g_upload 84_375
    end
  end
end
