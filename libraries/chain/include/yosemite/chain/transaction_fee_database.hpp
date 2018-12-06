/**
 *  @file yosemite/chain/transaction_fee_database.hpp
 *  @author bezalel@yosemitex.com
 *  @copyright defined in yosemite/LICENSE.txt
 */
#pragma once

#include <eosio/chain/database_utils.hpp>
#include <eosio/chain/multi_index_includes.hpp>

namespace yosemite { namespace chain {

   using namespace eosio::chain;

   enum tx_fee_type {
      null_tx_fee_type = 0,
      fixed_tx_fee_per_action_type,  // transaction_fee_object::value => fixed transaction fee amount per action
      resource_consumption_dynamic_tx_fee_type // transaction_fee_object::value => multiplier applied to resource consumption metric, 10000 = x1.0
   };

   using tx_fee_type_type  = uint32_t;
   using tx_fee_value_type = int32_t;

   /**
    * @brief transaction fee information of built-in actions or actions monitored by block producers
    * for which transaction fee rates and policies are predefined (authorized by block producers)
    */
   class transaction_fee_object : public chainbase::object<yosemite_transaction_fee_object_type, transaction_fee_object> {
      OBJECT_CTOR(transaction_fee_object)

      id_type            id;
      account_name       code; // code account, 0 for global actions
      action_name        action; // action name
      tx_fee_value_type  value;
      tx_fee_type_type   fee_type = fixed_tx_fee_per_action_type;

      // [code == 0 and action == 0]
      //   reserved for the special 'default' transaction_fee_object record
      //   applied as default transaction fee policy for every action that doesn't have transaction_fee_object record
   };

   struct by_code_action;

   using transaction_fee_multi_index = chainbase::shared_multi_index_container<
      transaction_fee_object,
      indexed_by<
         ordered_unique< tag<by_id>, member<transaction_fee_object, transaction_fee_object::id_type, &transaction_fee_object::id> >,
         ordered_unique< tag<by_code_action>,
            composite_key< transaction_fee_object,
               member<transaction_fee_object, account_name, &transaction_fee_object::code>,
               member<transaction_fee_object, action_name, &transaction_fee_object::action>
            >
         >
      >
   >;

} } /// yosemite::chain


CHAINBASE_SET_INDEX_TYPE(yosemite::chain::transaction_fee_object, yosemite::chain::transaction_fee_multi_index)

FC_REFLECT(yosemite::chain::transaction_fee_object, (code)(action)(value)(fee_type) )
