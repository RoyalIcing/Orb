defmodule WasiUnstable do
  use Orb.Import

  def esuccess, do: 0

  defmodule ClockID do
    defdelegate wasm_type, to: Orb.I32

    # export const CLOCKID_REALTIME = 0;
    # export const CLOCKID_MONOTONIC = 1;
    # export const CLOCKID_PROCESS_CPUTIME_ID = 2;
    # export const CLOCKID_THREAD_CPUTIME_ID = 3;
    def realtime, do: 0
    def monotonic, do: 1
    def process_cputime_id, do: 2
    def thread_cputime_id, do: 3
  end

  defw(clock_res_get(clockid: I32, address: I32.UnsafePointer), I32)
  defw(clock_time_get(clockid: I32, precision: I64, address: I32.UnsafePointer), I32)
end

defmodule Examples.ClockConsumer do
  use Orb

  Memory.pages(1)

  Orb.importw(WasiUnstable, :wasi_unstable)

  defw get_seconds, I32 do
    0
  end
end
