import urllib.request
import ssl

ssl._create_default_https_context = ssl._create_unverified_context

url = "https://raw.githubusercontent.com/Poco-F4-munch/AnyKernel3/munch/anykernel.sh"
try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        for line in content.split('\n'):
            if line.startswith('block=') or line.startswith('is_slot_device='):
                print(line.strip())
except Exception as e:
    print(f"Failed {url}: {e}")

url2 = "https://raw.githubusercontent.com/Poco-F4-munch/AnyKernel3/master/anykernel.sh"
try:
    req = urllib.request.Request(url2)
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
        for line in content.split('\n'):
            if line.startswith('block=') or line.startswith('is_slot_device='):
                print(line.strip())
except Exception as e:
    print(f"Failed {url2}: {e}")
