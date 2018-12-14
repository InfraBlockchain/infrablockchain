/**
 *  @file yosemite/chain/standard_token_action_types.hpp
 *  @author bezalel@yosemitex.com
 *  @copyright defined in yosemite/LICENSE.txt
 */
#pragma once

#include <eosio/chain/types.hpp>
#include <eosio/chain/exceptions.hpp>
#include <eosio/chain/symbol.hpp>
#include <eosio/chain/asset.hpp>

namespace yosemite { namespace chain { namespace token {

   using namespace eosio::chain;

   /**
    * Every account on YOSEMITE blockchain can process built-in standard token actions (settokenmeta, issue, transfer, redeem)
    * without custom smart contract code deployed to an account.
    * An account can have optional token contract code inheriting built-in token actions.
    */

   struct settokenmeta {
      symbol       symbol;
      std::string  url;
      std::string  description;

      static action_name get_name() {
         return N(settokenmeta);
      }
   };

   struct issue {
      account_name  to;
      asset         qty; // token quantity
      std::string   tag;

      static action_name get_name() {
         return N(issue);
      }
   };

   struct transfer {
      account_name  from;
      account_name  to;
      asset         qty; // token quantity
      std::string   tag;

      static action_name get_name() {
         return N(transfer);
      }
   };

   struct txfee {
      account_name  payer;
      asset         fee; // token quantity to pay tx fee

      static action_name get_name() {
         return N(txfee);
      }
   };

   struct redeem {
      asset         qty; // token quantity to redeem(burn)
      std::string   tag;

      static action_name get_name() {
         return N(redeem);
      }
   };

   struct utils {
      static bool is_yosemite_standard_token_action(action_name action) {
         return action == transfer::get_name()
                || action == issue::get_name()
                || action == redeem::get_name()
                || action == txfee::get_name()
                || action == settokenmeta::get_name();
      }
   };

} } } /// yosemite::chain::token

FC_REFLECT( yosemite::chain::token::settokenmeta , (symbol)(url)(description) )
FC_REFLECT( yosemite::chain::token::issue, (to)(qty)(tag) )
FC_REFLECT( yosemite::chain::token::transfer, (from)(to)(qty)(tag) )
FC_REFLECT( yosemite::chain::token::txfee, (payer)(fee) )
FC_REFLECT( yosemite::chain::token::redeem, (qty)(tag) )
