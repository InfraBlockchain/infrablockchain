#pragma once

#include <eosiolib/eosio.hpp>
#include <eosiolib/asset.hpp>

#include <string>
#include <musl/upstream/include/bits/stdint.h>

namespace yosemitex {

    using namespace eosio;
    using std::string;
    using boost::container::flat_map;
    using boost::container::flat_set;

    static const uint64_t NATIVE_TOKEN_NAME = S(0, DKRW) >> 8;
    static const uint64_t NATIVE_TOKEN = S(4, DKRW);
    static const uint64_t NATIVE_TOKEN_SYS = N(yx.token);
    static const account_name FEEDIST_ACCOUNT_NAME = N(yx.feedist);

    class token : public contract {
    public:
        explicit token(account_name self) : contract(self) {
            operations.insert(N(create));
            operations.insert(N(issue));
            operations.insert(N(redeem));
            operations.insert(N(transfer));
            //operations.insert(N(createn));
            operations.insert(N(issuen));
            operations.insert(N(redeemn));
            operations.insert(N(transfern));
        }

        void create(const extended_symbol &symbol);
        void issue(const account_name &to, const extended_asset &quantity, const string &memo);
        void redeem(const extended_asset &quantity, const string &memo);
        void transfer(account_name from,
                      account_name to,
                      extended_asset quantity,
                      const string &memo);

        void setfee(const name &operation_name, const extended_asset &fee);

        void createn(const account_name &depository);
        void issuen(const account_name &to, const extended_asset &quantity, const account_name &depository, const string &memo);
        void redeemn(const extended_asset &quantity, const account_name &depository, const string &memo);
        void transfern(const account_name &from, const account_name &to, const extended_asset &quantity,
                       const account_name &depository, const string &memo);

        void printsupply(const extended_symbol &symbol);
        void printsupplyn(const account_name &depository);
        void printbalance(account_name owner, extended_symbol symbol);
        void clear(const extended_symbol &symbol);
        void clearn();
    private:
        flat_set<uint64_t> operations{};

        struct fee_holder {
            uint64_t operation;
            extended_asset fee;

            uint64_t primary_key() const { return operation; }
        };

        //TODO: make the specific account as frozen
        struct token_balance {
            int64_t amount{};
            bool whitelist = true;
            bool frozen = false;
        };

        struct balance_holder {
            account_name owner;
            bool frozen = false;
            flat_map<extended_symbol, token_balance> balance_map{};

            uint64_t primary_key() const { return owner; }
        };

        struct native_balance_holder {
            account_name owner;
            int64_t total_balance = 0;
            flat_map<account_name, token_balance> balance_map{}; // account_name is depository

            uint64_t primary_key() const { return owner; }
        };

        struct token_stats {
            int64_t supply = 0;
            bool frozen = false;
            bool enforce_whitelist = false;
        };

        struct token_stats_holder {
            uint64_t id;
            uint128_t extended_symbol_s;
            token_stats tstats;

            uint64_t primary_key() const { return id; }
            uint128_t by_extended_symbol_s() const { return extended_symbol_s; }
        };

        struct native_token_stats_holder {
            account_name depository;
            token_stats tstats;

            uint64_t primary_key() const { return depository; }
        };

        typedef eosio::multi_index<N(stats), token_stats_holder,
                indexed_by<N(extendedsym), const_mem_fun<token_stats_holder, uint128_t, &token_stats_holder::by_extended_symbol_s> >
        > stats;
        typedef eosio::multi_index<N(accounts), balance_holder> accounts;
        typedef eosio::multi_index<N(nativestats), native_token_stats_holder> stats_native;
        typedef eosio::multi_index<N(accnative), native_balance_holder> accounts_native;
        typedef eosio::multi_index<N(fees), fee_holder> fees;

        void transfer_internal(account_name from, account_name to, extended_asset quantity, bool fee_required);
        void transfern_internal(const account_name &from, const account_name &to, const extended_asset &quantity,
                                        const account_name &depository, bool fee_required);

        void add_token_balance(const account_name &owner, const extended_asset &quantity);
        void sub_token_balance(const account_name &owner, const extended_asset &quantity);
        void
        add_native_token_balance(const account_name &owner, const int64_t &quantity, const account_name &depository);
        void
        sub_native_token_balance(const account_name &owner, const int64_t &quantity, const account_name &depository);
        int64_t get_supply(extended_symbol symbol) const;
        void charge_fee(account_name payer, uint64_t operation);
        uint128_t extended_symbol_to_uint128(const extended_symbol &symbol) const;

        void transfer_token(const account_name &from, const account_name &to, const extended_asset &quantity);
        void transfer_native_token(const account_name &from, const account_name &to, extended_asset quantity);
    };
}
