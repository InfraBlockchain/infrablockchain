YOSEMITE Transaction Fee Contract
===

* System contract managing the transaction fee amount for each charged system transaction.
* Transaction fee amounts should be agreed by the active block producers by signing txfee_contract::settxfee transaction
* This contract is deployed on the system transaction fee account (YOSEMITE_TX_FEE_ACCOUNT) on which transaction fees generated on the blockchain will be saved

Environment Var.
---

```bash
INFRA_CLI=$YOSEMITE_HOME/build/programs/infra-cli/infra-cli
YOSEMITE_CONTRACTS_DIR=$YOSEMITE_HOME/build/contracts
```

Install Transaction Fee System Contract
---
```bash
$INFRA_CLI set contract yx.txfee $YOSEMITE_CONTRACTS_DIR/yx.txfee/ -p yx.txfee@active
```

YOSEMITE Transaction Fee Operation Names
---
[`yosemitelib/transaction_fee.hpp`](../../contracts/yosemitelib/transaction_fee.hpp)

Setup Transaction Fees
---

Transaction fees can be updated by the active block producers

```bash
# yx.system
$INFRA_CLI push action yx.txfee settxfee '[ "tf.newacc", "1000.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.regprod", "3000000.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.regsysdep", "2000000.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.regidauth", "2000000.00 DKRW" ]' -p yosemite@active

# yx.ntoken
$INFRA_CLI push action yx.txfee settxfee '[ "tf.nissue", "0.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.nredeem", "1000.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.transfer", "100.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.ntransfer", "200.00 DKRW" ]' -p yosemite@active

# yx.token, yx.nft
$INFRA_CLI push action yx.txfee settxfee '[ "tf.tcreate", "10000.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.tissue", "500.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.tredeem", "500.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.ttransfer", "100.00 DKRW" ]' -p yosemite@active

// yx.dcontract
$INFRA_CLI push action yx.txfee settxfee '[ "tf.dccreate", "500.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.dcaddsign", "100.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.dcsign", "300.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.dcupadd", "50.00 DKRW" ]' -p yosemite@active
$INFRA_CLI push action yx.txfee settxfee '[ "tf.dcremove", "0.00 DKRW" ]' -p yosemite@active

$INFRA_CLI get table -l 100 yx.txfee yx.txfee txfees
{
  "rows": [{
      "operation": "tf.dcaddsign",
      "fee": 10000
    },{
...
    },{
      "operation": "tf.newacc",
      "fee": 100000
    },{
      "operation": "tf.nissue",
      "fee": 0
    },{
      "operation": "tf.nredeem",
      "fee": 100000
    },{
      "operation": "tf.ntransfer",
      "fee": 20000
    },{
...
}

```

Querying the accumulated native token amount in the Transaction Fee Profit Pool
---

```bash
$INFRA_CLI get table yx.ntoken yx.txfee ntaccounts
{
  "rows": [{
      "depository": "sysdepo1",
      "amount": 19273286
    }
  ],
  "more": false
}
```

Getting Current Transaction Fee Amount in Smart Contract Code
---

```cpp
namespace yosemite {

    typedef uint64_t operation_name;

    eosio::asset get_transaction_fee(const operation_name operation_name);

    int64_t get_transaction_fee_amount(const operation_name operation_name);
}
``` 