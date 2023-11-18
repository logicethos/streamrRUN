# wallet.py [config file]
# This will read the streamr config file for it's private key.
# It will return the public key, and it's balance of MATIC.
# If there is no private key, it will generate one for you.
#
# For secrity, only fund the account with enough MATIC as required.

import sys
import json
from web3 import Web3, Account
from pathlib import Path


def get_private_key_and_url_from_json(file_path):
    with open(file_path, 'r') as file:
        data = json.load(file)
        private_key = data['client']['auth']['privateKey']
        url = data['client']['contracts']['mainChainRPCs']['rpcs'][0]['url']
        return private_key, url

def get_public_key_and_balance(private_key, w3):
    account = Account.from_key(private_key)
    balance = w3.eth.get_balance(account.address)
    readable_balance = w3.from_wei(balance, 'ether')
    return account.address, readable_balance

def validate_or_create_private_key(private_key, file_path):
    try:
        # Attempt to create an account from the private key
        Account.from_key(private_key)
        return private_key
    except ValueError as e:
        # Catch specific exception related to invalid private key format
        print("Invalid private key format or not set - creating")
        new_account = Account.create()
        new_private_key = new_account.key.hex()  # Use .key.hex() instead of .privateKey.hex()
        update_json_file_with_new_key(file_path, new_private_key)
        return new_private_key

def update_json_file_with_new_key(file_path, new_private_key):
    with open(file_path, 'r+') as file:
        data = json.load(file)
        data['client']['auth']['privateKey'] = new_private_key
        file.seek(0)
        json.dump(data, file, indent=4)
        file.truncate()

def main():
    # Check if a command line argument is provided for the config path
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    else:
        home = str(Path.home())
        config_path = f'{home}/.streamrDocker/config/default.json'

    private_key, rpc_url = get_private_key_and_url_from_json(config_path)

    # Validate or create a new private key
    private_key = validate_or_create_private_key(private_key, config_path)

    # Connect to the Polygon (MATIC) network node
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    
    # Verify connection
    if not w3.is_connected():
        print("Failed to connect to the Polygon network")
        return

    public_key, matic_balance = get_public_key_and_balance(private_key, w3)
    print("Public Key:", public_key)
    print("MATIC Balance:", matic_balance, "MATIC")

if __name__ == "__main__":
    main()
