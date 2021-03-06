#!/usr/bin/env bash
# chmod +x ./reset_std_token_infrablockchain_testnet_on_server_side.sh

setopt shwordsplit

INFRA_NODE_BIN_NAME=infra-node
INFRA_CLI_BIN_NAME=infra-cli
INFRA_KEYSTORE_BIN_NAME=infra-keystore
INFRABLOCKCHAIN_HOME=/mnt/infrablockchain-git
INFRA_NODE=$INFRABLOCKCHAIN_HOME/build/programs/$INFRA_NODE_BIN_NAME/$INFRA_NODE_BIN_NAME
INFRA_NODE_LOG_FILE=/mnt/$INFRA_NODE_BIN_NAME.log
INFRA_CLI="$INFRABLOCKCHAIN_HOME/build/programs/$INFRA_CLI_BIN_NAME/$INFRA_CLI_BIN_NAME --wallet-url http://127.0.0.1:8900/"
INFRA_CLI_TESTNET="$INFRA_CLI -u http://testnet-sentinel.yosemitelabs.org:8888"
INFRA_CLI_TESTNET_V1="$INFRA_CLI -u http://testnet.yosemitelabs.org:8888"
INFRA_KEYSTORE=$INFRABLOCKCHAIN_HOME/build/programs/$INFRA_KEYSTORE_BIN_NAME/$INFRA_KEYSTORE_BIN_NAME
INFRA_KEYSTORE_LOG_FILE=/mnt/$INFRA_KEYSTORE_BIN_NAME.log
INFRA_KEYSTORE_WALLET_PASSWORD=PW5Jrpn9S5ygoA9r2bv47rv9gH2jVjntdyHWKL4QdoKVFRz6U17EM
INFRA_NODE_CONFIG=$INFRABLOCKCHAIN_HOME/infrablockchain_config/config_infrablockchain_testnet_boot.ini
INFRA_NODE_GENESIS_JSON=$INFRABLOCKCHAIN_HOME/infrablockchain_config/genesis_infrablockchain_testnet.json
INFRA_NODE_DATA_DIR=/mnt/INFRA_NODE_data
INFRABLOCKCHAIN_DEV_WALLET_DIR=/mnt/infrablockchain_dev_wallet
INFRABLOCKCHAIN_CONTRACTS_DIR=$INFRABLOCKCHAIN_HOME/build/contracts
INFRABLOCKCHAIN_MONGOD=/home/ubuntu/opt/mongodb/bin/mongod
INFRABLOCKCHAIN_MONGODB_CONFIG=/home/ubuntu/opt/mongodb/mongod.conf
INFRABLOCKCHAIN_MONGODB_DATA_DIR=/mnt/mongodb

INFRA_NODE_API_ENDPOINT=http://localhost:8888

{ set +x; } 2>/dev/null
red=`tput setaf 1`
green=`tput setaf 2`
magenta=`tput setaf 6`
reset=`tput sgr0`
set -x

{ set +x; } 2>/dev/null
echo "${red}[Resetting INFRABLOCKCHAIN Testnet]${reset}"
echo
echo "${green}INFRABLOCKCHAIN_HOME${reset}=${red}$INFRABLOCKCHAIN_HOME${reset}"
echo "${green}INFRA_NODE${reset}=${red}$INFRA_NODE${reset}"
echo "${green}INFRA_NODE_LOG_FILE${reset}=${red}$INFRA_NODE_LOG_FILE${reset}"
echo "${green}INFRA_CLI${reset}=${red}$INFRA_CLI${reset}"
echo "${green}INFRA_CLI_TESTNET${reset}=${red}$INFRA_CLI_TESTNET${reset}"
echo "${green}INFRA_KEYSTORE${reset}=${red}$INFRA_KEYSTORE${reset}"
echo "${green}INFRA_KEYSTORE_LOG_FILE${reset}=${red}$INFRA_KEYSTORE_LOG_FILE${reset}"
echo "${green}INFRA_KEYSTORE_WALLET_PASSWORD${reset}=${red}$INFRA_KEYSTORE_WALLET_PASSWORD${reset}"
echo "${green}INFRA_NODE_CONFIG${reset}=${red}$INFRA_NODE_CONFIG${reset}"
echo "${green}INFRA_NODE_GENESIS_JSON${reset}=${red}$INFRA_NODE_GENESIS_JSON${reset}"
echo "${green}INFRA_NODE_DATA_DIR${reset}=${red}$INFRA_NODE_DATA_DIR${reset}"
echo "${green}INFRABLOCKCHAIN_DEV_WALLET_DIR${reset}=${red}$INFRABLOCKCHAIN_DEV_WALLET_DIR${reset}"
echo "${green}INFRABLOCKCHAIN_CONTRACTS_DIR${reset}=${red}$INFRABLOCKCHAIN_CONTRACTS_DIR${reset}"
echo "${green}INFRABLOCKCHAIN_MONGOD${reset}=${red}$INFRABLOCKCHAIN_MONGOD${reset}"
echo "${green}INFRABLOCKCHAIN_MONGODB_CONFIG${reset}=${red}$INFRABLOCKCHAIN_MONGODB_CONFIG${reset}"
echo "${green}INFRABLOCKCHAIN_MONGODB_DATA_DIR${reset}=${red}$INFRABLOCKCHAIN_MONGODB_DATA_DIR${reset}"
echo
set -x

{ set +x; } 2>/dev/null
echo "${red}Really want to reset Testnet node data?${reset}"
echo "${red}[WARNING] all data including infra-node data and mongo db data will be deleted permanantely.${reset}"
echo "write YES to proceed reset process."
read USER_CONFIRM_TO_PROCEED
if [ "$USER_CONFIRM_TO_PROCEED" != "YES" ]; then
  exit 1
fi
set -x

print_section_title() {
  { set +x; } 2>/dev/null
  echo
  echo "${green}[$1]${reset}"
  echo
  set -x
}

{ print_section_title "Reset infra-node data"; } 2>/dev/null

pgrep $INFRA_NODE_BIN_NAME
pkill -SIGINT $INFRA_NODE_BIN_NAME
sleep 5

du -sh $INFRA_NODE_DATA_DIR
rm -rf $INFRA_NODE_DATA_DIR
mkdir $INFRA_NODE_DATA_DIR


{ print_section_title "Reset mongo db data"; } 2>/dev/null

pgrep mongod
pkill -SIGINT mongod
sleep 5

du -sh $INFRABLOCKCHAIN_MONGODB_DATA_DIR
rm -rf $INFRABLOCKCHAIN_MONGODB_DATA_DIR
mkdir $INFRABLOCKCHAIN_MONGODB_DATA_DIR
mkdir $INFRABLOCKCHAIN_MONGODB_DATA_DIR/data
mkdir $INFRABLOCKCHAIN_MONGODB_DATA_DIR/log

$INFRABLOCKCHAIN_MONGOD -f $INFRABLOCKCHAIN_MONGODB_CONFIG --logpath $INFRABLOCKCHAIN_MONGODB_DATA_DIR/log/mongodb.log --dbpath $INFRABLOCKCHAIN_MONGODB_DATA_DIR/data --bind_ip 127.0.0.1 --port 27017 --fork

sleep 5


{ print_section_title "Restart key daemon"; } 2>/dev/null

pgrep $INFRA_KEYSTORE_BIN_NAME
pkill -SIGINT $INFRA_KEYSTORE_BIN_NAME
sleep 5
nohup $INFRA_KEYSTORE --unlock-timeout 999999999 --http-server-address 127.0.0.1:8900 --wallet-dir $INFRABLOCKCHAIN_DEV_WALLET_DIR > $INFRA_KEYSTORE_LOG_FILE 2>&1&
sleep 10
tail -n 300 $INFRA_KEYSTORE_LOG_FILE

#$INFRA_CLI wallet create --to-console
#Creating wallet: default
#Save password to use in the future to unlock this wallet.
#Without password imported keys will not be retrievable.
#"PW5KdHLJYdrhiARnhK8b6JrSuxuZnDYQYBTEh9RMyBpBQo9QPfEdE"
$INFRA_CLI wallet open
$INFRA_CLI wallet unlock --password $INFRA_KEYSTORE_WALLET_PASSWORD

# infrablockchain initial key
#$INFRA_CLI create key --to-console
$INFRA_CLI wallet import --private-key PVT_K1_VwEM9o5KsqdLs5jgHucBcE3PFbu1kk3fH2wbjRGve4QPzvScR


{ print_section_title "Start infra-node from genesis"; } 2>/dev/null

nohup $INFRA_NODE --config $INFRA_NODE_CONFIG --genesis-json $INFRA_NODE_GENESIS_JSON --data-dir $INFRA_NODE_DATA_DIR > $INFRA_NODE_LOG_FILE 2>&1&
sleep 10
tail -n 300 $INFRA_NODE_LOG_FILE
pgrep $INFRA_NODE_BIN_NAME
pkill -SIGINT $INFRA_NODE_BIN_NAME
sleep 5
$INFRA_NODE --print-genesis-json --config $INFRA_NODE_CONFIG --data-dir $INFRA_NODE_DATA_DIR

nohup $INFRA_NODE --config $INFRA_NODE_CONFIG --data-dir $INFRA_NODE_DATA_DIR > $INFRA_NODE_LOG_FILE 2>&1&
sleep 10
tail -n 300 $INFRA_NODE_LOG_FILE


{ print_section_title "Create System Accounts"; } 2>/dev/null

$INFRA_CLI create account infrasys sys.tokenabi PUB_K1_73E1bUPyVMTb7gjvvhk3bhR1YnKi6TtzgJUL3Ykea8QGU1ZLfR -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys sys.txfee PUB_K1_73E1bUPyVMTb7gjvvhk3bhR1YnKi6TtzgJUL3Ykea8QGU1ZLfR -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys sys.msig PUB_K1_73E1bUPyVMTb7gjvvhk3bhR1YnKi6TtzgJUL3Ykea8QGU1ZLfR -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys sys.identity PUB_K1_73E1bUPyVMTb7gjvvhk3bhR1YnKi6TtzgJUL3Ykea8QGU1ZLfR -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys yx.dcontract PUB_K1_73E1bUPyVMTb7gjvvhk3bhR1YnKi6TtzgJUL3Ykea8QGU1ZLfR -p infrasys@active --txfee-payer infrasys

{ print_section_title "Create initial Identity Authority Account"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_2So2Tt7dAoMR6tk9npz1WrnbAgHadbEhbmkLChRvggduxnwxAn
$INFRA_CLI create account infrasys idauth.a PUB_K1_8QZSZGRFMiXk9GGEc7jPsyqZVF1CkJh16vHmnVt4PopkRZeyZJ -p infrasys@active --txfee-payer infrasys

$INFRA_CLI wallet import --private-key PVT_K1_2mrT8fELciM7qUvg7TSBG7SUVgvRL3gzATRMkY2JsJn1GMk2A5
$INFRA_CLI create account infrasys idauth.b PUB_K1_8acHA5kYZd9ktLC7zHWJcH8h63Zrt19kQbe11ASCobb7NNvZaq -p infrasys@active --txfee-payer infrasys



{ print_section_title "Create initial System Token Account"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_4pDTqEyBnCCacqUfE6RgRWmssghAHU497eDqLg9ZobcnBYWQx
$INFRA_CLI create account infrasys systoken.a PUB_K1_7DoMEdoWG4C9sf5B84HpG4k8MrnF1dcdsFTmk1Q348cn4XukEP -p infrasys@active --txfee-payer infrasys

$INFRA_CLI wallet import --private-key PVT_K1_2MPBZmG3HxvzYdFJB1h3sR1HWcXe6rJUxuG9Uf52smrqLUaoYX
$INFRA_CLI create account infrasys systoken.b PUB_K1_6XAnMYrHi4fiVDkj4F6iV3ujgvNpYqQBViQr8pgFxi4Zv9muWg -p infrasys@active --txfee-payer infrasys


{ print_section_title "Install InfraBlockchain System Contract"; } 2>/dev/null

sleep 2
$INFRA_CLI set contract infrasys $INFRABLOCKCHAIN_CONTRACTS_DIR/infrasys/ -p infrasys@active --txfee-payer infrasys
sleep 2


{ print_section_title "Install Standard Token ABI Interface System Contract"; } 2>/dev/null

sleep 2
$INFRA_CLI set contract sys.tokenabi $INFRABLOCKCHAIN_CONTRACTS_DIR/sys.tokenabi/ -p sys.tokenabi@active --txfee-payer infrasys
sleep 2


{ print_section_title "Install Multi-sig System Contract"; } 2>/dev/null

sleep 2
$INFRA_CLI set contract sys.msig $INFRABLOCKCHAIN_CONTRACTS_DIR/eosio.msig/ -p sys.msig@active --txfee-payer infrasys
sleep 2
$INFRA_CLI push action infrasys setpriv '{"account":"sys.msig","is_priv":1}' -p infrasys@active --txfee-payer infrasys
sleep 2


{ print_section_title "Install Identity System Contract"; } 2>/dev/null

sleep 2
$INFRA_CLI set contract sys.identity $INFRABLOCKCHAIN_CONTRACTS_DIR/sys.identity/ -p sys.identity@active --txfee-payer infrasys
sleep 2

{ print_section_title "Install DigitalContract Contract"; } 2>/dev/null

sleep 2
$INFRA_CLI set contract yx.dcontract $INFRABLOCKCHAIN_CONTRACTS_DIR/yx.dcontract/ -p yx.dcontract@active --txfee-payer infrasys
sleep 2

{ print_section_title "Register Initial Identity Authorities"; } 2>/dev/null

$INFRA_CLI push action infrasys regidauth '{"identity_authority":"idauth.a","url":"http://idauth-a.org","location":1}' -p idauth.a@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authidauth '{"identity_authority":"idauth.a"}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys regidauth '{"identity_authority":"idauth.b","url":"http://idauth-b.org","location":1}' -p idauth.b@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authidauth '{"identity_authority":"idauth.b"}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI get table infrasys infrasys idauthority

sleep 2


{ print_section_title "Querying the status of Identity Authorities and Block Producers"; } 2>/dev/null

$INFRA_CLI get table infrasys infrasys global
$INFRA_CLI get table infrasys infrasys idauthority
$INFRA_CLI get table infrasys infrasys producers


{ print_section_title "Setup Initial System Tokens"; } 2>/dev/null

$INFRA_CLI push action systoken.a settokenmeta '{"sym":"4,DUSD","url":"http://sysdepo-a.org","desc":"system depository a"}' -p systoken.a@active --txfee-payer infrasys

$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"systoken.a","qty":"1000.0000 DUSD","tag":"issue systoken.a"}' -p systoken.a@active --txfee-payer infrasys
sleep 1

$INFRA_CLI get token info systoken.a
$INFRA_CLI get token balance systoken.a systoken.a
$INFRA_CLI get token balance systoken.a idauth.a
$INFRA_CLI get token balance systoken.a idauth.b

$INFRA_CLI push action systoken.b settokenmeta '{"sym":"4,DUSDB","url":"http://sysdepo-b.org","desc":"system depository b"}' -p systoken.b@active --txfee-payer infrasys

$INFRA_CLI push action systoken.b issue '{"t":"systoken.b","to":"systoken.b","qty":"2000.0000 DUSDB","tag":"issue systoken.b"}' -p systoken.b@active --txfee-payer infrasys

$INFRA_CLI get token info systoken.b
$INFRA_CLI get token balance systoken.b systoken.b

$INFRA_CLI push action infrasys addsystoken '{"token":"systoken.a","weight":10000}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys addsystoken '{"token":"systoken.b","weight":10000}' -p infrasys@active --txfee-payer infrasys
sleep 2

$INFRA_CLI get systoken list

$INFRA_CLI get systoken balance systoken.a
$INFRA_CLI get systoken balance systoken.b

$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.a","qty":"5000.0000 DUSD","tag":"issue systoken.a to idauth.a"}' -p systoken.a@active --txfee-payer systoken.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"5000.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a


{ print_section_title "Setup Initial Transaction Fees for Built-in Actions"; } 2>/dev/null

$INFRA_CLI push action infrasys settxfee '{"code":"","action":"","value":1000,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"","action":"issue","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"","action":"transfer","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"","action":"redeem","value":200,"feetype":1}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys settxfee '{"code":"infrasys","action":"newaccount","value":500,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"infrasys","action":"updateauth","value":1000,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"infrasys","action":"linkauth","value":1000,"feetype":1}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"setidinfo","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys
sleep 1
$INFRA_CLI get txfee list -L "sys.identity" -U "sys.identity"
$INFRA_CLI push action infrasys unsettxfee '{"code":"sys.identity","action":"setidinfo"}' -p infrasys@active --txfee-payer infrasys
sleep 1
$INFRA_CLI get txfee list -L "sys.identity" -U "sys.identity"
$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"setidinfo","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"settype","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"setkyc","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"setstate","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"sys.identity","action":"setdata","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI get txfee list -L "sys.identity" -U "sys.identity"

$INFRA_CLI get txfee item infrasys newaccount
$INFRA_CLI get txfee item "" transfer
$INFRA_CLI get txfee item "" ""
$INFRA_CLI get txfee list -L "" -U 1
$INFRA_CLI get txfee list -L infrasys -U infrasys -l 50
$INFRA_CLI get txfee list


{ print_section_title "Initial Block Producer Setup"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_2ocZxRUNmcX94XZa3BkDQVadHhBpgveVu9uisn5rwnjA3HtcCJ
$INFRA_CLI wallet import --private-key PVT_K1_U9Ee4ZGBPVMfyRAhnWqvkGPJY24MK48j7GSA9eRckSroJ7f1i
$INFRA_CLI wallet import --private-key PVT_K1_2RCY8az3ghcCjz9zCy3nSWCWhuskPm3hbCjUAoT8P1R2mCpp3L
$INFRA_CLI wallet import --private-key PVT_K1_2sVfxUt4mEYXcmpeCHofTMh4eKZj39Si55M3E5qd1mf3VVk5fp
$INFRA_CLI wallet import --private-key PVT_K1_27iTXKeEN5J8eddX5dVFTGLR6CZt6sXHtFGhxhsTLJgsGYW5Zw
$INFRA_CLI wallet import --private-key PVT_K1_1BTEQ7FuXNpAwEwiVeBAM8ub9m2SHZii8HeH4U17pMirbCP4z
$INFRA_CLI wallet import --private-key PVT_K1_2QCCaMVBmQw7zwv6QmeKVvQBdKovqsgCfG6qr9VRWRkCpNSQzi
$INFRA_CLI wallet import --private-key PVT_K1_2atqfuPKaW8jvCVgNd2bjXQ2gsuJUrdjXFAe6KZCpTyeHc3Hqr
$INFRA_CLI wallet import --private-key PVT_K1_fkYpEQam1UKXJuPuYBKnbWk7nRzoGFC21x8WSuZFtRjgUKTvT
$INFRA_CLI wallet import --private-key PVT_K1_ci477gtWsaiitBZt5m9t2MwKdFzCR47gvThYjSFqqKh3u9WHu
sleep 1

$INFRA_CLI create account infrasys producer.a PUB_K1_4uE86f8v56gAGT92VjJqcVf2hdwMuwhQbVMk5Twta83StDyis1 -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.b PUB_K1_7vx3brmnCQ6GvGyhHssNWbamN9VycZNHPuwq58NxQmixaXqoyB -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.c PUB_K1_5pWYTTfJnogzVJmJ4E3x48S6wjY1VQ6VfwpnNq8f3iscRyMiGa -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.d PUB_K1_5jHaKqt4jBXrnwCGGMbf1HmAQk4t1TUCUJHVNVkSrjB2Hr1Pux -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.e PUB_K1_5oCuNPNUj2TiVbybefYzDq5kfpEaS6Y8iK2BL5jnwcKimp92zJ -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.f PUB_K1_6f4NxFQoFTfQTvbg28g3uPAB2qF3g8ijbpXiVvp8AiSsQLGiXw -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.g PUB_K1_5z17LRtLxDJRTDEVQRvUqZoq9ikzhyZzsAM6VZXN5atZsd4nqD -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.h PUB_K1_8DppnPXPrajP93RuV1TUFQWKmjvebnWrwGqhAhucp8iifxkJvc -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.i PUB_K1_7fMtu1cHqADH9NEvMXZWZaBg1rkM5k7s2dtP7NvPTTjFean4K3 -p infrasys@active --txfee-payer infrasys
$INFRA_CLI create account infrasys producer.j PUB_K1_8Xd6fUhpb7hLogbyo7z9sF6epfaeFx8vuAANPbcZtTDj6Yuzwk -p infrasys@active --txfee-payer infrasys
sleep 1

$INFRA_CLI push action infrasys regproducer '{"producer":"producer.a","producer_key":"PUB_K1_4uE86f8v56gAGT92VjJqcVf2hdwMuwhQbVMk5Twta83StDyis1","url":"http://producera.io","location":1}' -p producer.a@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.b","producer_key":"PUB_K1_7vx3brmnCQ6GvGyhHssNWbamN9VycZNHPuwq58NxQmixaXqoyB","url":"http://producerb.io","location":1}' -p producer.b@active --txfee-payer infrasys

$INFRA_CLI push action infrasys authproducer '{"producer":"producer.a"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.b"}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys regproducer '{"producer":"producer.c","producer_key":"PUB_K1_5pWYTTfJnogzVJmJ4E3x48S6wjY1VQ6VfwpnNq8f3iscRyMiGa","url":"http://producerc.io","location":1}' -p producer.c@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.d","producer_key":"PUB_K1_5jHaKqt4jBXrnwCGGMbf1HmAQk4t1TUCUJHVNVkSrjB2Hr1Pux","url":"http://producerd.io","location":1}' -p producer.d@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.e","producer_key":"PUB_K1_5oCuNPNUj2TiVbybefYzDq5kfpEaS6Y8iK2BL5jnwcKimp92zJ","url":"http://producere.io","location":1}' -p producer.e@active --txfee-payer infrasys

$INFRA_CLI push action infrasys authproducer '{"producer":"producer.c"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.d"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.e"}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys regproducer '{"producer":"producer.f","producer_key":"PUB_K1_6f4NxFQoFTfQTvbg28g3uPAB2qF3g8ijbpXiVvp8AiSsQLGiXw","url":"http://producerf.io","location":1}' -p producer.f@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.g","producer_key":"PUB_K1_5z17LRtLxDJRTDEVQRvUqZoq9ikzhyZzsAM6VZXN5atZsd4nqD","url":"http://producerg.io","location":1}' -p producer.g@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.h","producer_key":"PUB_K1_8DppnPXPrajP93RuV1TUFQWKmjvebnWrwGqhAhucp8iifxkJvc","url":"http://producerh.io","location":1}' -p producer.h@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.i","producer_key":"PUB_K1_7fMtu1cHqADH9NEvMXZWZaBg1rkM5k7s2dtP7NvPTTjFean4K3","url":"http://produceri.io","location":1}' -p producer.i@active --txfee-payer infrasys
$INFRA_CLI push action infrasys regproducer '{"producer":"producer.j","producer_key":"PUB_K1_8Xd6fUhpb7hLogbyo7z9sF6epfaeFx8vuAANPbcZtTDj6Yuzwk","url":"http://producerj.io","location":1}' -p producer.j@active --txfee-payer infrasys

$INFRA_CLI push action infrasys authproducer '{"producer":"producer.f"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.g"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.h"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.i"}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authproducer '{"producer":"producer.j"}' -p infrasys@active --txfee-payer infrasys

## Transaction votes for initial block producer election
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"10.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"20.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.b
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"30.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.c
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"40.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.d
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"50.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.e
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"60.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.f
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"70.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.g
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"80.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.h
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"90.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.i
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"100.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.j
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"110.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"120.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.b
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"130.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.c
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"140.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.d
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.b","qty":"150.0000 DUSD","tag":"issue systoken.a to idauth.b"}' -p systoken.a@active --txfee-payer systoken.a -v producer.e


sleep 125
tail -n 150 $INFRA_NODE_LOG_FILE

{ print_section_title "Resign \"infrasys\" delegating authority to \"sys.prods\""; } 2>/dev/null

$INFRA_CLI get account infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"infrasys","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"sys.prods","permission":"active"}}]}}' -p infrasys@owner --txfee-payer infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"infrasys","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"sys.prods","permission":"active"}}]}}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI get account infrasys
$INFRA_CLI get account sys.prods

sleep 1

{ print_section_title "Resign \"sys.msig\" delegating authority to \"infrasys\""; } 2>/dev/null

$INFRA_CLI get account sys.msig
$INFRA_CLI push action infrasys updateauth '{"account":"sys.msig","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.msig@owner --txfee-payer infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"sys.msig","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.msig@active --txfee-payer infrasys
$INFRA_CLI get account sys.msig

sleep 1

{ print_section_title "Resign System Contract Accounts delegating authority to \"infrasys\""; } 2>/dev/null

$INFRA_CLI get account sys.tokenabi
$INFRA_CLI push action infrasys updateauth '{"account":"sys.tokenabi","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.tokenabi@owner --txfee-payer infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"sys.tokenabi","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.tokenabi@active --txfee-payer infrasys
$INFRA_CLI get account sys.tokenabi

$INFRA_CLI get account sys.identity
$INFRA_CLI push action infrasys updateauth '{"account":"sys.identity","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.identity@owner --txfee-payer infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"sys.identity","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p sys.identity@active --txfee-payer infrasys
$INFRA_CLI get account sys.identity

$INFRA_CLI get account yx.dcontract
$INFRA_CLI push action infrasys updateauth '{"account":"yx.dcontract","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.dcontract@owner --txfee-payer infrasys
$INFRA_CLI push action infrasys updateauth '{"account":"yx.dcontract","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.dcontract@active --txfee-payer infrasys
$INFRA_CLI get account yx.dcontract

#$INFRA_CLI get account yx.nft
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.nft","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.nft@owner --txfee-payer infrasys
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.nft","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.nft@active --txfee-payer infrasys
#$INFRA_CLI get account yx.nft

#$INFRA_CLI get account yx.nftex
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.nftex","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.nftex@owner --txfee-payer infrasys
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.nftex","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.nftex@active --txfee-payer infrasys
#$INFRA_CLI get account yx.nftex

#$INFRA_CLI get account yx.escrow
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.escrow","permission":"owner","parent":"","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.escrow@owner --txfee-payer infrasys
#$INFRA_CLI push action infrasys updateauth '{"account":"yx.escrow","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"infrasys","permission":"active"}}]}}' -p yx.escrow@active --txfee-payer infrasys
#$INFRA_CLI get account yx.escrow

sleep 1

{ print_section_title "Create New User Accounts"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_2gSaRyXwhPaRhpvZwF8ZCLvskJw8BpDnJzYa2b8siJC6sumY8A
$INFRA_CLI wallet import --private-key PVT_K1_2YKh5fwAKdwG1vFvdSyUT636qesed171fL3nh4i5xLiHTp2NMz
$INFRA_CLI wallet import --private-key PVT_K1_2VXd5W4vPMUZ998zButT7f2U2NbS93TqkzJ6tgQYHE6yHUApQb
$INFRA_CLI wallet import --private-key PVT_K1_W5DUCEM6xqmJqXvz3ZfH7VZ9gTPqCXVabDd2YzUowVBG7VKo
$INFRA_CLI wallet import --private-key PVT_K1_fGvQ9cRyumC3xzFG3cvPfNaNibkzRLFXBHF9P7FJixhvqkxHV

$INFRA_CLI create account idauth.a useraccount1 PUB_K1_6rGczYQ1yjJVZcm3TbKbkLwFX98LoigRHREvU1yWS4MPxRPCSx -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI create account idauth.a useraccount2 PUB_K1_8ZzFcSW18yA1JgwrEzxSN75GoE263dMWW8X4tHrvvC8nuN5z2j -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI create account idauth.a useraccount3 PUB_K1_7auEiXsYXmQe5WdyjGJmQ4e4eRpi3PFWvNzRQDajhCZ65jTY7R -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI create account infrasys com PUB_K1_6gr3cnC46CuMW4dEgp42ct64aWqFdcYQzRFdwCKU4X11Qa5ZKA -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"com\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"1f32i7t23\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"com","qty":"3000.0000 DUSD","tag":"issue systoken.a to com"}' -p systoken.a@active --txfee-payer systoken.a
$INFRA_CLI create account com acquire.com PUB_K1_5RyCzTHK13aRPA6nYmPzKgjVhdXUXtbEuj3JfQGhoKUaT56dnH -p com@active --txfee-payer com

$INFRA_CLI get systoken balance com
$INFRA_CLI get systoken balance acquire.com
$INFRA_CLI get systoken balance sys.txfee

$INFRA_CLI get table -L com -l 1 sys.identity sys.identity identity

sleep 1

{ print_section_title "Managing Account Identity Info (KYC, Account Type/State/Data)"; } 2>/dev/null

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccount1\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 0111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccount2\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"23uyiuye\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccount3\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"vewv23r3\"}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI get table -L useraccount1 -l 1 sys.identity sys.identity identity

$INFRA_CLI push action sys.identity settype "{\"account\":\"useraccount1\", \"type\":$(echo 'ibase=2; 1000000000000000' | bc)}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action sys.identity settype "{\"account\":\"useraccount1\", \"type\":$(echo 'ibase=2; 0' | bc)}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action sys.identity setkyc "{\"account\":\"useraccount1\", \"kyc\":$(echo 'ibase=2; 1111' | bc)}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action sys.identity setstate "{\"account\":\"useraccount1\", \"state\":$(echo 'ibase=2; 0001' | bc)}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action sys.identity setdata "{\"account\":\"useraccount1\", \"data\":\"23fiuygy3\"}" -p idauth.a@active --txfee-payer idauth.a

sleep 1

{ print_section_title "System Token Issue / Transfer"; } 2>/dev/null

$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"useraccount2","qty":"1000.0000 DUSD","tag":"issue systoken.a"}' -p systoken.a@active --txfee-payer systoken.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"useraccount3","qty":"1000.0000 DUSD","tag":"issue systoken.a"}' -p systoken.a@active --txfee-payer systoken.a

$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccount2","to":"useraccount3","qty":"100.0000 DUSD","tag":"transfer memo"}' -p useraccount2@active --txfee-payer useraccount2
$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccount2","to":"useraccount3","qty":"100.0000 DUSD","tag":"transfer memo 2"}' -p useraccount2@active --txfee-payer useraccount3

$INFRA_CLI get systoken balance useraccount1
$INFRA_CLI get systoken balance useraccount2
$INFRA_CLI get systoken balance useraccount3
$INFRA_CLI get systoken balance sysdepo1
$INFRA_CLI get systoken balance sys.txfee

sleep 1


{ print_section_title "Transaction Votes"; } 2>/dev/null

$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccount3","to":"useraccount2","qty":"50.0000 DUSD","tag":"tag1"}' -p useraccount3@active --txfee-payer useraccount2 -v producer.f
$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccount3","to":"useraccount2","qty":"50.0000 DUSD","tag":"tag2"}' -p useraccount3@active --txfee-payer useraccount2 -v producer.g
$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccount3","to":"useraccount2","qty":"50.0000 DUSD","tag":"tag3"}' -p useraccount3@active --txfee-payer useraccount2 -v producer.g
sleep 2

$INFRA_CLI get table infrasys infrasys producers
sleep 1


{ print_section_title "Account Recovery"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_25dYUkNiDbDTS6QCbpVkVdD2hahWYPeKdcsaU7keoUmMn5Q8Sr
$INFRA_CLI wallet import --private-key PVT_K1_2nCiLfxueijtLm6VSM84hVeekAYjvcXiZFUq837kZ8Q7MAaLBU
$INFRA_CLI wallet import --private-key PVT_K1_MHGoN1Dyp2Z1ESE77ngzenZn2jtzvtfPCEMgbQ3EaPPYxdrPc
$INFRA_CLI wallet import --private-key PVT_K1_MtWqXKuwY4hb8qr5c3fAMFLxgD7H6yVqepkN8ZWS5nSeudNXY
$INFRA_CLI wallet import --private-key PVT_K1_pN929oHCx3nef3kX2c4J9kJjjRQ4H2YJo4aMWEhH7zoTy2FPw

$INFRA_CLI push action infrasys newaccount '{"creator":"idauth.a","name":"useraccountz","owner":{"threshold":1,"keys":[{"key":"PUB_K1_7iQ8oVcnWs5ARztz8pDN2MSyFPFX3EXAKtK7zHuLYrbdCzToNm","weight":1}],"accounts":[{"permission":{"actor":"idauth.a","permission":"active"},"weight":1}],"waits":[]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_7CLNHjPKHsRpgZmBctdkVKuZeqX5jgrro9uNTRfDRQMPwYEYPZ","weight":1}],"accounts":[],"waits":[]}}' -p idauth.a@active --txfee-payer idauth.a -v producer.c
$INFRA_CLI get account useraccountz
sleep 1
$INFRA_CLI push action infrasys updateauth '{"account":"useraccountz","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[{"key":"PUB_K1_6d1UeaP2MSHPqp1Eyku7cSmmBpkbdobbi17cNEpYPCgstmfExe","weight":1}],"waits":[],"accounts":[]}}' -p useraccountz@owner --txfee-payer idauth.a
$INFRA_CLI get account useraccountz
sleep 1
$INFRA_CLI push action infrasys updateauth '{"account":"useraccountz","permission":"owner","parent":"","auth":{"threshold":2,"keys":[{"key":"PUB_K1_65naa2mTDkHZQFXBn6AcbddHuqytPdKwQnRJv2H7BDaxdi1obA","weight":2}],"accounts":[{"permission":{"actor":"idauth.a","permission":"active"},"weight":1},{"permission":{"actor":"systoken.a","permission":"active"},"weight":1}],"waits":[]}}' -p useraccountz@owner --txfee-payer idauth.a
$INFRA_CLI get account useraccountz
sleep 1
$INFRA_CLI push action infrasys updateauth '{"account":"useraccountz","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[{"key":"PUB_K1_5yK2PNDHhwjrfmx5y4SyQocH1mEantPKsVNWQ69qC3Meh39RRH","weight":1}],"waits":[],"accounts":[]}}' -p useraccountz@owner --txfee-payer idauth.a
$INFRA_CLI get account useraccountz
sleep 1
$INFRA_CLI push action infrasys newaccount '{"creator":"idauth.a","name":"useraccountx","owner":{"threshold":2,"keys":[{"key":"PUB_K1_65naa2mTDkHZQFXBn6AcbddHuqytPdKwQnRJv2H7BDaxdi1obA","weight":2}],"accounts":[{"permission":{"actor":"idauth.a","permission":"active"},"weight":1},{"permission":{"actor":"systoken.a","permission":"active"},"weight":1}],"waits":[]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_5yK2PNDHhwjrfmx5y4SyQocH1mEantPKsVNWQ69qC3Meh39RRH","weight":1}],"accounts":[],"waits":[]}}' -p idauth.a@active --txfee-payer idauth.a -v producer.c
$INFRA_CLI get account useraccountx
sleep 1
$INFRA_CLI push action infrasys updateauth '{"account":"useraccountx","permission":"owner","parent":"","auth":{"threshold":2,"keys":[{"key":"PUB_K1_6d1UeaP2MSHPqp1Eyku7cSmmBpkbdobbi17cNEpYPCgstmfExe","weight":1}],"accounts":[{"permission":{"actor":"idauth.a","permission":"active"},"weight":1},{"permission":{"actor":"systoken.a","permission":"active"},"weight":1}],"waits":[]}}' -p useraccountx@owner --txfee-payer idauth.a
$INFRA_CLI push action infrasys updateauth '{"account":"useraccountx","permission":"active","parent":"owner","auth":{"threshold":1,"keys":[{"key":"PUB_K1_6d1UeaP2MSHPqp1Eyku7cSmmBpkbdobbi17cNEpYPCgstmfExe","weight":1}],"accounts":[],"waits":[]}}' -p useraccountx@owner --txfee-payer idauth.a
$INFRA_CLI get account useraccountx
sleep 1
$INFRA_CLI push action infrasys newaccount '{"creator":"idauth.a","name":"useraccounty","owner":{"threshold":3,"keys":[{"key":"PUB_K1_65naa2mTDkHZQFXBn6AcbddHuqytPdKwQnRJv2H7BDaxdi1obA","weight":2}],"accounts":[{"permission":{"actor":"idauth.a","permission":"active"},"weight":2},{"permission":{"actor":"systoken.a","permission":"active"},"weight":1}],"waits":[{"wait_sec":604800,"weight":1}]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_5yK2PNDHhwjrfmx5y4SyQocH1mEantPKsVNWQ69qC3Meh39RRH","weight":1}],"accounts":[],"waits":[]}}' -p idauth.a@active --txfee-payer idauth.a -v producer.c
$INFRA_CLI get account useraccounty
sleep 1

{ print_section_title "Deploy Yosemite X Fiat Stable Coin as a System Token"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_2vMkSMrCTRnuFTWH8LVoqmXNxadPhnqMY9qSHFgSxnKAz67UU4
$INFRA_CLI create account infrasys ysmt.dusd.a PUB_K1_5aexj1rg482quS3pkqCeiejNJWpNfhJDc875qDZP1q9kNRYZGN -p infrasys@active --txfee-payer infrasys

sleep 2
$INFRA_CLI set contract ysmt.dusd.a $INFRABLOCKCHAIN_CONTRACTS_DIR/yosemitex.fiat.stable.token/ -p ysmt.dusd.a@active --txfee-payer infrasys
sleep 2

$INFRA_CLI push action ysmt.dusd.a settokenmeta '{"sym":"4,DUSD","url":"https://yosemitex.com","desc":"Yosemite X Digital USD Token"}' -p ysmt.dusd.a@active --txfee-payer infrasys

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ysmt.dusd.a\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"ysmt.dusd.a\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"ysmt.dusd.a","qty":"100000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer infrasys

$INFRA_CLI push action infrasys settxfee '{"code":"ysmt.dusd.a","action":"issue","value":0,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ysmt.dusd.a","action":"redeem","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys addsystoken '{"token":"ysmt.dusd.a","weight":10000}' -p infrasys@active --txfee-payer infrasys

sleep 2


{ print_section_title "InfraBlockchain Standard Token Test"; } 2>/dev/null

$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"idauth.a","qty":"10000.0000 DUSD","tag":""}' -p systoken.a@active --txfee-payer systoken.a

$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"idauth.a","to":"idauth.b","qty":"50.0000 DUSD","tag":"transfer tag"}' -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"idauth.a","to":"idauth.b","qty":"30.0000 DUSD","tag":"transfer tag 2"}' -p idauth.a@active --txfee-payer idauth.b

$INFRA_CLI get token balance systoken.a idauth.a
$INFRA_CLI get token balance systoken.a idauth.b

$INFRA_CLI get token balance systoken.a systoken.a
$INFRA_CLI push action systoken.a redeem '{"qty":"500.0000 DUSD","tag":"redeem tag"}' -p systoken.a@active --txfee-payer systoken.a

$INFRA_CLI wallet import --private-key PVT_K1_2K75BtRGgahpZqT4QfeVNyrNN7gBaSHTpVg5XMWLXkKjNETCWt
$INFRA_CLI wallet import --private-key PVT_K1_CKtaYYgdJsHnN5kmJ5WuxcqFQVkuG5U1Wspp79BXMYE7m3Zen
$INFRA_CLI wallet import --private-key PVT_K1_2GbCUqeWSrbSfdL3H3ngermFP7m1paiPDKCn8kT3p4HNkQDqnk

$INFRA_CLI create account idauth.a useraccounta PUB_K1_59GwcpZm6FqQDDfuRsCTsVWQ6MgWWUE4wCFVACDqx5dwMBwBwR -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI create account idauth.a useraccountb PUB_K1_8iVnvTrvG4vQMcJ7R45BKhzNeijn5LDE8d4sq32EGknDc3Zro1 -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI create account idauth.a useraccountc PUB_K1_62eHR1NUJCULSTfcSKKGxi1Cb3ctPxgnK8MyzXhtZUL2jhkmpq -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccounta\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"qwefewff2f\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccountb\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"wef2ouih23\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"useraccountc\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 0111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"kh23r23ruy\"}" -p idauth.a@active --txfee-payer idauth.a

$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"useraccounta","qty":"50000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"useraccountb","qty":"20000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a
#$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"useraccountc","qty":"10000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a

$INFRA_CLI get token balance ysmt.dusd.a useraccounta
$INFRA_CLI get token balance ysmt.dusd.a useraccountb

$INFRA_CLI push action ysmt.dusd.a transfer '{"t":"ysmt.dusd.a","from":"useraccounta","to":"useraccountb","qty":"100.0000 DUSD","tag":"transfer tag"}' -p useraccounta@active --txfee-payer useraccounta -v producer.d


$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"useraccounta","qty":"1000.0000 DUSD","tag":""}' -p systoken.a@active --txfee-payer systoken.a
$INFRA_CLI push action systoken.b issue '{"t":"systoken.b","to":"useraccounta","qty":"1000.0000 DUSDB","tag":""}' -p systoken.b@active --txfee-payer systoken.b

$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"useraccountb","qty":"2000.0000 DUSD","tag":""}' -p systoken.a@active --txfee-payer systoken.a
$INFRA_CLI push action systoken.a issue '{"t":"systoken.a","to":"useraccountc","qty":"3000.0000 DUSD","tag":""}' -p systoken.a@active --txfee-payer systoken.a

$INFRA_CLI get token balance systoken.a useraccounta
$INFRA_CLI get token balance systoken.b useraccounta
$INFRA_CLI get systoken balance useraccounta

$INFRA_CLI get token balance systoken.a useraccountb
$INFRA_CLI get token balance systoken.a useraccountc

$INFRA_CLI push action systoken.a transfer '{"t":"systoken.a","from":"useraccounta","to":"useraccountb","qty":"999.5000 DUSD","tag":"transfer tag"}' -p useraccounta@active --txfee-payer useraccounta -v producer.a

$INFRA_CLI get systoken balance useraccounta
$INFRA_CLI get systoken balance useraccountb
$INFRA_CLI get systoken balance useraccountc

sleep 2

{ print_section_title "Yosemite Card Credit Token Test"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_PgZ6SXpnuxTMcHeK2y4HDPv3R6nSLdwQV6u6rbU4Ka5hBtHb4
$INFRA_CLI create account infrasys ycard.cusd.a PUB_K1_6jY1dkUUf315a5gdsjd1CHu6FANoMpVYCqb6dZ52eGtYvSGCNT -p infrasys@active --txfee-payer infrasys

sleep 2
$INFRA_CLI set contract ycard.cusd.a $INFRABLOCKCHAIN_CONTRACTS_DIR/yosemitex.credit.token/ -p ycard.cusd.a@active --txfee-payer infrasys
sleep 2

$INFRA_CLI push action ycard.cusd.a settokenmeta '{"sym":"4,CUSD","url":"https://yosemitecardx.com","desc":"Yosemite Card X USD Credit Token"}' -p ycard.cusd.a@active --txfee-payer infrasys

$INFRA_CLI push action infrasys settxfee '{"code":"ycard.cusd.a","action":"creditlimit","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.cusd.a","action":"creditissue","value":300,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.cusd.a","action":"creditredeem","value":500,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.cusd.a","action":"offtransfer","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycard.cusd.a\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"if3fhu3eu\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"ycard.cusd.a","qty":"70000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a -v producer.a

$INFRA_CLI get token balance ysmt.dusd.a ycard.cusd.a

sleep 2

## issuing credit card to useraccounta by offering credit limit
$INFRA_CLI push action ycard.cusd.a creditlimit '{"account":"useraccounta","credit_limit":"500.0000 CUSD","tag":"vhw93rh23r"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.b

$INFRA_CLI get table -L useraccounta -l 1 ycard.cusd.a ycard.cusd.a creditoffer

sleep 2

## useraccounta issues credit tokens and deposits to ycard service
$INFRA_CLI push action infrasys updateauth '{"account":"useraccounta","permission":"creditissue","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.cusd.a","permission":"active"}}]}}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"useraccounta","code":"ycard.cusd.a","type":"creditissue","requirement":"creditissue"}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.c
$INFRA_CLI push action infrasys updateauth '{"account":"useraccounta","permission":"codetransfer","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.cusd.a","permission":"sys.code"}}]}}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"useraccounta","code":"ycard.cusd.a","type":"transfer","requirement":"codetransfer"}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.c

$INFRA_CLI push action ycard.cusd.a creditissue '{"issuer":"useraccounta","to":"ycard.cusd.a","qty":"500.0000 CUSD","tag":"issue credit token by user, and deposit to credit service"}' -p useraccounta@creditissue --txfee-payer ycard.cusd.a -v producer.c
#$INFRA_CLI push action ycard.cusd.a transfer '{"t":"ycard.cusd.a","from":"useraccounta","to":"ycard.cusd.a","qty":"500.0000 CUSD","tag":"deposit credit to service account for anonymous tx"}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.c

$INFRA_CLI get table -L useraccounta -l 1 ycard.cusd.a ycard.cusd.a creditoffer
$INFRA_CLI get token balance ycard.cusd.a useraccounta
$INFRA_CLI get token balance ycard.cusd.a ycard.cusd.a

sleep 2

## anonymous payment transaction to merchant useraccountb
$INFRA_CLI push action ycard.cusd.a transfer '{"t":"ycard.cusd.a","from":"ycard.cusd.a","to":"useraccountb","qty":"100.0000 CUSD","tag":"payment tx 1"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.d
$INFRA_CLI push action ycard.cusd.a transfer '{"t":"ycard.cusd.a","from":"ycard.cusd.a","to":"useraccountb","qty":"100.0000 CUSD","tag":"payment tx 2"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.d

$INFRA_CLI get token balance ycard.cusd.a useraccountb

## anonymous off-chain token transfer, logging just an evidence of off-chain token transfer (hash of transfer data)
$INFRA_CLI push action ycard.cusd.a offtransfer '{"t":"ycard.cusd.a","to":"useraccountc","tag":"QmT4AeWE9Q9EaoyLJiqaZuYQ8mJeq4ZBncjjFH9dQ9uDVA"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.e

sleep 2

## monthly user credit balance settlement
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"ycard.cusd.a","qty":"200.0000 DUSD","tag":"useraccounta credit settlement"}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a -v producer.g

$INFRA_CLI push action ycard.cusd.a redeem '{"qty":"300.0000 CUSD","tag":"burn unused useraccounta credit"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.g

$INFRA_CLI push action ycard.cusd.a creditredeem '{"account":"useraccounta","qty":"500.0000 CUSD","tag":"reset useraccounta credit offering"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.e

$INFRA_CLI push action ycard.cusd.a creditissue '{"issuer":"useraccounta","to":"ycard.cusd.a","qty":"500.0000 CUSD","tag":"monthly issue credit token by user, and deposit to credit service"}' -p useraccounta@creditissue --txfee-payer ycard.cusd.a -v producer.e
#$INFRA_CLI push action ycard.cusd.a transfer '{"t":"ycard.cusd.a","from":"useraccounta","to":"ycard.cusd.a","qty":"500.0000 CUSD","tag":"deposit credit to service account for anonymous tx"}' -p useraccounta@active --txfee-payer ycard.cusd.a -v producer.e

sleep 2

## merchant(useraccountb) redeems credit tokens and withdraws fiat
$INFRA_CLI push action ycard.cusd.a transfer '{"t":"ycard.cusd.a","from":"useraccountb","to":"ycard.cusd.a","qty":"200.0000 CUSD","tag":"request redeeming credit token"}' -p useraccountb@active --txfee-payer ycard.cusd.a -v producer.h

$INFRA_CLI push action ysmt.dusd.a transfer '{"t":"ysmt.dusd.a","from":"ycard.cusd.a","to":"useraccountb","qty":"200.0000 DUSD","tag":"redeeming CUSD to DUSD"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.h

$INFRA_CLI push action ycard.cusd.a redeem '{"qty":"200.0000 CUSD","tag":"burn redeemed credit tokens"}' -p ycard.cusd.a@active --txfee-payer ycard.cusd.a -v producer.h

sleep 2

$INFRA_CLI get token balance ycard.cusd.a useraccountb
$INFRA_CLI get token balance ysmt.dusd.a useraccountb

$INFRA_CLI push action ysmt.dusd.a transfer '{"t":"ysmt.dusd.a","from":"useraccountb","to":"ysmt.dusd.a","qty":"200.0000 DUSD","tag":"request redeeming DUSD to fiat"}' -p useraccountb@active --txfee-payer ycard.cusd.a -v producer.i
$INFRA_CLI push action ysmt.dusd.a redeem '{"qty":"200.0000 DUSD","tag":"redeem DUSD to fiat"}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a -v producer.i

sleep 2

{ print_section_title "Yosemite Card X Token Test"; } 2>/dev/null

$INFRA_CLI wallet import --private-key PVT_K1_r2nv6dJvB3pQyxSh5JkXyLaKrVkh9NDYAA1H9HAQmj6eCWGM6
$INFRA_CLI create account infrasys ycard.usd.yt PUB_K1_7nn2nbvyuCspiCt5nQp5Kx5GJKKoSLmsAPTdY9Yua34PcYVCYT -p infrasys@active --txfee-payer infrasys

$INFRA_CLI wallet import --private-key PVT_K1_d1mjQrD3BtnMbmgeUQX5oc5XwJRVUgJNY65MpZJTS6D6D1ucp
$INFRA_CLI create account infrasys ycard.users PUB_K1_5zWk8fvNugYJ9noncZkKcAnmfeojbBqc9F8X1j9FYdMPstcqLk -p infrasys@active --txfee-payer infrasys

sleep 2
$INFRA_CLI set contract ycard.usd.yt $INFRABLOCKCHAIN_CONTRACTS_DIR/yosemite.card.ytoken/ -p ycard.usd.yt@active --txfee-payer infrasys
sleep 2

$INFRA_CLI push action ycard.usd.yt settokenmeta '{"sym":"4,YTOKEN","url":"https://yosemitecardx.com","desc":"Yosemite Card Yosemite Token USD"}' -p ycard.usd.yt@active --txfee-payer infrasys

$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"ytokenissue","value":300,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"ytokenburn","value":500,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"ytokenredeem","value":500,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"ytokenpay","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"usdytissue","value":200,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"usdredeemto","value":200,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"yusdtransfer","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"yusdredeemrq","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"cnclyusdrdrq","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"creditlimit","value":100,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"creditissue","value":200,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"credittxfer","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"creditsettle","value":200,"feetype":1}' -p infrasys@active --txfee-payer infrasys
$INFRA_CLI push action infrasys settxfee '{"code":"ycard.usd.yt","action":"creditburn","value":50,"feetype":1}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycard.usd.yt\", \"identity_authority\":\"idauth.a\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p idauth.a@active --txfee-payer idauth.a
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"ycard.usd.yt","qty":"10000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a -v producer.a

$INFRA_CLI get token balance ysmt.dusd.a ycard.usd.yt


$INFRA_CLI wallet import --private-key PVT_K1_2DgoXF9WARUKb6caFLLTALYvbdHjHTKnS4FFfxnLv49sDsQrFy
$INFRA_CLI create account infrasys ycard.id.us PUB_K1_88E4kRrKvEaz9tfkAqeEmiyZLJPf5rb7psdTASHCNpWGHd9d9g -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action infrasys regidauth '{"identity_authority":"ycard.id.us","url":"https://yosemitecardx.com","location":1}' -p ycard.id.us@active --txfee-payer infrasys
$INFRA_CLI push action infrasys authidauth '{"identity_authority":"ycard.id.us"}' -p infrasys@active --txfee-payer infrasys

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycard.id.us\", \"identity_authority\":\"ycard.id.us\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p ycard.id.us@active --txfee-payer infrasys
$INFRA_CLI push action ysmt.dusd.a issue '{"t":"ysmt.dusd.a","to":"ycard.id.us","qty":"10000.0000 DUSD","tag":""}' -p ysmt.dusd.a@active --txfee-payer ysmt.dusd.a -v producer.a

# deposit USD-backed Yosemite Tokens for Yosemite Card service operation
$INFRA_CLI push action ycard.usd.yt usdytissue '{"qty":"20000.0000 USD","tag":"issue USD-backed YTOKEN by Yosemite Card"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.d

$INFRA_CLI get token balance ycard.usd.yt ycard.usd.yt
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.usd.yt"}'; echo;

sleep 2

#################################################
### Yosemite Card User Account Setup
$INFRA_CLI wallet import --private-key PVT_K1_TiDZHzPzZwimu36VGt3YjmWqcSkRa9BjkVtBa7Zr6mjKKgMsE
#$INFRA_CLI create account ycard.usd.yt ycarduseraaa PUB_K1_7UPqYWRodQ1dhgCsgF4VnEi1mgcV4a6K7u95BrtTDoNCVXtFYT -p ycard.usd.yt@active --txfee-payer ycard.usd.yt
$INFRA_CLI push action infrasys newaccount '{"creator":"ycard.usd.yt","name":"ycarduseraaa","owner":{"threshold":1,"keys":[{"key":"PUB_K1_7UPqYWRodQ1dhgCsgF4VnEi1mgcV4a6K7u95BrtTDoNCVXtFYT","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_7UPqYWRodQ1dhgCsgF4VnEi1mgcV4a6K7u95BrtTDoNCVXtFYT","weight":1}],"accounts":[],"waits":[]}}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c
#$INFRA_CLI push action infrasys updateauth '{"account":"ycarduseraaa","permission":"owner","parent":"","auth":{"threshold":1,"keys":[{"key":"PUB_K1_7UPqYWRodQ1dhgCsgF4VnEi1mgcV4a6K7u95BrtTDoNCVXtFYT","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]}}' -p ycarduseraaa@owner --txfee-payer ycard.usd.yt

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycarduseraaa\", \"identity_authority\":\"ycard.id.us\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1111' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p ycard.id.us@active --txfee-payer ycard.id.us -v producer.a

# ycarduseraaa issues credit tokens and deposits to ycard service
$INFRA_CLI push action infrasys updateauth '{"account":"ycarduseraaa","permission":"creditissue","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.usd.yt","permission":"active"}}]}}' -p ycarduseraaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycarduseraaa","code":"ycard.usd.yt","type":"creditissue","requirement":"creditissue"}' -p ycarduseraaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys updateauth '{"account":"ycarduseraaa","permission":"codecrdtxfer","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.usd.yt","permission":"sys.code"}}]}}' -p ycarduseraaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycarduseraaa","code":"ycard.usd.yt","type":"credittxfer","requirement":"codecrdtxfer"}' -p ycarduseraaa@active --txfee-payer ycard.usd.yt -v producer.c

# offering credit limit to user account ycarduseraaa (issuing credit card)
$INFRA_CLI push action ycard.usd.yt creditlimit '{"account":"ycarduseraaa","credit_limit":"1000.0000 CREDIT","tag":"credit offering"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.b

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt creditoffer -L ycarduseraaa -l 1
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"creditoffer","lower_bound":"ycarduseraaa","limit":1}'; echo;

$INFRA_CLI push action ycard.usd.yt creditissue '{"issuer":"ycarduseraaa","to":"ycard.usd.yt","qty":"1000.0000 CREDIT","tag":"credit token issued by user, and deposited to yosemite card service"}' -p ycarduseraaa@creditissue --txfee-payer ycard.usd.yt -v producer.c

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt creditoffer -L ycarduseraaa -l 1
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"creditoffer","lower_bound":"ycarduseraaa","limit":1}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt credittoken -L ycarduseraaa -l 1
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"credittoken","lower_bound":"ycarduseraaa","limit":1}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt credittoken -L ycard.usd.yt -l 1
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"credittoken","lower_bound":"ycard.usd.yt","limit":1}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt creditstat
curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"creditstat"}'; echo;

sleep 2

#################################################
##### Yosemite Card Merchant Account Setup
$INFRA_CLI wallet import --private-key PVT_K1_SMmDwJed8ZR4hVsMD7bJLYirKpesXtr9tDwnmF5hW15R8myWA
#$INFRA_CLI create account ycard.usd.yt ycardshopaaa PUB_K1_7c2UjL57nCkxR8PWXzt3srpWEM1Cvv6JcAgwzJ6JtqMvQd52wZ -p ycard.usd.yt@active --txfee-payer ycard.usd.yt
$INFRA_CLI push action infrasys newaccount '{"creator":"ycard.usd.yt","name":"ycardshopaaa","owner":{"threshold":1,"keys":[{"key":"PUB_K1_7c2UjL57nCkxR8PWXzt3srpWEM1Cvv6JcAgwzJ6JtqMvQd52wZ","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_7c2UjL57nCkxR8PWXzt3srpWEM1Cvv6JcAgwzJ6JtqMvQd52wZ","weight":1}],"accounts":[],"waits":[]}}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c
#$INFRA_CLI push action infrasys updateauth '{"account":"ycardshopaaa","permission":"owner","parent":"","auth":{"threshold":1,"keys":[{"key":"PUB_K1_7c2UjL57nCkxR8PWXzt3srpWEM1Cvv6JcAgwzJ6JtqMvQd52wZ","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]}}' -p ycardshopaaa@owner --txfee-payer ycard.usd.yt

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycardshopaaa\", \"identity_authority\":\"ycard.id.us\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1101' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p ycard.id.us@active --txfee-payer ycard.id.us -v producer.a

$INFRA_CLI push action infrasys updateauth '{"account":"ycardshopaaa","permission":"ytokenaction","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.usd.yt","permission":"active"}}]}}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopaaa","code":"ycard.usd.yt","type":"ytokenissue","requirement":"ytokenaction"}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopaaa","code":"ycard.usd.yt","type":"ytokenburn","requirement":"ytokenaction"}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopaaa","code":"ycard.usd.yt","type":"ytokenredeem","requirement":"ytokenaction"}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopaaa","code":"ycard.usd.yt","type":"ytokenpay","requirement":"ytokenaction"}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopaaa","code":"ycard.usd.yt","type":"yusdredeemrq","requirement":"ytokenaction"}' -p ycardshopaaa@active --txfee-payer ycard.usd.yt -v producer.c

#################################################
#### Issue Yosemite Token backed by Merchant-issued gift card token

# merchant issues gift token backed yosemite token, yosemite card prepays USD to the merchant
$INFRA_CLI push action ycard.usd.yt ytokenissue '{"merchant":"ycardshopaaa","qty":"700.0000 YTOKEN","paid":"500.0000 USD","tag":"issue merchant gift token backed yosemite token"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenissue -L ycardshopaaa -l 1
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenissue","lower_bound":"ycardshopaaa","limit":1}'; echo;

$INFRA_CLI get token balance ycard.usd.yt ycard.usd.yt
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.usd.yt"}'; echo;

sleep 2

#################################################
##### Yosemite Card Payment Transactions

### yosemite card payment (anonymous user)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopaaa","price":"24.0000 YTOKEN","credit":"24.0000 CREDIT","ytoken":"0.0000 YTOKEN","reward":"6.0000 YTOKEN","tag":"yosemite card anonymous payment"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

$INFRA_CLI get token balance ycard.usd.yt ycard.usd.yt
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.usd.yt"}'; echo;
$INFRA_CLI get token balance ycard.usd.yt ycard.users
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.users"}'; echo;

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenissue -L ycardshopaaa -l 1
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenissue","lower_bound":"ycardshopaaa","limit":1}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenissue -L usdbacked -l 1
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenissue","lower_bound":"usdbacked","limit":1}'; echo;

### yosemite card payment using CREDIT + YTOKEN (anonymous user)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopaaa","price":"32.0000 YTOKEN","credit":"28.0000 CREDIT","ytoken":"4.0000 YTOKEN","reward":"7.0000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenissue -L ycardshopaaa -l 1
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenissue","lower_bound":"ycardshopaaa","limit":1}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenissue -L usdbacked -l 1
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenissue","lower_bound":"usdbacked","limit":1}'; echo;

$INFRA_CLI get token balance ycard.usd.yt ycard.usd.yt
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.usd.yt"}'; echo;
$INFRA_CLI get token balance ycard.usd.yt ycard.users
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_balance -d '{"token":"ycard.usd.yt","account":"ycard.users"}'; echo;

$INFRA_CLI get token info ycard.usd.yt
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_token_info -d '{"token":"ycard.usd.yt"}'; echo;
$INFRA_CLI get table ycard.usd.yt ycard.usd.yt ytokenstat
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"ytokenstat"}'; echo;

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt creditstat
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"creditstat"}'; echo;

$INFRA_CLI get table ycard.usd.yt ycard.usd.yt yusdstat
#curl ${INFRA_NODE_API_ENDPOINT}/v1/chain/get_table_rows -d '{"json":true,"code":"ycard.usd.yt","scope":"ycard.usd.yt","table":"yusdstat"}'; echo;

### yosemite card payment using CREDIT + YTOKEN (anonymous user)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopaaa","price":"350.0000 YTOKEN","credit":"342.0000 CREDIT","ytoken":"8.0000 YTOKEN","reward":"81.0000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

sleep 2

#####################################################
##### Monthly user credit balance settlement

### Yosemite Card user(s) sends money off-chain to Yosemite Card as credit balance settlement
$INFRA_CLI push action ycard.usd.yt usdytissue '{"qty":"394.0000 USD","tag":"YCardUserMonthlyCreditBalancePayment"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.d

$INFRA_CLI push action ycard.usd.yt creditburn '{"qty":"606.0000 CREDIT","tag":"burn unused credit"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.g

$INFRA_CLI push action ycard.usd.yt creditsettle '{"account":"ycarduseraaa","qty":"1000.0000 CREDIT","tag":"reset user credit offering"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.e

$INFRA_CLI push action ycard.usd.yt creditissue '{"issuer":"ycarduseraaa","to":"ycard.usd.yt","qty":"1000.0000 CREDIT","tag":"monthly issue credit token by user, and deposit to ycard service"}' -p ycarduseraaa@creditissue --txfee-payer ycard.usd.yt -v producer.e


#####################################################
##### Burn existing merchant-issued Yosemite Token (store-credit) and Re-issue merchant-issued Yosemite Tokens

$INFRA_CLI push action ycard.usd.yt ytokenburn '{"merchant":"ycardshopaaa","qty":"294.0000 YTOKEN","tag":""}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.d
### merchant refunded USD to Yosemite Card Services
$INFRA_CLI push action ycard.usd.yt usdytissue '{"qty":"210.0000 USD","tag":"merchant refunded money for burning merchant-backed Yosemite Tokens"}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.d

### re-issue merchant backed Yosemite Tokens, YUSD token is paid to merchant account for future redeeming to USD fiat money
$INFRA_CLI push action ycard.usd.yt ytokenissue '{"merchant":"ycardshopaaa","qty":"600.0000 YTOKEN","paid":"500.0000 YUSD","tag":"issue merchant gift token backed yosemite token"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c


#####################################################
##### Redeem YUSD to real fiat money

### YUSD redeem request
$INFRA_CLI push action ycard.usd.yt yusdredeemrq '{"account":"ycardshopaaa","qty":"300.0000 YUSD","tag":""}' -p ycardshopaaa@ytokenaction --txfee-payer ycard.usd.yt -v producer.c

### Cancel YUSD redeem request
$INFRA_CLI push action ycard.usd.yt cnclyusdrdrq '{"account":"ycardshopaaa","qty":"300.0000 YUSD","tag":""}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### YUSD redeem request
$INFRA_CLI push action ycard.usd.yt yusdredeemrq '{"account":"ycardshopaaa","qty":"500.0000 YUSD","tag":""}' -p ycardshopaaa@ytokenaction --txfee-payer ycard.usd.yt -v producer.c

### Yosemite Card completed YUSD redeem to merchant (transferred USD fund to merchant's bank account)
$INFRA_CLI push action ycard.usd.yt usdredeemto '{"to":"ycardshopaaa","qty":"500.0000 YUSD","tag":""}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c


#####################################################
##### Yosemite Card Payment to a merchant who does not issue merchant-backed Yosemite Token

$INFRA_CLI wallet import --private-key PVT_K1_KDQQ5JmS9sCZRZFqJwttJQqjpGrv5KqiSZdAMump34sQJ66MB
#$INFRA_CLI create account ycard.usd.yt ycarduserbbb PUB_K1_5FZrQjaDtifFxa45sKoPCJSsmp4kLuQKZU721HnjA17pchKVmX -p ycard.usd.yt@active --txfee-payer ycard.usd.yt
$INFRA_CLI push action infrasys newaccount '{"creator":"ycard.usd.yt","name":"ycardshopbbb","owner":{"threshold":1,"keys":[{"key":"PUB_K1_5FZrQjaDtifFxa45sKoPCJSsmp4kLuQKZU721HnjA17pchKVmX","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]},"active":{"threshold":1,"keys":[{"key":"PUB_K1_5FZrQjaDtifFxa45sKoPCJSsmp4kLuQKZU721HnjA17pchKVmX","weight":1}],"accounts":[],"waits":[]}}' -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c
#$INFRA_CLI push action infrasys updateauth '{"account":"ycardshopbbb","permission":"owner","parent":"","auth":{"threshold":1,"keys":[{"key":"PUB_K1_5FZrQjaDtifFxa45sKoPCJSsmp4kLuQKZU721HnjA17pchKVmX","weight":1}],"accounts":[{"permission":{"actor":"ycard.id.us","permission":"active"},"weight":1}],"waits":[]}}' -p ycardshopbbb@owner --txfee-payer ycard.usd.yt

$INFRA_CLI push action sys.identity setidinfo "{\"account\":\"ycardshopbbb\", \"identity_authority\":\"ycard.id.us\", \"type\":$(echo 'ibase=2; 0' | bc), \"kyc\":$(echo 'ibase=2; 1101' | bc), \"state\":$(echo 'ibase=2; 0' | bc), \"data\":\"\"}" -p ycard.id.us@active --txfee-payer ycard.id.us -v producer.a

$INFRA_CLI push action infrasys updateauth '{"account":"ycardshopbbb","permission":"ytokenaction","parent":"active","auth":{"threshold":1,"keys":[],"waits":[],"accounts":[{"weight":1,"permission":{"actor":"ycard.usd.yt","permission":"active"}}]}}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopbbb","code":"ycard.usd.yt","type":"ytokenissue","requirement":"ytokenaction"}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopbbb","code":"ycard.usd.yt","type":"ytokenburn","requirement":"ytokenaction"}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopbbb","code":"ycard.usd.yt","type":"ytokenredeem","requirement":"ytokenaction"}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopbbb","code":"ycard.usd.yt","type":"ytokenpay","requirement":"ytokenaction"}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c
$INFRA_CLI push action infrasys linkauth '{"account":"ycardshopbbb","code":"ycard.usd.yt","type":"yusdredeemrq","requirement":"ytokenaction"}' -p ycardshopbbb@active --txfee-payer ycard.usd.yt -v producer.c

### yosemite card payment using CREDIT + YTOKEN (anonymous user)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopbbb","price":"120.0000 YTOKEN","credit":"110.0000 CREDIT","ytoken":"10.0000 YTOKEN","reward":"1.2000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### merchant redeems the earned YTOKEN to USD fiat money
$INFRA_CLI push action ycard.usd.yt ytokenredeem '{"account":"ycardshopbbb","qty":"50.0000 YTOKEN","redeemed":"50.0000 USD","tag":""}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c
### merchant redeems the earned YTOKEN to YUSD token
$INFRA_CLI push action ycard.usd.yt ytokenredeem '{"account":"ycardshopbbb","qty":"70.0000 YTOKEN","redeemed":"70.0000 YUSD","tag":""}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c


#####################################################
##### Yosemite Card - Cancel Payment

### yosemite card payment using CREDIT + YTOKEN (anonymous user)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopaaa","price":"50.0000 YTOKEN","credit":"45.0000 CREDIT","ytoken":"5.0000 YTOKEN","reward":"7.5000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### cancel previous payment
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopaaa","price":"-50.0000 YTOKEN","credit":"-45.0000 CREDIT","ytoken":"-5.0000 YTOKEN","reward":"-7.5000 YTOKEN","tag":"cancel yosemite card payment"}' -p ycardshopaaa@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### cannot cancel the payment already settled for a merchant not issuing merchant-backed Yosemite Token
#$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopbbb","price":"-120.0000 YTOKEN","credit":"-110.0000 CREDIT","ytoken":"-10.0000 YTOKEN","reward":"-1.2000 YTOKEN","tag":"cancel yosemite card payment"}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### payment for a merchant not issuing merchant-backed yosemite tokens
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopbbb","price":"100.0000 YTOKEN","credit":"80.0000 CREDIT","ytoken":"20.0000 YTOKEN","reward":"0.8000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c

### cancel payment (rollback transferred yosemite token)
$INFRA_CLI push action ycard.usd.yt ytokenpay '{"merchant":"ycardshopbbb","price":"-100.0000 YTOKEN","credit":"-80.0000 CREDIT","ytoken":"-20.0000 YTOKEN","reward":"-0.8000 YTOKEN","tag":"yosemite card anonymous payment using YTOKEN"}' -p ycardshopbbb@ytokenaction -p ycard.usd.yt@active --txfee-payer ycard.usd.yt -v producer.c