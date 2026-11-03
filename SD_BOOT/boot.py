"""SD startup: initialize PL clock and load the verified car; never start motors."""
from pathlib import Path
import hashlib
import json
import time

root = Path(__file__).resolve().parent
payload = root / 'car_zebra_final'
status_file = payload / 'boot_status.json'
status = {'loaded': False, 'started_epoch': time.time()}
try:
    manifest = json.loads((payload / 'manifest.json').read_text())
    bitfile = payload / manifest['bitfile']
    actual = hashlib.sha256(bitfile.read_bytes()).hexdigest()
    if actual != manifest['sha256']:
        raise RuntimeError('Car bitstream checksum mismatch')
    from pynq import Bitstream, Clocks
    # Linux/FSBL already initialized PS. Never run XSDB system reset here.
    Clocks.fclk0_mhz = 125.0
    before = float(Clocks.fclk0_mhz)
    if abs(before - 125.0) > 0.5:
        raise RuntimeError('Cannot establish 125 MHz FCLK0: {}'.format(before))
    Bitstream(str(bitfile)).download()
    after = float(Clocks.fclk0_mhz)
    if abs(after - 125.0) > 0.5:
        raise RuntimeError('FCLK0 changed during load: {}'.format(after))
    state = Path('/sys/class/fpga_manager/fpga0/state')
    status.update(loaded=True, version=manifest['version'], bitfile=bitfile.name,
                  sha256=actual, fclk0_mhz=after,
                  fpga_state=state.read_text().strip() if state.exists() else 'unavailable')
    print('CAR_ZEBRA_FINAL_READY: BTN0 reset, BTN1 start/stop, BTN2 emergency stop; zebra dwell 1.5s', flush=True)
except Exception as exc:
    status['error'] = repr(exc)
    print('CAR_ZEBRA_FINAL_FAILED: ' + repr(exc), flush=True)
    raise
finally:
    try:
        status_file.write_text(json.dumps(status, indent=2))
    except Exception as exc:
        print('CAR_STATUS_WRITE_FAILED: ' + repr(exc), flush=True)
