#!/bin/bash
#Helper script for streamr node config file.

# Reset
Color_Off='\033[0m'       # Text Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;93m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White


# Set STREAMRPATH to ~/.streamrDocker if not already set
if [ -z "$STREAMRPATH" ]; then
    STREAMRPATH=~/.streamrDocker
fi

# Set STREAMRCONFIG to point to the default.json file
STREAMRCONFIG=$STREAMRPATH/config/default.json

# Set REPO if not already set
if [ -z "$REPO" ]; then
    REPO="streamr/broker-node"
fi
REPO_TAG="v100.0.0-testnet-one.0"

ethereumAddressPattern="^(0x)?[a-fA-F0-9]{40}$"
validate_ethereum_address() {
    if [[ $1 =~ $ethereumAddressPattern ]]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

check_operator_contract_address_exists() {
    jq -e '.plugins.operator | has("operatorContractAddress")' "$STREAMRCONFIG" > /dev/null 2>&1
}

check_privateKey_exists() {
    jq -e '.client.auth | has("privateKey")' "$STREAMRCONFIG" > /dev/null 2>&1
}

get_operator_contract_address() {
    echo $(jq -r '.plugins.operator.operatorContractAddress' "$STREAMRCONFIG")
}

set_operator_id()
{
  while true; do
      OPERATOR_ID=$(whiptail --inputbox "Enter your Operator ID" 10 60 3>&1 1>&2 2>&3)

      # Exit if cancelled
      if [ $? -ne 0 ]; then
          echo "User cancelled the input."
          OPERATOR_ID=""
          break
      fi

      # Validate the entered Ethereum address
      if [ $(validate_ethereum_address "$OPERATOR_ID") == "valid" ]; then
          echo "Valid Operator ID entered: $OPERATOR_ID"
          break
      else
          whiptail --msgbox "Invalid Ethereum address, please enter a valid address." 10 60
          OPERATOR_ID=""
      fi
  done
}

# Check if the directory and config file exist
if [ ! -d "$STREAMRPATH" ] || [ ! -f "$STREAMRCONFIG" ]; then
    # Directory or file does not exist, ask user for action
    CHOICE=$(whiptail --title "Setup Streamr" --menu "Choose an option" 15 60 3 \
    "1" "Node Testnet" \
    "2" "Mumbai Operator Node" \
    "3" "Exit" 3>&1 1>&2 2>&3)

    case "$CHOICE" in
        "1")
            echo "Setting up Testnet Operator Node..."
            mkdir -p $(dirname "$STREAMRCONFIG")
            cp config_template $STREAMRCONFIG
            chmod -R 777 $STREAMRPATH
            ;;
        "2")
            echo "Setting up Mumbai Operator Node..."
            mkdir -p $(dirname "$STREAMRCONFIG")
            wget -O "$STREAMRCONFIG" "https://docs.streamr.network/assets/files/default-f8e7b3b44d5acd8738a7d8d30fb590e5.json"
            chmod -R 777 $STREAMRPATH
            ;;
        *)
            exit 0
            ;;
    esac
fi

#Check config now exists.
if [ ! -d "$STREAMRPATH" ] || [ ! -f "$STREAMRCONFIG" ]; then
  echo -e "${Red}Fail to find $STREAMRCONFIG${Color_Off}"
  exit 1
fi

if check_operator_contract_address_exists; then
  OPERATOR_ID=$(get_operator_contract_address)
  if [ ! $(validate_ethereum_address "$OPERATOR_ID") == "valid" ]; then
      set_operator_id
      if [ -z "$OPERATOR_ID" ]; then
        echo "Failed to set Operator ID"
        exit 1
      else
        jq '.plugins.operator.operatorContractAddress = "'$OPERATOR_ID'"' "$STREAMRCONFIG" > temp.json && mv temp.json "$STREAMRCONFIG"
        echo "Updated $STREAMRCONFIG"
      fi
  fi
fi


# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null ;
}

# Check for Python and install it if it's not present
if ! command_exists python3; then
    echo "Python is not installed. Installing Python..."
    apt install python3 -y
fi

# Check for pip and install it if it's not present
if ! command_exists pip3; then
    echo "pip is not installed. Installing pip..."
    apt install python3-pip -y
fi

# Check for Web3.py and install it if it's not present
if ! pip3 list | grep -q web3; then
    echo "Web3.py is not installed. Installing Web3.py..."    
    PIP_BREAK_SYSTEM_PACKAGES=1
    pip3 install web3
fi


if check_privateKey_exists; then
  whiptail --title "Wallet" --msgbox "$(python3 walletRUN.py)" 15 50
fi

echo -e "${Yellow}Streamr configuration is complete.${Color_Off}"
