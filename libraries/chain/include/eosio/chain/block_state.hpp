/**
 *  @file
 *  @copyright defined in eos/LICENSE
 */
#pragma once

#include <infrablockchain/chain/transaction_as_a_vote.hpp>
#include <eosio/chain/block_header_state.hpp>
#include <eosio/chain/block.hpp>
#include <eosio/chain/transaction_metadata.hpp>
#include <eosio/chain/action_receipt.hpp>

namespace eosio { namespace chain {

   struct block_state : public block_header_state {
      explicit block_state( const block_header_state& cur ):block_header_state(cur){}
      block_state( const block_header_state& prev, signed_block_ptr b, bool skip_validate_signee );
      block_state( const block_header_state& prev, block_timestamp_type when );
      block_state() = default;

      /// weak_ptr prev_block_state....
      signed_block_ptr                                    block;
      bool                                                validated = false;
      bool                                                in_current_chain = false;

      /// this data is redundant with the data stored in block, but facilitates
      /// recapturing transactions when we pop a block
      vector<transaction_metadata_ptr>                    trxs;

      /// INFRABLOCKCHAIN Transaction-as-a-Vote for Proof-of-Transaction
      /// the accumulated transaction votes data of this block.
      /// the reason why transaction votes data structure is located in struct 'block_state'
      /// is because 'block_state' data structure resides only in 'fork_db' state
      /// from which the irreversible blocks are purged (evicted from memory)
      infrablockchain::chain::transaction_votes_in_block  trx_votes;
   };

   using block_state_ptr = std::shared_ptr<block_state>;

} } /// namespace eosio::chain

FC_REFLECT_DERIVED( eosio::chain::block_state, (eosio::chain::block_header_state), (block)(validated)(in_current_chain) )
