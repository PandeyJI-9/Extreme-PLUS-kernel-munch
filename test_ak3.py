import ssl
ssl._create_default_https_context = ssl._create_unverified_context
import urllib.request

urls = [
    "https://raw.githubusercontent.com/Rohail33/Realking_xiaomi_sm8250/munch/anykernel.sh",
    "https://raw.githubusercontent.com/Rohail33/Realking_xiaomi_sm8250/main/anykernel.sh",
    "https://raw.githubusercontent.com/UtsavBalar1231/AnyKernel3/master/anykernel.sh"
]

for url in urls:
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            content = response.read().decode('utf-8')
            print(f"--- SUCCESS: {url} ---")
            for line in content.split('\n'):
                if line.startswith('block=') or line.startswith('is_slot_device='):
                    print(line.strip())
            break
    except Exception as e:
        print(f"Failed {url}: {e}")
