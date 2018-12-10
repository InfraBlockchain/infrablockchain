/**
 *  @file chain/yosemite/standard_token_action_handlers.cpp
 *  @author bezalel@yosemitex.com
 *  @copyright defined in yosemite/LICENSE.txt
 */

#include <yosemite/chain/standard_token_action_handlers.hpp>
#include <yosemite/chain/standard_token_action_types.hpp>
#include <yosemite/chain/standard_token_manager.hpp>
#include <yosemite/chain/exceptions.hpp>
#include <yosemite/chain/system_accounts.hpp>

#include <eosio/chain/controller.hpp>
#include <eosio/chain/transaction_context.hpp>
#include <eosio/chain/apply_context.hpp>
#include <eosio/chain/transaction.hpp>
#include <eosio/chain/account_object.hpp>

namespace yosemite { namespace chain {

   using namespace eosio::chain;
   using namespace yosemite::chain::token;

   /**
    * 'settokenmeta' standard token action apply handler
    */
   void apply_yosemite_built_in_action_settokenmeta(apply_context& context) {

      auto set_token_meta = context.act.data_as_built_in_common_action<settokenmeta>();
      try {
         token_id_type token_id = context.receiver;

         // only the account owner can set token metadata for its own token
         context.require_authorization(token_id);

         context.control.get_mutable_token_manager().set_token_meta_info(context, token_id, set_token_meta);

      } FC_CAPTURE_AND_RETHROW( (set_token_meta) )
   }


   /**
    * 'issue' standard token action apply handler
    */
   void apply_yosemite_built_in_action_issue(apply_context& context) {

      auto issue_action = context.act.data_as_built_in_common_action<issue>();
      try {
         EOS_ASSERT( issue_action.qty.is_valid(), token_action_validate_exception, "invalid quantity" );
         EOS_ASSERT( issue_action.memo.size() <= 256, token_action_validate_exception, "memo has more than 256 bytes" );
         // action parameter validation will be done in context.issue_token()

         const token_id_type token_account = context.receiver;
         const account_name to_account = issue_action.to;
         const share_type issue_amount = issue_action.qty.get_amount();

         auto& token_manager = context.control.get_token_manager();

         auto* token_meta_ptr = token_manager.get_token_meta_info(token_account);
         EOS_ASSERT( !token_meta_ptr, token_not_yet_created_exception, "token not yet created for the account ${account}", ("account", context.receiver) );
         auto token_meta_obj = *token_meta_ptr;
         EOS_ASSERT( issue_action.qty.get_symbol() == token_meta_obj.symbol, token_symbol_mismatch_exception,
                     "token symbol of quantity field mismatches with the symbol(${sym}) of token metadata",
                     ("sym", token_meta_obj.symbol.to_string()) );

         // only the token account owner can issue new token
         context.require_authorization( token_account );

         // update token balance and ram usage
         context.issue_token( token_account, issue_amount );

         // send inline 'transfer' action if token receiver is not the token account
         if ( to_account != token_account ) {
            context.execute_inline(
               action { vector<permission_level>{ {token_account, config::active_name} },
                        token_account,
                        transfer{ token_account, to_account, issue_action.qty, issue_action.memo }
                      }
               );
         }

      } FC_CAPTURE_AND_RETHROW( (issue_action) )
   }

   /**
    * 'transfer' standard token action apply handler
    */
   void apply_yosemite_built_in_action_transfer( apply_context& context ) {

      auto transfer_action = context.act.data_as_built_in_common_action<transfer>();
      try {
         const account_name from_account = transfer_action.from;
         const account_name to_account = transfer_action.to;
         const share_type transfer_amount = transfer_action.qty.get_amount();

         EOS_ASSERT( transfer_action.qty.is_valid(), token_action_validate_exception, "invalid quantity" );
         EOS_ASSERT( transfer_action.memo.size() <= 256, token_action_validate_exception, "memo has more than 256 bytes" );
         // action parameter validation will be done in context.transfer_token()

         token_id_type token_id = context.receiver;
         auto& token_manager = context.control.get_mutable_token_manager();

         auto* token_meta_ptr = token_manager.get_token_meta_info(token_id);
         EOS_ASSERT( !token_meta_ptr, token_not_yet_created_exception, "token not yet created for the account ${account}", ("account", context.receiver) );
         auto token_meta_obj = *token_meta_ptr;
         EOS_ASSERT( transfer_action.qty.get_symbol() == token_meta_obj.symbol, token_symbol_mismatch_exception,
                     "token symbol of quantity field mismatches with the symbol(${sym}) of token metadata",
                     ("sym", token_meta_obj.symbol.to_string()) );

         // need 'from' account signature
         context.require_authorization( from_account );

         // update token balance and ram usage
         context.transfer_token( from_account, to_account, transfer_amount );

         // notify 'transfer' action to 'from' and 'to' accounts who could process additional operations for their own sake
         context.require_recipient( from_account );
         context.require_recipient( to_account );

      } FC_CAPTURE_AND_RETHROW( (transfer_action) )
   }


   /**
    * 'txfee' standard token action apply handler
    */
   void apply_yosemite_built_in_action_txfee( apply_context& context ) {

      auto txfee_action = context.act.data_as_built_in_common_action<txfee>();
      try {
         const account_name payer_account = txfee_action.payer;
         EOS_ASSERT( payer_account.good(), token_action_validate_exception, "invalid payer account name" );
         EOS_ASSERT( txfee_action.fee.is_valid(), token_action_validate_exception, "invalid fee quantity" );

         const share_type txfee_amount = txfee_action.fee.get_amount();
         EOS_ASSERT( txfee_amount > 0, token_action_validate_exception, "tx fee amount must be greater than 0" );

         token_id_type token_id = context.receiver;

         auto& db = context.db;
         auto& token_manager = context.control.get_mutable_token_manager();

         auto* token_meta_ptr = token_manager.get_token_meta_info(token_id);
         EOS_ASSERT( !token_meta_ptr, token_not_yet_created_exception, "token not yet created for the account ${account}", ("account", context.receiver) );
         auto token_meta_obj = *token_meta_ptr;

         EOS_ASSERT( txfee_action.fee.get_symbol() == token_meta_obj.symbol, token_symbol_mismatch_exception,
                     "token symbol of fee quantity field mismatches with the symbol(${sym}) of token metadata",
                     ("sym", token_meta_obj.symbol.to_string()) );

         auto* payer_account_obj_ptr = db.find<account_object, by_name>( payer_account );
         EOS_ASSERT( payer_account_obj_ptr != nullptr, no_token_target_account_exception,
                     "tx fee payer account ${account} does not exist", ("account", payer_account) );

         context.require_authorization( payer_account );

         token_manager.subtract_token_balance( context, token_id, payer_account, txfee_amount );
         token_manager.add_token_balance( context, token_id, YOSEMITE_TX_FEE_ACCOUNT, txfee_amount );

         // notify 'txfee' action to payer account and tx-fee system account
         context.require_recipient( payer_account );
         context.require_recipient( YOSEMITE_TX_FEE_ACCOUNT );

      } FC_CAPTURE_AND_RETHROW( (txfee_action) )
   }


   /**
    * 'redeem' standard token action apply handler
    */
   void apply_yosemite_built_in_action_redeem( apply_context& context ) {

      auto redeem_action = context.act.data_as_built_in_common_action<redeem>();
      try {
         EOS_ASSERT( redeem_action.qty.is_valid(), token_action_validate_exception, "invalid token redemption quantity" );
         EOS_ASSERT( redeem_action.memo.size() <= 256, token_action_validate_exception, "memo has more than 256 bytes" );
         // action parameter validation will be done in context.issue_token()

         const share_type redeem_amount = redeem_action.qty.get_amount();

         token_id_type token_account = context.receiver;

         auto& token_manager = context.control.get_mutable_token_manager();

         auto* token_meta_ptr = token_manager.get_token_meta_info(token_account);
         EOS_ASSERT( !token_meta_ptr, token_not_yet_created_exception, "token not yet created for the account ${account}", ("account", context.receiver) );
         auto token_meta_obj = *token_meta_ptr;

         EOS_ASSERT( redeem_action.qty.get_symbol() == token_meta_obj.symbol, token_symbol_mismatch_exception,
                     "token symbol of redemption quantity field mismatches with the symbol(${sym}) of token metadata",
                     ("sym", token_meta_obj.symbol.to_string()) );

         // only the token account owner can redeem(burn) tokens held by token account
         context.require_authorization( context.receiver );

         // update token balance and ram usage
         context.redeem_token( redeem_amount );

      } FC_CAPTURE_AND_RETHROW( (redeem_action) )
   }

} } // namespace yosemite::chain
