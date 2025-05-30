defmodule Examples.WasiTest do
  use ExUnit.Case, async: true

  # TODO: Migrate to Wasmex - needs implementation of:
  # - Instance.run with WASI imports
  # - Instance.capture for function references
  # - Instance.read_memory for memory operations
  # - WASI function imports and handling
  require TestHelper

  Code.require_file("wasi.exs", __DIR__)
  alias Examples.ClockConsumer

  # test "clock" do
  #   # TODO: switch to wasmex
  #   inst =
  #     Instance.run(ClockConsumer, [
  #       {:wasi_unstable, :clock_res_get,
  #        fn _caller, _clockid, _address ->
  #          # Instance.Caller.write_string_nul_terminated(caller, address, )
  #          WasiUnstable.esuccess()
  #        end},
  #       {:wasi_unstable, :clock_time_get,
  #        fn _caller, _clockid, _precision, _address ->
  #          WasiUnstable.esuccess()
  #        end}
  #     ])

  #   get_seconds = Instance.capture(inst, :get_seconds, 0)
  #   read = &Instance.read_memory(inst, &1, 8)

  #   get_seconds.()
  #   assert read.(0x100) == "\0\0\0\0\0\0\0\0"
  # end
end
