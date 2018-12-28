/**
 *  @file contracts/yx.tokenabi/yx.tokenabi.hpp
 *  @author bezalel@yosemitex.com
 *  @copyright defined in yosemite/LICENSE.txt
 */
#pragma once

#include <eosiolib/asset.hpp>
#include <eosiolib/eosio.hpp>
#include <eosiolib/symbol.hpp>

#include <string>

namespace yosemite { namespace contract {

   using namespace eosio;
   using std::string;

   /**
    * Every account on YOSEMITE blockchain can process built-in standard token actions (settokenmeta, issue, transfer, redeem)
    * without custom smart contract code deployed to an account.
    * This system contract (yx.tokenabi) provide standard application binary interface(abi) for standard token actions.
    * Client tools such as clyos encoding YOSEMITE blockchain transactions could refer 'yx.tokenabi' contract account
    * to retrieve abi information for standard token actions.
    */
   class tokenabi : public eosio::contract {
   public:
      explicit tokenabi( account_name self ) : contract(self) {}

      /**
       * Set token meta info
       * @param sym - token symbol (precision, symbol name)
       * @param url - web site url providing token information managed by token issuer
       * @param desc - token description
       */
      void settokenmeta( symbol_type sym, string url, string desc );

      /**
       * Issue new token
       * @param t - token id (token account name)
       * @param to - account name receiving the issued tokens
       * @param qty - token quantity (amount, symbol) to issue
       * @param tag - user tag string to identity a specific issue action (application-specific purpose)
       */
      void issue( account_name t, account_name to, asset qty, string tag );

      /**
       * Transfer token
       * @param t - token id (token account name)
       * @param from - account name sending tokens
       * @param to - account name receiving tokens
       * @param qty - token quantity (amount, symbol) to transfer
       * @param tag - user tag string to identity a specific transfer action (application-specific purpose)
       */
      void transfer( account_name t, account_name from, account_name to, asset qty, string tag );

      /**
       * Transaction fee payment
       * if current token account is selected as a system token,
       * 'txfee' actions are generated from YOSEMITE blockchain core after processing actions on a submitted transaction
       * @param t - token id (token account name)
       * @param payer - account name paying transaction fee
       * @param fee - token quantity (amount, symbol) being charged as transaction fee
       */
      void txfee( account_name t, account_name payer, asset fee );

      /**
       * Redeem(burn) token
       * only token issuer can redeem(burn) its own token
       * @param qty token quantity (amount, symbol) to redeem
       * @param tag user tag string to identity a specific redeem action (application-specific purpose)
       */
      void redeem( asset qty, string tag );
   };

} } /// namespace yosemite::contract
