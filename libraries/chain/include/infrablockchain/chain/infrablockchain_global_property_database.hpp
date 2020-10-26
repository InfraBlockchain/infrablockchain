/**
 *  @file infrablockchain/chain/infrablockchain_global_property_database.hpp
 *  @author bezalel@infrablockchain.com
 *  @copyright defined in infrablockchain/LICENSE.txt
 */
#pragma once

#include <eosio/chain/database_utils.hpp>
#include <eosio/chain/multi_index_includes.hpp>
#include <infrablockchain/chain/system_token_list.hpp>
#include <infrablockchain/chain/received_transaction_votes_database.hpp>

namespace infrablockchain { namespace chain {

   using namespace eosio::chain;

   class infrablockchain_global_property_object : public chainbase::object<infrablockchain_global_property_object_type, infrablockchain_global_property_object> {
      OBJECT_CTOR(infrablockchain_global_property_object, (system_token_list))

      id_type                        id;
      shared_system_token_list_type  system_token_list;
      tx_votes_sum_weighted_type     total_tx_votes_weighted = 0.0; /// the sum of all transaction votes (weighted sum for vote decay)
      tx_votes_sum_type              total_tx_votes = 0; /// the sum of all transaction votes (un-weighted sum)
      uint64_t                       reserved1 = 0;
      uint64_t                       reserved2 = 0;
   };

   using infrablockchain_global_property_multi_index = chainbase::shared_multi_index_container<
      infrablockchain_global_property_object,
      indexed_by<
         ordered_unique< tag<by_id>, member<infrablockchain_global_property_object, infrablockchain_global_property_object::id_type, &infrablockchain_global_property_object::id> >
      >
   >;

} } /// infrablockchain::chain

CHAINBASE_SET_INDEX_TYPE(infrablockchain::chain::infrablockchain_global_property_object, infrablockchain::chain::infrablockchain_global_property_multi_index)

FC_REFLECT(infrablockchain::chain::infrablockchain_global_property_object, (system_token_list)(total_tx_votes_weighted)(total_tx_votes)(reserved1)(reserved2))