/**
 *  @file chain/yosemite/standard_token_action_handlers.cpp
 *  @author bezalel@yosemitex.com
 *  @copyright defined in yosemite/LICENSE.txt
 */

#include <yosemite/chain/standard_token_action_handlers.hpp>
#include <yosemite/chain/standard_token_action_types.hpp>
#include <yosemite/chain/standard_token_database.hpp>
#include <yosemite/chain/exceptions.hpp>

#include <eosio/chain/controller.hpp>
#include <eosio/chain/transaction_context.hpp>
#include <eosio/chain/apply_context.hpp>
#include <eosio/chain/transaction.hpp>
#include <eosio/chain/account_object.hpp>

namespace yosemite { namespace chain {

   using namespace eosio::chain;
   using namespace yosemite::chain::token;

   void apply_yosemite_built_in_action_settokenmeta(apply_context& context) {

      auto action = context.act.data_as_built_in_common_action<settokenmeta>();
      try {
         int64_t url_size = action.url.size();
         int64_t desc_size = action.description.size();

         EOS_ASSERT( action.symbol.valid(), token_meta_validate_exception, "invalid token symbol" );
         EOS_ASSERT( url_size > 0 && url_size <= 255, token_meta_validate_exception, "invalid token url size" );
         EOS_ASSERT( desc_size > 0 && desc_size <= 255, token_meta_validate_exception, "invalid token description size" );

         // only the account owner can set token metadata for its own token
         context.require_authorization(context.receiver);

         auto& db = context.db;

         auto set_token_meta_lambda = [&action,url_size,desc_size](token_meta_object& token_meta) {
            token_meta.symbol = action.symbol;
            token_meta.url.resize(url_size);
            memcpy( token_meta.url.data(), action.url.data(), url_size );
            token_meta.description.resize(desc_size);
            memcpy( token_meta.description.data(), action.description.data(), desc_size );
         };

         auto token_meta_ptr = db.find<token_meta_object, by_token_id>(context.receiver);
         if ( token_meta_ptr ) {
            EOS_ASSERT( token_meta_ptr->symbol != action.symbol || token_meta_ptr->url != action.url.c_str() || token_meta_ptr->description != action.description.c_str(),
               token_meta_validate_exception, "attempting update token metadata, but new metadata is same as old one" );

            db.modify( *token_meta_ptr, set_token_meta_lambda );
         } else {
            db.create<token_meta_object>( set_token_meta_lambda );

            context.add_ram_usage(context.receiver, (int64_t)(config::billable_size_v<token_meta_object>));
         }

      } FC_CAPTURE_AND_RETHROW( (action) )
   }


   void apply_yosemite_built_in_action_issue(apply_context& context) {

      auto issue_action = context.act.data_as_built_in_common_action<issue>();
      try {
         EOS_ASSERT( issue_action.to.good(), token_issue_validate_exception, "invalid to account name" );
         EOS_ASSERT( issue_action.qty.is_valid(), token_issue_validate_exception, "invalid quantity" );

         share_type issue_amount = issue_action.qty.get_amount();
         EOS_ASSERT( issue_amount > 0, token_issue_validate_exception, "amount of token issuance must be greater than 0" );
         EOS_ASSERT( issue_action.memo.size() <= 256, token_issue_validate_exception, "memo has more than 256 bytes" );

         auto& db = context.db;

         auto token_meta_ptr = db.find<token_meta_object, by_token_id>(context.receiver);
         EOS_ASSERT( !token_meta_ptr, token_not_yet_created_exception, "token not yet created for the account ${account}", ("account", context.receiver) );
         auto token_meta_obj = *token_meta_ptr;

         EOS_ASSERT( issue_action.qty.get_symbol() == token_meta_obj.symbol, token_symbol_mismatch_exception,
                    "token symbol of quantity field mismatches with the symbol(${sym2}) of token metadata",
                    ("sym", token_meta_obj.symbol.to_string()) );

         auto to_account_obj_ptr = db.find<account_object, by_name>(issue_action.to);
         EOS_ASSERT( to_account_obj_ptr != nullptr, token_issue_validate_exception,
                     "token issuance target account ${account} does not exist", ("account", issue_action.to) );

         share_type old_total_supply = token_meta_obj.total_supply;
         EOS_ASSERT( old_total_supply + issue_amount > 0, token_balance_overflow_exception, "total supply balance overflow" );

         // only the token account owner can issue new token
         context.require_authorization( context.receiver );

         // update total supply
         db.modify<token_meta_object>( token_meta_obj, [&](token_meta_object& token_meta) {
            token_meta.total_supply += issue_amount;
         });

         // issue new token to token account
         add_token_balance( context, context.receiver, context.receiver, issue_amount );

         // send inline 'transfer' action if token receiver is not the token account
         if ( issue_action.to != context.receiver ) {
            context.execute_inline(
               action { vector<permission_level>{ {context.receiver, config::active_name} },
                        context.receiver,
                        transfer{ context.receiver, issue_action.to, issue_action.qty, issue_action.memo }
                      }
               );
         }

      } FC_CAPTURE_AND_RETHROW( (issue_action) )
   }

   void add_token_balance( apply_context& context, token_id_type token_id, account_name owner, share_type value ) {

      EOS_ASSERT( context.receiver == token_id, invalid_token_balance_update_access_exception, "add_token_balance : action context receiver mismatches token-id" );

      auto& db = context.db;

      auto balance_ptr = db.find<token_balance_object, by_token_account>(boost::make_tuple(token_id, owner));
      if ( balance_ptr ) {
         db.modify<token_balance_object>( *balance_ptr, [&]( token_balance_object& balance_obj ) {
            balance_obj.balance += value;
         });
      } else {
         db.create<token_balance_object>( [&](token_balance_object& balance_obj) {
            balance_obj.token_id = token_id;
            balance_obj.account = owner;
            balance_obj.balance = value;
         });

         context.add_ram_usage(owner, (int64_t)(config::billable_size_v<token_balance_object>));
      }
   }

} } // namespace yosemite::chain
