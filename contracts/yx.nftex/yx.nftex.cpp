/**
 * @file
 * @copyright defined in yosemite-public-blockchain/LICENSE
 */

#include "yx.nftex.hpp"
#include "../yx.nft/yx.nft.hpp"
#include <infrablockchainlib/yx_asset.hpp>
#include <infrablockchainlib/system_accounts.hpp>
#include <infrablockchainlib/transaction_fee.hpp>
#include <infrablockchainlib/native_token.hpp>

namespace yosemite {

   void nft_exchange::buy(account_name buyer, const yx_nft &nft, const yx_asset &price, const string &memo) {
      check_param(buyer, nft, price, memo);

      sellbook sell_book{get_self(), nft.ysymbol.value};
      auto order_index = sell_book.get_index<N(orderkey)>();
      const uint128_t &orderkey = nft.get_orderkey();
      const auto &sell_order = order_index.get(orderkey, "NFT with the specified id is not in the sell order book");

      auto _now = now();
      if (sell_order.expiration <= time_point_sec(_now)) {
         sell_book.erase(sell_order);
         return;
      }
      eosio_assert(static_cast<uint32_t>(sell_order.price == price), "price is different");
      eosio_assert(static_cast<uint32_t>(sell_order.seller != buyer), "seller and buyer are the same");

      // transfer NFT to buyer
      vector<id_type> ids{sell_order.nft_id};
      INLINE_ACTION_SENDER(yosemite::non_native_token::nft, transferid)
            (INFRABLOCKCHAIN_SYS_NON_FUNGIBLE_TOKEN_ACCOUNT, {{get_self(),              N(active)},
                                                   {INFRABLOCKCHAIN_SYSTEM_ACCOUNT, N(active)}},
             {get_self(), buyer, sell_order.ysymbol.issuer, ids, memo});

      // transfer price to seller
      transfer_token_as_inline(buyer, sell_order.seller, price, memo);

      sell_book.erase(sell_order);

      native_token::charge_transaction_fee(buyer, INFRABLOCKCHAIN_TX_FEE_OP_NAME_NFT_BUY);
   }

   void nft_exchange::buynt(account_name buyer, const yx_nft &nft, const asset &price, const string &memo) {
      buy(buyer, nft, yx_asset{price, account_name{}}, memo);
   }

   void nft_exchange::sell(account_name seller, const yx_nft &nft,
                           const yx_asset &price, const time_point_sec &expiration, const string &memo) {
      eosio_assert(static_cast<uint32_t>(expiration.utc_seconds > 0), "expiration must be set");
      check_param(seller, nft, price, memo, expiration);

      sellbook sell_book{get_self(), nft.ysymbol.value};
      auto order_index = sell_book.get_index<N(orderkey)>();
      const uint128_t &orderkey = nft.get_orderkey();

      eosio_assert(static_cast<uint32_t>(order_index.find(orderkey) == order_index.end()), "sell order with the same NFT already exists");

      sell_book.emplace(get_self(), [&](auto &order) {
         order.id = sell_book.available_primary_key();
         order.nft_id = nft.id;
         order.ysymbol = nft.ysymbol;
         order.seller = seller;
         order.price = price;
         order.expiration = expiration;
      });

      // transfer NFT from seller
      vector<id_type> ids{nft.id};
      INLINE_ACTION_SENDER(yosemite::non_native_token::nft, transferid)
            (INFRABLOCKCHAIN_SYS_NON_FUNGIBLE_TOKEN_ACCOUNT, {{seller,                  N(active)},
                                                   {INFRABLOCKCHAIN_SYSTEM_ACCOUNT, N(active)}},
             {seller, get_self(), nft.ysymbol.issuer, ids, memo});

      native_token::charge_transaction_fee(seller, INFRABLOCKCHAIN_TX_FEE_OP_NAME_NFT_SELL);
   }

   void
   nft_exchange::sellnt(account_name seller, const yx_nft &nft, const asset &price, const time_point_sec &expiration,
                        const string &memo) {
      sell(seller, nft, yx_asset{price, account_name{}}, expiration, memo);
   }

   void nft_exchange::check_param(const account_name &order_account, const yx_nft &nft,
                                  const yx_asset &price, const string &memo,
                                  const time_point_sec &expiration) const {
      require_auth(order_account);
      eosio_assert(static_cast<uint32_t>(is_account(nft.ysymbol.issuer)), "invalid issuer account");
      eosio_assert(static_cast<uint32_t>(nft.ysymbol.is_valid()), "invalid nft symbol");
      eosio_assert(static_cast<uint32_t>(non_native_token::does_token_exist(INFRABLOCKCHAIN_SYS_NON_FUNGIBLE_TOKEN_ACCOUNT, nft.ysymbol)), "nft does not exist");
      eosio_assert(static_cast<uint32_t>(price.is_valid()), "invalid price");
      eosio_assert(static_cast<uint32_t>(price.amount > 0), "only positive price is allowed");
      if (!price.is_native(false)) {
         eosio_assert(static_cast<uint32_t>(non_native_token::does_token_exist(INFRABLOCKCHAIN_SYS_USER_TOKEN_ACCOUNT, price.get_yx_symbol())), "price token does not exist");
      }
      eosio_assert(static_cast<uint32_t>(memo.size() <= 256), "memo has more than 256 bytes");

      if (expiration.utc_seconds != 0) {
         uint32_t _now = now();
         eosio_assert(static_cast<uint32_t>(expiration > time_point_sec(_now + 60)), "wrong expiration : already expired or too close to now");
         eosio_assert(static_cast<uint32_t>(expiration <= time_point_sec(_now + MAX_EXPIRATION_SECONDS)),
                      "expiration is too long");
      }
   }

   void nft_exchange::cancelsell(const yx_nft &nft) {
      sellbook sell_book{get_self(), nft.ysymbol.value};
      auto order_index = sell_book.get_index<N(orderkey)>();
      const uint128_t &orderkey = nft.get_orderkey();
      const auto &order = order_index.get(orderkey, "NFT with the specified id is not in the sell order book");

      require_auth(order.seller);

      sell_book.erase(order);

      // transfer back NFT to seller
      vector<id_type> ids{nft.id};
      INLINE_ACTION_SENDER(yosemite::non_native_token::nft, transferid)
            (INFRABLOCKCHAIN_SYS_NON_FUNGIBLE_TOKEN_ACCOUNT, {{INFRABLOCKCHAIN_SYSTEM_ACCOUNT, N(active)}},
             {get_self(), order.seller, nft.ysymbol.issuer, ids, ""});

      native_token::charge_transaction_fee(order.seller, INFRABLOCKCHAIN_TX_FEE_OP_NAME_NFT_SELL_CANCEL);
   }

}

EOSIO_ABI(yosemite::nft_exchange, (buy)(sell)(buynt)(sellnt)(cancelsell))
