import base64

# Two Hex strings provided in the challenge
hex_line1 = "4d 48 67 33 5a 44 45 31 59 6d 4a 68 4d 6a 5a 6a 4e 54 49 7a 4e 6a 67 7a 59 6d 5a 6a 4d 32 52 6a 4e 32 4e 6b 59 7a 56 6b 4d 57 49 34 59 54 49 33 4e 44 51 30 4e 44 63 31 4f 54 64 6a 5a 6a 52 6b 59 54 45 33 4d 44 56 6a 5a 6a 5a 6a 4f 54 6b 7a 4d 44 59 7a 4e 7a 51 30"
hex_line2 = "4d 48 67 32 4f 47 4a 6b 4d 44 49 77 59 57 51 78 4f 44 5a 69 4e 6a 51 33 59 54 59 35 4d 57 4d 32 59 54 56 6a 4d 47 4d 78 4e 54 49 35 5a 6a 49 78 5a 57 4e 6b 4d 44 6c 6b 59 32 4d 30 4e 54 49 30 4d 54 51 77 4d 6d 46 6a 4e 6a 42 69 59 54 4d 33 4e 32 4d 30 4d 54 55 35"

def decode_private_key(hex_str):
    # 1. Remove whitespace and convert Hex to Base64 string
    clean_hex = hex_str.replace(" ", "")
    base64_str = bytes.fromhex(clean_hex).decode('utf-8')
    
    # 2. Base64 decode -> Results in an ASCII-formatted Hex private key string
    raw_bytes = base64.b64decode(base64_str)
    
    # 3. Decode raw bytes directly into a utf-8 string
    return raw_bytes.decode('utf-8')

pk1 = decode_private_key(hex_line1)
pk2 = decode_private_key(hex_line2)

print("私钥 1:", pk1)
print("私钥 2:", pk2)