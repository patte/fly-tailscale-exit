#!/usr/bin/env python3

import os
import requests

from dotenv import load_dotenv
load_dotenv()


# Environment variables.
TS_API_DOMAIN = os.getenv("TS_API_DOMAIN")
TS_TAG = os.getenv("TS_TAG")
TS_API_TOKEN = os.getenv("TS_API_TOKEN")

# Endponts.
API_ENDPOINT = f"https://api.tailscale.com/api/v2"
API_DEVICE_ENDPOINT = f"{API_ENDPOINT}/device"
API_TAILNET_ENDPOINT = f"{API_ENDPOINT}/tailnet/{TS_API_DOMAIN}"

# Fly.io Regions <https://fly.io/docs/reference/regions/#fly-io-regions>.
# Region ID: (Region Location, WireGuard Gateway)
FLY_IO_REGIONS = {
    "ams": ("Amsterdam, Netherlands", True),
    "cdg": ("Paris, France", True),
    "dfw": ("Dallas, TX, USA", True),
    "ewr": ("Secaucus, NJ, USA", False),
    "fra": ("Frankfurt, Germany", True),
    "gru": ("Sao Paulo, Brazil", False),
    "hkg": ("Hong Kong, China", True),
    "iad": ("Ashburn, VA, USA", False),
    "lax": ("Los Angeles, CA, USA", True),
    "lhr": ("London, United Kingdom", True),
    "maa": ("Chennai, India", True),
    "mad": ("Madrid, Spain", False),
    "mia": ("Miami, FL, USA", False),
    "nrt": ("Tokyo, Japan", True),
    "ord": ("Chicago, IL, USA", True),
    "scl": ("Santiago, Chile", True),
    "sea": ("Seattle, WA, USA", True),
    "sin": ("Singapore, Singapore", True),
    "sjc": ("Sunnyvale, CA, USA", True),
    "syd": ("Sydney, Australia", True),
    "yul": ("Montreal, Canada", False),
    "yyz": ("Toronto, Canada", True),
}


def get_fly_io_exit_routes() -> dict:
    """
    API Documentation: <https://github.com/tailscale/tailscale/blob/main/api.md#tailnet-devices>.
    :return: dict{"hostname": "id"}.
    """
    response = requests.get(f"{API_TAILNET_ENDPOINT}/devices",
                            auth=requests.auth.HTTPBasicAuth(TS_API_TOKEN, "")).json()

    devices = {}

    for device in response["devices"]:
        # Only match machines both have expected ACL tag and is in Fly.io region.
        if TS_TAG in device["tags"] and device["hostname"][-3:] in FLY_IO_REGIONS:
            devices[device["hostname"]] = device["id"]

    return devices


def delete_device(device_id: str) -> int:
    """
    API Documentation: <https://github.com/tailscale/tailscale/blob/main/api.md#device-delete>.
    :return: status.
    """
    return requests.delete(f"{API_DEVICE_ENDPOINT}/{device_id}",
                           auth=requests.auth.HTTPBasicAuth(TS_API_TOKEN, "")).status_code


def main() -> int:
    """
    :return: status.
    """
    print("Checking existing exit routes on Tailnet...")
    devices = get_fly_io_exit_routes()
    for hostname in devices.keys():
        print(f"\tFound an exit route in {FLY_IO_REGIONS[hostname[-3:]][0]}.")
    print(f"Total: {len(devices)} exit routes.")

    print("Cleaning up...")
    for hostname, id in devices.items():
        print(f"\tDeleting exit route in {FLY_IO_REGIONS[hostname[-3:]][0]}:\n"
              f"\tStatus code: {delete_device(id)}.")

    if len(get_fly_io_exit_routes()) != 0:
        print("Something went wrong, existing VPN machines were not deleted successfully.")
        return 1
    else:
        print("All existing VPN machines were deleted successfully.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
