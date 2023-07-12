defmodule Examples.MagicNumbersTest do
  use ExUnit.Case, async: true

  Code.require_file("magic_numbers.exs", __DIR__)
  alias Examples.MagicNumbers

  alias OrbWasmtime.Wasm

  describe "MobileThrottling" do
    alias MagicNumbers.MobileThrottling

    test "byte size vs json" do
      assert byte_size(Wasm.to_wasm(MobileThrottling)) == 168

      assert byte_size(
               Jason.encode!(%{
                 slow_3g_latency_ms: 2000,
                 slow_3g_download: 50_000,
                 slow_3g_upload: 50_000,
                 fast_3g_latency_ms: 563,
                 fast_3g_download: 180_000,
                 fast_3g_upload: 84_375
               })
             ) == 149
    end

    @tag :skip
    test "opt" do
      path_wasm = Path.join(__DIR__, "mobile_throttling.wasm")
      path_wat = Path.join(__DIR__, "mobile_throttling.wat")
      path_opt_wasm = Path.join(__DIR__, "mobile_throttling_OPT.wasm")
      path_opt_wat = Path.join(__DIR__, "mobile_throttling_OPT.wat")
      wasm = Wasm.to_wasm(URLEncoding)
      File.write!(path_wasm, wasm)
      System.cmd("wasm-opt", [path_wasm, "-o", path_opt_wasm, "-O"])

      %{size: size} = File.stat!(path_opt_wasm)
      assert size == 408

      {wat, 0} = System.cmd("wasm2wat", [path_wasm])
      File.write!(path_wat, wat)
      {opt_wat, 0} = System.cmd("wasm2wat", [path_opt_wasm])
      File.write!(path_opt_wat, opt_wat)
    end
  end

  # byte_size(Wasm.to_wasm(URLEncoding)) |> dbg()
end
